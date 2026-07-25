import '../models/member.dart';
import 'activity_service.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';
import 'reminder_service.dart';
import 'step1_validator.dart';

/// Auto-activates Step 1 when all Member Info fields are filled.
///
/// // NEW ADDITION - Delete this file to revert Step 1 auto-activation.
class StepActivationService {
  StepActivationService(
    this._db,
    this._reminders,
    this._activity, {
    ReminderNotificationService? notifications,
  }) : _notifications = notifications;

  final DatabaseService _db;
  final ReminderService _reminders;
  final ActivityService _activity;
  final ReminderNotificationService? _notifications;

  /// Returns updated member when Step 1 was activated; otherwise [member].
  Future<Member> checkAndActivateStep1(Member member) async {
    if (!Step1Validator.isStep1Complete(member)) {
      return member;
    }
    if (member.step1MemberInfoComplete) {
      return member;
    }

    final now = DateTime.now().toUtc();
    var nextStatus = member.registrationStatus;
    if (nextStatus == 'pending') {
      nextStatus = 'in_progress';
    }

    final updated = member.copyWith(
      step1MemberInfoComplete: true,
      step1CompletionDate: now,
      step1ApprovedBy: 'system',
      registrationStatus: nextStatus,
      updatedAt: now,
      pendingSync: true,
    );

    await _db.upsertMember(updated);

    try {
      await _reminders.onMemberInfoSaved(updated, actor: 'system');
    } catch (_) {
      // Reminder sync is best-effort; Step 1 flag already saved.
    }

    await _notifications?.notifyStepAutoActivated(
      memberName: updated.fullName,
      stepNumber: 1,
      stepDescription: 'Member Info',
    );

    await _activity.record(
      userName: 'System',
      action: 'step1_auto_activated ${updated.fullName}',
      captureGps: false,
    );

    return updated;
  }
}
