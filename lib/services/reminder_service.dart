import 'package:flutter/foundation.dart';

import '../models/member.dart';
import '../models/reminder.dart';
import 'activity_service.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';
import 'sync_engine.dart';

/// Automated onboarding reminder lifecycle (steps 1–4, 24h expiry).
class ReminderService {
  ReminderService(
    this._db,
    this._sync,
    this._notifications, {
    ActivityService? activityService,
  }) : _activity = activityService;

  final DatabaseService _db;
  final SyncEngine _sync;
  final ReminderNotificationService _notifications;
  final ActivityService? _activity;

  Future<void> _persist(Reminder reminder) async {
    await _db.upsertReminder(
      reminder.copyWith(
        updatedAt: DateTime.now().toUtc(),
        pendingSync: true,
      ),
    );
    try {
      await _sync.pushPending();
    } catch (e) {
      debugPrint('Reminder sync push failed: $e');
    }
  }

  Future<Reminder?> _getActiveReminderByMember(String memberId) async {
    final list = await _db.getActiveRemindersByMember(memberId);
    return list.isEmpty ? null : list.first;
  }

  Future<Reminder> createReminder({
    required String memberId,
    required String memberName,
    required String surname,
    required String saId,
    required int stepNumber,
    String? createdBy,
  }) async {
    final existing = await _getActiveReminderByMember(memberId);
    if (existing != null) {
      return updateReminderStep(
        reminderId: existing.id,
        newStep: stepNumber,
        updatedBy: createdBy ?? 'system',
      );
    }

    final reminder = Reminder.createOnboarding(
      memberId: memberId,
      memberName: memberName,
      surname: surname,
      saId: saId,
      stepNumber: stepNumber,
      createdBy: createdBy ?? 'system',
    );
    await _persist(reminder);
    await _notifications.notifyNewReminder(
      memberName: reminder.displayName,
      step: stepNumber,
      stepDescription: ReminderStep.getDescription(stepNumber),
    );
    await _logActivity(
      'Reminder created for ${reminder.displayName} (step $stepNumber)',
    );
    return reminder;
  }

  Future<Reminder> updateReminderStep({
    required String reminderId,
    required int newStep,
    String? updatedBy,
  }) async {
    final reminder = await _db.getReminderById(reminderId);
    if (reminder == null) {
      throw StateError('Reminder $reminderId not found');
    }

    final now = DateTime.now().toUtc();
    final desc = ReminderStep.getDescription(newStep);
    final expiry = now.add(const Duration(hours: 24));
    final updated = reminder.copyWith(
      stepNumber: newStep,
      stepDescription: desc,
      title: 'Step $newStep: $desc',
      description: 'Onboarding reminder — $desc',
      reminderDateTime: expiry,
      expiryDate: expiry,
      updatedAt: now,
      status: 'active',
      isCompleted: false,
      priority: newStep == 1 ? 'High' : 'Medium',
      clearCompleted: true,
      pendingSync: true,
    );
    await _persist(updated);
    await _notifications.notifyReminderUpdated(
      memberName: updated.displayName,
      newStep: newStep,
      stepDescription: desc,
    );
    return updated;
  }

  Future<Reminder> completeReminder({
    required String reminderId,
    String? completedBy,
  }) async {
    final reminder = await _db.getReminderById(reminderId);
    if (reminder == null) {
      throw StateError('Reminder $reminderId not found');
    }
    final now = DateTime.now().toUtc();
    final done = reminder.copyWith(
      isCompleted: true,
      status: 'completed',
      completedDate: now,
      completedBy: completedBy ?? 'system',
      updatedAt: now,
      pendingSync: true,
    );
    await _persist(done);
    await _notifications.notifyReminderCompleted(
      memberName: done.displayName,
    );
    return done;
  }

  Future<Reminder> dismissReminder({
    required String reminderId,
    String? dismissedBy,
  }) async {
    final reminder = await _db.getReminderById(reminderId);
    if (reminder == null) {
      throw StateError('Reminder $reminderId not found');
    }
    final now = DateTime.now().toUtc();
    final done = reminder.copyWith(
      isCompleted: true,
      status: 'expired',
      completedDate: now,
      completedBy: dismissedBy ?? 'system',
      updatedAt: now,
      pendingSync: true,
    );
    await _persist(done);
    return done;
  }

  Future<void> autoExpireReminders() async {
    final now = DateTime.now().toUtc();
    final expired = await _db.getExpiredReminders(now);
    for (final reminder in expired) {
      final done = reminder.copyWith(
        status: 'expired',
        isCompleted: true,
        completedDate: now,
        updatedAt: now,
        pendingSync: true,
      );
      await _persist(done);
      await _notifications.notifyReminderExpired(
        memberName: reminder.displayName,
        step: reminder.stepNumber ?? 0,
      );
    }
  }

  Future<List<Reminder>> getActiveReminders() =>
      _db.getActiveOnboardingReminders();

  Future<List<Reminder>> getRemindersByStep(int stepNumber) =>
      _db.getRemindersByStep(stepNumber);

  Future<ReminderStats> getReminderStats() async {
    final all = await getActiveReminders();
    return ReminderStats(
      total: all.length,
      step1: all.where((r) => r.stepNumber == 1).length,
      step2: all.where((r) => r.stepNumber == 2).length,
      step3: all.where((r) => r.stepNumber == 3).length,
      step4: all.where((r) => r.stepNumber == 4).length,
    );
  }

  /// Derive target step from member onboarding flags.
  /// Returns null when all steps complete (reminder should be removed).
  static int? expectedStepForMember(Member member) {
    if (member.allStepsComplete) return null;
    if (member.step3Global928Complete) return ReminderStep.step4LRO;
    if (member.step2Global528Complete) return ReminderStep.step3Global928;
    if (member.step1MemberInfoComplete) return ReminderStep.step2Global528;
    return ReminderStep.step1MemberInfo;
  }

  /// Sync reminder to member's current onboarding progress.
  Future<void> syncFromMember(
    Member member, {
    String? actor,
    bool isNewMember = false,
  }) async {
    final expected = expectedStepForMember(member);
    final existing = await _getActiveReminderByMember(member.id);

    if (expected == null) {
      if (existing != null) {
        await completeReminder(
          reminderId: existing.id,
          completedBy: actor ?? 'system',
        );
      }
      return;
    }

    if (existing == null) {
      await createReminder(
        memberId: member.id,
        memberName: member.memberName,
        surname: member.surname,
        saId: member.saId,
        stepNumber: isNewMember ? ReminderStep.step1MemberInfo : expected,
        createdBy: actor ?? 'system',
      );
      return;
    }

    if (existing.stepNumber != expected) {
      await updateReminderStep(
        reminderId: existing.id,
        newStep: expected,
        updatedBy: actor ?? 'system',
      );
    } else {
      // Refresh denormalized name fields
      await _persist(
        existing.copyWith(
          memberName: member.memberName,
          surname: member.surname,
          saId: member.saId,
        ),
      );
    }
  }

  Future<void> onMemberCreated(Member member, {String? actor}) async {
    await createReminder(
      memberId: member.id,
      memberName: member.memberName,
      surname: member.surname,
      saId: member.saId,
      stepNumber: ReminderStep.step1MemberInfo,
      createdBy: actor ?? member.createdBy ?? 'system',
    );
  }

  Future<void> onMemberInfoSaved(Member member, {String? actor}) =>
      syncFromMember(member, actor: actor);

  Future<void> onGlobal528Completed(Member member, {String? actor}) =>
      syncFromMember(member, actor: actor);

  Future<void> onGlobal928Completed(Member member, {String? actor}) =>
      syncFromMember(member, actor: actor);

  Future<void> onLROCompleted(Member member, {String? actor}) =>
      syncFromMember(member, actor: actor);

  Future<void> _logActivity(String action) async {
    final activity = _activity;
    if (activity == null) return;
    try {
      await activity.record(
        userName: 'system',
        action: action,
        captureGps: false,
      );
    } catch (e) {
      debugPrint('Reminder activity log failed: $e');
    }
  }
}
