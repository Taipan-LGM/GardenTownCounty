import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';
import '../models/remuneration_settings.dart';
import '../services/auth_service.dart';
import 'activity_service.dart';
import 'county_settings_service.dart';
import 'database_service.dart';
import 'lro_payment_workflow.dart';
import 'lro_settings_service.dart';
import 'member_lock_service.dart';

/// Applies / reverses "Free Upload" settlements for Member onboarding steps.
///
/// Per the approved design plan:
///  - Only Admin may use it (the screen gates the button to Admin; this service
///    also relies on [MemberLockService] permission checks).
///  - A step that is ALREADY complete/paid is left untouched (idempotent + the
///    "only unpaid steps" rule).
///  - Marking Step 4_LRO as Free Upload runs the same LRO "prepare" stage as a
///    normal payment (Recording Number + Personal Public Notice), making the
///    "LRO Publication" button available. Publishing is still a separate,
///    manual action by the RS.
///  - Every apply/reverse is written to the audit trail via [ActivityService].
class FreeUploadService {
  FreeUploadService(
    this._db,
    this._lock,
    this._activity,
    this._lroSettings,
    this._countySettings, {
    required this.countyId,
  });

  final DatabaseService _db;
  final MemberLockService _lock;
  final ActivityService _activity;
  final LroSettingsService _lroSettings;
  final CountySettingsService _countySettings;
  final String countyId;

  /// Marks [steps] as completed-and-paid via Free Upload for [member].
  /// Returns the updated Member. Steps already complete are skipped.
  Future<Member> apply({
    required Member member,
    required AuthUser actor,
    required List<int> steps,
    required RemunerationSettings settings,
    String? reason,
  }) async {
    var updated = member;
    final appliedSteps = <int>[];
    final now = DateTime.now().toUtc();

    for (final step in steps) {
      if (updated.isStepCompleteAt(step)) continue; // already paid -> skip
      updated = await _lock.setOnboardingStep(
        member: updated,
        actor: actor,
        step: step,
        complete: true,
      );
      updated = updated.withStepPayment(
        step: step,
        payment: StepPayment(
          method: StepPayment.methodFreeUpload,
          paymentDate: now,
          amount: 0.0,
          recordedBy: actor.id,
        ),
      );
      if (step == 4) {
        updated = await _runLroPrepare(updated, actor);
      }
      await _db.upsertMember(updated);
      appliedSteps.add(step);
    }

    if (appliedSteps.isNotEmpty) {
      final names = appliedSteps
          .map((s) => settings.stepName(s))
          .join(', ');
      await _activity.record(
        userName: actor.displayName,
        action:
            '[FREE-UPLOAD-APPLIED] 🆓 Free Upload applied for ${member.fullName} '
            '(SA ID: ${member.saId}) — steps: $names'
            '${reason?.isNotEmpty == true ? ' | reason: $reason' : ''}',
        captureGps: false,
      );
    }
    return updated;
  }

  /// Reverses a prior Free Upload for [steps]: unchecks the step and clears the
  /// Free Upload settlement record. Steps not currently Free-Uploaded are
  /// skipped. Note: if Step 4_LRO was already published, only the local record
  /// is reverted — external posts are NOT removed (the UI warns before this).
  Future<Member> reverse({
    required Member member,
    required AuthUser actor,
    required List<int> steps,
    required RemunerationSettings settings,
    String? reason,
  }) async {
    var updated = member;
    final reversedSteps = <int>[];

    for (final step in steps) {
      final payment = updated.paymentFor(step);
      if (payment == null || !payment.isFreeUpload) continue;
      updated = await _lock.setOnboardingStep(
        member: updated,
        actor: actor,
        step: step,
        complete: false,
      );
      updated = updated.withStepPayment(step: step, payment: null);
      await _db.upsertMember(updated);
      reversedSteps.add(step);
    }

    if (reversedSteps.isNotEmpty) {
      final names = reversedSteps.map((s) => settings.stepName(s)).join(', ');
      await _activity.record(
        userName: actor.displayName,
        action:
            '[FREE-UPLOAD-REVERSED] ↩️ Free Upload reversed for ${member.fullName} '
            '(SA ID: ${member.saId}) — steps: $names'
            '${reason?.isNotEmpty == true ? ' | reason: $reason' : ''}',
        captureGps: false,
      );
    }
    return updated;
  }

  /// Runs the LRO "prepare" stage (Recording Number + Personal Public Notice)
  /// for Step 4_LRO, mirroring the normal payment path. Failures are returned
  /// as [LroWorkflowException] so the caller can surface a non-blocking notice
  /// without losing the Free Upload completion itself.
  Future<Member> _runLroPrepare(Member member, AuthUser actor) async {
    if (member.step4LROComplete && member.lroRecordNo != null) {
      return member; // already prepared
    }
    final workflow = LroPaymentWorkflow(
      _db,
      _activity,
      _lroSettings,
      _countySettings,
      countyId: countyId,
    );
    return workflow.prepare(
      member: member,
      paymentDate: DateTime.now().toUtc(),
      actorId: actor.displayName,
    );
  }
}
