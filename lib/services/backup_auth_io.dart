import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import 'backup_auth_service.dart';

Future<BackupAuthInfo> checkFileAuthorization() async {
  final file = await _authFile();
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
}

Future<void> writeAuthFile(String deviceName) async {
  final file = await _authFile();
  await file.writeAsString(
    '${AppConstants.backupAuthKeyLine}\nDEVICE_NAME=$deviceName\n',
    flush: true,
  );
}

Future<String> backupsDirectoryPath({bool auto = false}) async {
  final root = await _gardenTownRoot();
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
  return dir.path;
}

Future<File> _authFile() async {
  final root = await _gardenTownRoot();
  return File(p.join(root.path, AppConstants.backupAuthFileName));
}

Future<Directory> _gardenTownRoot() async {
  final docs = await _userDocumentsDirectory();
  final root = Directory(p.join(docs.path, AppConstants.gardenTownFolderName));
  if (!root.existsSync()) {
    await root.create(recursive: true);
  }
  return root;
}

Future<Directory> _userDocumentsDirectory() async {
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
  return getApplicationDocumentsDirectory();
}
