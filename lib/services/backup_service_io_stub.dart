import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_auth_service.dart';
import 'database_service.dart';

Future<String> writeBackupFile({
  required Uint8List encrypted,
  required String fileName,
  required String? targetDirectoryPath,
  required BackupAuthService auth,
  required bool auto,
}) async {
  throw UnsupportedError('Writing backup files requires desktop/mobile.');
}

Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('Reading backup files requires desktop/mobile.');
}

Future<void> addSqliteToArchive(Archive archive, DatabaseService db) async {
  throw UnsupportedError('SQLite backup requires desktop/mobile.');
}

Future<void> addCachedFolder(Archive archive, String folderName) async {}

Future<void> restoreSqliteArchive(
  Archive archive,
  DatabaseService db,
  void Function(double progress)? onProgress,
) async {
  throw UnsupportedError('SQLite restore requires desktop/mobile.');
}
