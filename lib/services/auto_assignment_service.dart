import '../models/app_user.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';

/// Fair distribution of members among active Recording Secretaries.
///
/// // NEW ADDITION - Delete this file to revert auto-assignment.
class AutoAssignmentService {
  AutoAssignmentService(this._db, {ReminderNotificationService? notifications})
      : _notifications = notifications;

  final DatabaseService _db;
  final ReminderNotificationService? _notifications;

  /// Secretary with the least assigned members (even distribution).
  Future<AppUser?> findBestSecretary() async {
    final secretaries = await _db.getActiveRecordingSecretaries();
    if (secretaries.isEmpty) return null;

    AppUser? best;
    var minCount = 1 << 30;
    for (final secretary in secretaries) {
      final count = await _db.countAssignedMembers(secretary.id);
      if (count < minCount) {
        minCount = count;
        best = secretary;
      }
    }
    return best;
  }

  /// Auto-assign secretary to reminder + linked member.
  Future<AppUser?> autoAssignToReminder(String reminderId) async {
    final best = await findBestSecretary();
    if (best == null) return null;

    final reminder = await _db.assignSecretaryToReminder(
      reminderId: reminderId,
      secretaryId: best.id,
      assignmentMethod: 'auto',
    );

    await _db.assignSecretaryToMember(
      memberId: reminder.memberId,
      secretaryId: best.id,
      assignmentMethod: 'auto',
    );

    await _notifications?.notifySecretaryAssigned(
      secretaryId: best.id,
      memberName: reminder.displayName,
      step: reminder.stepNumber ?? 0,
    );

    return best;
  }
}
