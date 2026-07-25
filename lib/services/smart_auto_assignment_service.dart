import '../models/reminder.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';

/// Result of bulk fair auto-assignment across unassigned reminders.
///
/// // NEW ADDITION - Delete with smart_auto_assignment_service.dart to revert.
class AutoAssignResult {
  AutoAssignResult({
    this.success = false,
    this.assignedCount = 0,
    this.totalUnassigned = 0,
    this.message = '',
  });

  bool success;
  int assignedCount;
  int totalUnassigned;
  String message;
}

/// Assigns ALL unassigned active reminders using least-workload distribution.
///
/// // NEW ADDITION - Delete this file to revert smart Auto-Assign All.
class SmartAutoAssignmentService {
  SmartAutoAssignmentService(
    this._db, {
    ReminderNotificationService? notifications,
  }) : _notifications = notifications;

  final DatabaseService _db;
  final ReminderNotificationService? _notifications;

  Future<AutoAssignResult> autoAssignAll() async {
    final result = AutoAssignResult();

    final secretaries = await _db.getActiveRecordingSecretaries();
    if (secretaries.isEmpty) {
      result.message = 'No active Recording Secretaries available.';
      result.success = false;
      return result;
    }

    final unassigned = await _db.getUnassignedActiveReminders();
    if (unassigned.isEmpty) {
      result.message = 'All reminders already have assigned Secretaries!';
      result.success = true;
      return result;
    }

    final assignmentCounts = <String, int>{};
    for (final secretary in secretaries) {
      assignmentCounts[secretary.id] =
          await _db.countAssignedReminders(secretary.id);
    }

    // Higher step first, then sooner expiry.
    final sorted = List<Reminder>.from(unassigned)
      ..sort((a, b) {
        final sa = a.stepNumber ?? 0;
        final sb = b.stepNumber ?? 0;
        if (sa != sb) return sb.compareTo(sa);
        final ea = a.expiryDate ?? a.reminderDateTime;
        final eb = b.expiryDate ?? b.reminderDateTime;
        return ea.compareTo(eb);
      });

    var assignedCount = 0;
    for (final reminder in sorted) {
      String? bestId;
      var minCount = 1 << 30;
      for (final secretary in secretaries) {
        final count = assignmentCounts[secretary.id] ?? 0;
        if (count < minCount) {
          minCount = count;
          bestId = secretary.id;
        }
      }
      if (bestId == null) break;

      await _db.assignSecretaryToReminder(
        reminderId: reminder.id,
        secretaryId: bestId,
        assignmentMethod: 'auto',
      );
      await _db.assignSecretaryToMember(
        memberId: reminder.memberId,
        secretaryId: bestId,
        assignmentMethod: 'auto',
      );

      assignmentCounts[bestId] = (assignmentCounts[bestId] ?? 0) + 1;
      assignedCount++;

      await _notifications?.notifySecretaryAssigned(
        secretaryId: bestId,
        memberName: reminder.displayName,
        step: reminder.stepNumber ?? 0,
      );
    }

    result.success = true;
    result.assignedCount = assignedCount;
    result.totalUnassigned = unassigned.length;
    result.message =
        'Successfully assigned $assignedCount of ${unassigned.length} reminders.';
    return result;
  }
}
