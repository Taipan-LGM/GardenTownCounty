import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import 'backup_auth_io_stub.dart'
    if (dart.library.io) 'backup_auth_io.dart' as io;

class BackupAuthInfo {
  final bool authorized;
  final String? deviceName;

  const BackupAuthInfo({
    required this.authorized,
    this.deviceName,
  });
}

/// Gates Backup & Restore — file marker on desktop, prefs on web.
class BackupAuthService {
  static const _prefsLastBackupKey = 'gtc_last_backup_at';
  static const _prefsWebAuthKey = 'gtc_web_backup_auth';
  static const _prefsWebDeviceKey = 'gtc_web_backup_device';

  Future<BackupAuthInfo> checkAuthorization() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final ok = prefs.getBool(_prefsWebAuthKey) ?? false;
      if (!ok) return const BackupAuthInfo(authorized: false);
      return BackupAuthInfo(
        authorized: true,
        deviceName: prefs.getString(_prefsWebDeviceKey) ?? 'Web browser',
      );
    }

    try {
      return await io.checkFileAuthorization();
    } catch (error) {
      debugPrint('Backup auth check failed: $error');
      return const BackupAuthInfo(authorized: false);
    }
  }

  Future<BackupAuthInfo> enableLocalBackup(String deviceName) async {
    final name = deviceName.trim();
    if (name.isEmpty) {
      throw Exception('Device name is required.');
    }

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsWebAuthKey, true);
      await prefs.setString(_prefsWebDeviceKey, name);
      return BackupAuthInfo(authorized: true, deviceName: name);
    }

    await io.writeAuthFile(name);
    return BackupAuthInfo(authorized: true, deviceName: name);
  }

  Future<String> backupsDirectoryPath({bool auto = false}) async {
    if (kIsWeb) {
      throw Exception('Local backup folders are not available on web.');
    }
    return io.backupsDirectoryPath(auto: auto);
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsLastBackupKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markBackupCompleted(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastBackupKey, at.toUtc().toIso8601String());
  }

  Future<bool> isBackupOverdue({int days = 7}) async {
    final last = await lastBackupAt();
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= days;
  }
}

/// Shared document root helper for IO platforms.
Future<String> resolveUserDocumentsPath() async {
  final docs = await getApplicationDocumentsDirectory();
  return docs.path;
}

String gardenTownJoin(String docsPath, String child) =>
    p.join(docsPath, AppConstants.gardenTownFolderName, child);
