import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backup_auth_service.dart';
import 'backup_service.dart';

/// Runs daily auto-backup at ~02:00 on authorized desktop PCs.
class AutoBackupScheduler {
  AutoBackupScheduler(this._auth, this._backup);

  final BackupAuthService _auth;
  final BackupService _backup;
  Timer? _timer;

  void start() {
    if (kIsWeb) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _tick());
    Future.microtask(_tick);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      final auth = await _auth.checkAuthorization();
      if (!auth.authorized) return;

      final now = DateTime.now();
      // Window: 02:00–02:20 local.
      if (now.hour != 2 || now.minute > 20) return;

      final last = await _auth.lastBackupAt();
      if (last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day) {
        return; // already backed up today
      }

      debugPrint('Auto-backup starting…');
      await _backup.createBackup(auto: true);
      debugPrint('Auto-backup complete');
    } catch (error) {
      debugPrint('Auto-backup failed: $error');
    }
  }
}
