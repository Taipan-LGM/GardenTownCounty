import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reminder_service.dart';

/// Background timer that expires onboarding reminders after 24 hours.
class ReminderExpiryService {
  ReminderExpiryService._();

  static Timer? _timer;
  static ReminderService? _service;

  static void start(ReminderService service) {
    _service = service;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(_checkAndExpireReminders());
    });
    // Run once shortly after start.
    unawaited(_checkAndExpireReminders());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _service = null;
  }

  static Future<void> _checkAndExpireReminders() async {
    final service = _service;
    if (service == null) return;
    try {
      await service.autoExpireReminders();
    } catch (e) {
      debugPrint('Error expiring reminders: $e');
    }
  }

  static Future<void> manualExpireNow() async {
    await _checkAndExpireReminders();
  }
}
