import 'backup_auth_service.dart';

Future<BackupAuthInfo> checkFileAuthorization() async {
  return const BackupAuthInfo(authorized: false);
}

Future<void> writeAuthFile(String deviceName) async {
  throw UnsupportedError('Local auth file not available on this platform.');
}

Future<String> backupsDirectoryPath({bool auto = false}) async {
  throw UnsupportedError('Backup folders not available on this platform.');
}
