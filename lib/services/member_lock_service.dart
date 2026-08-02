import '../models/member.dart';
import '../models/user_role.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'remuneration_service.dart';
import 'sync_engine.dart';
import 'temporary_access_service.dart';

/// Lock / unlock members once onboarding is complete.
class MemberLockService {
  MemberLockService(
    this._db,
    this._sync,
    this._activity, {
    RemunerationService? remunerationService,
  }) : _remuneration = remunerationService;

  final DatabaseService _db;
  final SyncEngine _sync;
  final ActivityService _activity;
  // NEW ADDITION - optional remuneration hook (pass null to disable)
  final RemunerationService? _remuneration;

  static const String _idStepPdfRelease = 'ACT-REL-PDF-STEP';
  static const String _idStep4AiId = 'ACT-REL-AIID-STEP4';
  static const String _idStep4PdfRelease = 'ACT-REL-PDF-STEP4';
  static const String _idCardIssued = 'ACT-REL-CARD-ISSUED';
  static const String _idStepMarked = 'ACT-STEP-MARK';
  static const String _idStepUnmarked = 'ACT-STEP-UNMARK';

  bool _canManageOnboarding(AuthUser actor) =>
      actor.isAdmin ||
      actor.hasPermission(AppPermission.onboarding) ||
      actor.hasPermission(AppPermission.memberInfo);

  Future<void> _validateStepTransition({
    required Member member,
    required int step,
    required bool complete,
    required String Function(int) stepLabel,
    required List<int> configuredSteps,
  }) async {
    final stepIndex = configuredSteps.indexOf(step);
    if (stepIndex < 0) throw Exception('Invalid onboarding step.');
    if (complete) {
      if (stepIndex > 0) {
        final previousStep = configuredSteps[stepIndex - 1];
        final previousStepComplete = member.isStepCompleteAt(previousStep);
        if (!previousStepComplete) {
          throw Exception(
            '${stepLabel(step)} is locked. Complete ${stepLabel(previousStep)} first.',
          );
        }
      }

      final paid =
          await _remuneration?.hasPaidStepPayment(
            memberId: member.id,
            stepNumber: step,
          ) ??
          false;
      if (!paid) {
        throw Exception(
          'Payment required before ${stepLabel(step)} can be completed.',
        );
      }
      return;
    }

    for (final next in configuredSteps.skip(stepIndex + 1)) {
      if (member.isStepCompleteAt(next)) {
        throw Exception(
          'Cannot uncheck ${stepLabel(step)} while ${stepLabel(next)} is already complete.',
        );
      }
    }
  }

  Future<Member> _applyStepCompletionSideEffects({
    required Member member,
    required AuthUser actor,
    required int step,
    required String stepName,
  }) async {
    var updated = member;
    if (step >= 1 && step <= 3) {
      await _activity.record(
        userName: 'System',
        action:
            '[$_idStepPdfRelease] 📄 step_${step}_pdf_released ($stepName) for ${updated.fullName}',
        captureGps: false,
      );
    }

    if (step == 4) {
      if ((updated.lroRecordNo ?? '').trim().isEmpty) {
        final generatedId =
            'AI-${DateTime.now().toUtc().millisecondsSinceEpoch}';
        updated = updated.copyWith(
          lroRecordNo: generatedId,
          lastModifiedBy: actor.id,
          updatedAt: DateTime.now().toUtc(),
          pendingSync: true,
        );
        await _db.upsertMember(updated);
        await _activity.record(
          userName: 'System',
          action:
              '[$_idStep4AiId] 🆔 step_4_ai_id_generated ($stepName) $generatedId for ${updated.fullName}',
          captureGps: false,
        );
      }
      await _activity.record(
        userName: 'System',
        action:
            '[$_idStep4PdfRelease] 📄 step_4_pdf_released ($stepName) for ${updated.fullName}',
        captureGps: false,
      );
    }

    if (step == 5) {
      await _activity.record(
        userName: 'System',
        action:
            '[$_idCardIssued] 🪪 credential_card_issued ($stepName) for ${updated.fullName}',
        captureGps: false,
      );
    }
    return updated;
  }

  /// Toggle a single onboarding step (1–4). Logs who/when; notifies member.
  Future<Member> setOnboardingStep({
    required Member member,
    required AuthUser actor,
    required int step,
    required bool complete,
  }) async {
    if (!_canManageOnboarding(actor)) {
      throw Exception('You do not have permission to update onboarding steps.');
    }
    if (member.isLocked && !actor.isAdmin) {
      throw Exception('🔒 Locked members cannot have steps changed.');
    }
    final settings = await _remuneration?.getSettings();
    final configuredSteps =
        settings?.configuredSteps.map((step) => step.number).toList() ??
        const [1, 2, 3, 4, 5];
    String stepLabel(int stepNumber) =>
        settings?.stepName(stepNumber) ?? 'Step $stepNumber';
    await _validateStepTransition(
      member: member,
      step: step,
      complete: complete,
      stepLabel: stepLabel,
      configuredSteps: configuredSteps,
    );

    final now = DateTime.now().toUtc();
    final stepName = stepLabel(step);
    var updated = member.withStepState(
      step: step,
      complete: complete,
      changedAt: now,
      approvedBy: actor.id,
    );

    String nextStatus = updated.registrationStatus;
    if (!updated.isLocked) {
      final anyStep = configuredSteps.any(updated.isStepCompleteAt);
      if (updated.allStepsCompleteFor(configuredSteps)) {
        nextStatus = 'complete';
      } else if (anyStep) {
        nextStatus = 'in_progress';
      } else {
        nextStatus = 'pending';
      }
    }

    updated = updated.copyWith(
      registrationStatus: nextStatus,
      lastModifiedBy: actor.id,
      updatedAt: now,
      pendingSync: true,
    );

    await _db.upsertMember(updated);
    await _activity.record(
      userName: actor.displayName,
      action: complete
          ? '[$_idStepMarked] ✅ step_$step ($stepName) completed for ${member.fullName}'
          : '[$_idStepUnmarked] ⬜ step_$step ($stepName) unchecked for ${member.fullName}',
      captureGps: false,
    );
    if (complete) {
      await _activity.record(
        userName: 'System',
        action:
            '📧 Notify ${member.fullName}: $stepName approved '
            'by ${actor.displayName}',
        captureGps: false,
      );
      updated = await _applyStepCompletionSideEffects(
        member: updated,
        actor: actor,
        step: step,
        stepName: stepName,
      );
    }
    await _sync.pushPending();
    return updated;
  }

  /// Lock member after all 5 checklist steps are complete.
  Future<Member> completeAndLock({
    required Member member,
    required AuthUser actor,
    String? reason,
  }) async {
    if (!_canManageOnboarding(actor)) {
      throw Exception('You do not have permission to complete members.');
    }
    if (member.isLocked) {
      throw Exception('⚠️ Member is already locked.');
    }
    final settings = await _remuneration?.getSettings();
    final configuredSteps =
        settings?.configuredSteps.map((step) => step.number).toList() ??
        const [1, 2, 3, 4, 5];
    if (!member.allStepsCompleteFor(configuredSteps)) {
      throw Exception('❌ Member has not completed all configured steps.');
    }

    final now = DateTime.now().toUtc();
    final locked = member.copyWith(
      registrationStatus: 'fully_fledged',
      isLocked: true,
      lockedDate: now,
      lockedBy: actor.id,
      lockedReason: reason ?? 'All requirements completed',
      completedBy: actor.id,
      completedDate: now,
      lastModifiedBy: actor.id,
      updatedAt: now,
      pendingSync: true,
    );
    await _db.upsertMember(locked);
    await _activity.record(
      userName: actor.displayName,
      action: '🔒 lock_member ${locked.fullName} (all steps complete)',
      captureGps: false,
    );
    await _activity.record(
      userName: 'System',
      action:
          '✅ ${locked.fullName} completed all requirements. Member is now locked.',
      captureGps: false,
    );
    await _sync.pushPending();
    return locked;
  }

  Future<Member> unlock({
    required Member member,
    required AuthUser actor,
    String? reason,
  }) async {
    if (!actor.isAdmin) {
      throw Exception('Only the System Administrator can unlock members.');
    }
    if (!member.isLocked) {
      throw Exception('⚠️ Member is not locked.');
    }
    final unlocked = member.copyWith(
      clearLock: true,
      clearTemporaryAccess: true,
      registrationStatus: 'complete',
      lastModifiedBy: actor.id,
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await _db.upsertMember(unlocked);
    await _activity.record(
      userName: actor.displayName,
      action:
          '🔓 unlock_member ${member.fullName}${reason != null ? ' — $reason' : ''}',
      captureGps: false,
    );
    await _sync.pushPending();
    return unlocked;
  }

  bool canEditMember({
    required Member member,
    required AuthUser? user,
    required bool sessionVerifiedTempAccess,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (!user.hasPermission(AppPermission.memberInfo)) return false;
    if (!member.isLocked) return true;
    return sessionVerifiedTempAccess &&
        TemporaryAccessService.isGrantValidFor(member, user.id);
  }
}
