import '../models/member.dart';
import '../models/user_role.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sync_engine.dart';
import 'temporary_access_service.dart';

/// Lock / unlock members once onboarding is complete.
class MemberLockService {
  MemberLockService(this._db, this._sync, this._activity);

  final DatabaseService _db;
  final SyncEngine _sync;
  final ActivityService _activity;

  bool _canManageOnboarding(AuthUser actor) =>
      actor.isAdmin ||
      actor.hasPermission(AppPermission.onboarding) ||
      actor.hasPermission(AppPermission.memberInfo);

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
    if (step < 1 || step > 4) {
      throw Exception('Invalid onboarding step.');
    }

    final now = DateTime.now().toUtc();
    final labels = {
      1: 'Member Info',
      2: 'Global 528',
      3: 'Global 928',
      4: 'LRO',
    };
    var updated = member;
    switch (step) {
      case 1:
        updated = member.copyWith(
          step1MemberInfoComplete: complete,
          step1CompletionDate: complete ? now : member.step1CompletionDate,
          step1ApprovedBy: complete ? actor.id : member.step1ApprovedBy,
        );
      case 2:
        updated = member.copyWith(
          step2Global528Complete: complete,
          step2CompletionDate: complete ? now : member.step2CompletionDate,
          step2ApprovedBy: complete ? actor.id : member.step2ApprovedBy,
        );
      case 3:
        updated = member.copyWith(
          step3Global928Complete: complete,
          step3CompletionDate: complete ? now : member.step3CompletionDate,
          step3ApprovedBy: complete ? actor.id : member.step3ApprovedBy,
        );
      case 4:
        updated = member.copyWith(
          step4LROComplete: complete,
          step4CompletionDate: complete ? now : member.step4CompletionDate,
          step4ApprovedBy: complete ? actor.id : member.step4ApprovedBy,
        );
    }

    String nextStatus = updated.registrationStatus;
    if (!updated.isLocked) {
      final anyStep = updated.step1MemberInfoComplete ||
          updated.step2Global528Complete ||
          updated.step3Global928Complete ||
          updated.step4LROComplete;
      if (updated.allStepsComplete) {
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
          ? '✅ step_$step (${labels[step]}) completed for ${member.fullName}'
          : '⬜ step_$step (${labels[step]}) unchecked for ${member.fullName}',
      captureGps: false,
    );
    if (complete) {
      await _activity.record(
        userName: 'System',
        action:
            '📧 Notify ${member.fullName}: Step $step (${labels[step]}) approved '
            'by ${actor.displayName}',
        captureGps: false,
      );
    }
    await _sync.pushPending();
    return updated;
  }

  /// Lock member after all 4 checklist steps are complete.
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
    if (!member.allStepsComplete) {
      throw Exception('❌ Member has not completed all 4 steps.');
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
