import 'package:flutter/foundation.dart';

import 'database_service.dart';

/// In-app notifications for reminder lifecycle events (admins/secretaries).
class ReminderNotificationService {
  ReminderNotificationService(this._db);

  final DatabaseService _db;

  final List<ReminderNotice> _inbox = [];

  List<ReminderNotice> get recentNotices =>
      List.unmodifiable(_inbox.reversed.take(50));

  Future<void> notifyNewReminder({
    required String memberName,
    required int step,
    required String stepDescription,
  }) async {
    await _send(
      title: '📋 New Reminder',
      body: '$memberName — Step $step: $stepDescription',
      type: 'new_reminder',
    );
  }

  Future<void> notifyReminderUpdated({
    required String memberName,
    required int newStep,
    required String stepDescription,
  }) async {
    await _send(
      title: '🔄 Reminder Updated',
      body: '$memberName — Now Step $newStep: $stepDescription',
      type: 'reminder_updated',
    );
  }

  Future<void> notifyReminderCompleted({
    required String memberName,
  }) async {
    await _send(
      title: '✅ Reminder Completed',
      body: '$memberName has completed all onboarding steps!',
      type: 'reminder_completed',
    );
  }

  Future<void> notifyReminderExpired({
    required String memberName,
    required int step,
  }) async {
    await _send(
      title: '⚠️ Reminder Expired',
      body: '$memberName — Step $step expired after 24 hours',
      type: 'reminder_expired',
    );
  }

  // NEW ADDITION - RS assignment / remuneration notices (Delete methods to revert)
  Future<void> notifySecretaryAssigned({
    required String secretaryId,
    required String memberName,
    required int step,
  }) async {
    await _send(
      title: '👤 Member Assigned',
      body: '$memberName assigned to you (Step $step)',
      type: 'secretary_assigned',
      audienceSecretaryId: secretaryId,
    );
  }

  Future<void> notifyRemunerationEarned({
    required String secretaryId,
    required double amount,
    required String description,
    required String memberName,
  }) async {
    await _send(
      title: '💰 Remuneration Earned',
      body:
          'R ${amount.toStringAsFixed(2)} — $description ($memberName)',
      type: 'remuneration_earned',
      audienceSecretaryId: secretaryId,
    );
  }

  Future<void> notifyRemunerationApproved({
    required String secretaryId,
    required double amount,
    required String description,
  }) async {
    await _send(
      title: '✅ Remuneration Approved',
      body: 'R ${amount.toStringAsFixed(2)} — $description',
      type: 'remuneration_approved',
      audienceSecretaryId: secretaryId,
    );
  }

  Future<void> notifyRemunerationPaid({
    required String secretaryId,
    required double amount,
    required String description,
  }) async {
    await _send(
      title: '💵 Remuneration Paid',
      body: 'R ${amount.toStringAsFixed(2)} — $description',
      type: 'remuneration_paid',
      audienceSecretaryId: secretaryId,
    );
  }

  Future<void> _send({
    required String title,
    required String body,
    required String type,
    String? audienceSecretaryId,
  }) async {
    _inbox.add(
      ReminderNotice(
        title: title,
        body: body,
        type: type,
        timestamp: DateTime.now().toUtc(),
      ),
    );
    debugPrint('[ReminderNotice] $title — $body');

    try {
      final users = await _db.getAppUsers();
      final targets = users.where((u) {
        if (u.deleted || !u.active) return false;
        if (u.isAdmin) return true;
        if (audienceSecretaryId != null && u.id == audienceSecretaryId) {
          return true;
        }
        return false;
      });
      debugPrint(
        'Reminder notice audience: ${targets.length} user(s)',
      );
    } catch (e) {
      debugPrint('Reminder notify recipient lookup failed: $e');
    }
  }
}

class ReminderNotice {
  const ReminderNotice({
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });

  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
}
