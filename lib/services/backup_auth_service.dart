import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class BackupAuthInfo {
  final bool authorized;
  final String? deviceName;

  const BackupAuthInfo({
    required this.authorized,
    this.deviceName,
  });
}

/// Gates Backup & Restore to selected PCs via Documents/GardenTown/.gardentown_auth.
class BackupAuthService {
  static const _prefsLastBackupKey = 'gtc_last_backup_at';

  Future<Directory> gardenTownRoot() async {
    final docs = await _userDocumentsDirectory();
    final root = Directory(p.join(docs.path, AppConstants.gardenTownFolderName));
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<File> authFile() async {
    final root = await gardenTownRoot();
    return File(p.join(root.path, AppConstants.backupAuthFileName));
  }

  Future<Directory> backupsDirectory({bool auto = false}) async {
    final root = await gardenTownRoot();
    final dir = Directory(
      p.join(
        root.path,
        auto
            ? AppConstants.autoBackupsFolderName
            : AppConstants.backupsFolderName,
      ),
    );
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<BackupAuthInfo> checkAuthorization() async {
    if (kIsWeb) {
      return const BackupAuthInfo(authorized: false);
    }
    try {
      final file = await authFile();
      if (!file.existsSync()) {
        return const BackupAuthInfo(authorized: false);
      }
      final lines = await file.readAsLines();
      if (lines.isEmpty ||
          lines.first.trim() != AppConstants.backupAuthKeyLine) {
        return const BackupAuthInfo(authorized: false);
      }
      String? deviceName;
      for (final line in lines.skip(1)) {
        if (line.startsWith('DEVICE_NAME=')) {
          deviceName = line.substring('DEVICE_NAME='.length).trim();
          break;
        }
      }
      return BackupAuthInfo(authorized: true, deviceName: deviceName);
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
    final file = await authFile();
    await file.writeAsString(
      '${AppConstants.backupAuthKeyLine}\nDEVICE_NAME=$name\n',
      flush: true,
    );
    return BackupAuthInfo(authorized: true, deviceName: name);
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

  Future<Directory> _userDocumentsDirectory() async {
    if (!kIsWeb) {
      if (Platform.isWindows) {
        final profile = Platform.environment['USERPROFILE'];
        if (profile != null) {
          return Directory(p.join(profile, 'Documents'));
        }
      }
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final docs = Directory(p.join(home, 'Documents'));
          if (docs.existsSync()) return docs;
          return Directory(home);
        }
      }
    }
    return getApplicationDocumentsDirectory();
  }
}
