import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_auth_service.dart';
import 'database_service.dart';

Future<String> writeBackupFile({
  required Uint8List encrypted,
  required String fileName,
  required String? targetDirectoryPath,
  required BackupAuthService auth,
  required bool auto,
}) async {
  final Directory dir;
  if (targetDirectoryPath != null && targetDirectoryPath.trim().isNotEmpty) {
    dir = Directory(targetDirectoryPath.trim());
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  } else {
    dir = Directory(await auth.backupsDirectoryPath(auto: auto));
  }
  final outPath = p.join(dir.path, fileName);
  await File(outPath).writeAsBytes(encrypted, flush: true);
  if (auto) {
    await _pruneAutoBackups(dir);
  }
  return outPath;
}

Future<Uint8List> readFileBytes(String path) async {
  return Uint8List.fromList(await File(path).readAsBytes());
}

Future<void> addSqliteToArchive(Archive archive, DatabaseService db) async {
  final dbPath = db.databasePath!;
  await db.close();
  try {
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw Exception('Local database file not found.');
    }
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(
      ArchiveFile('garden_town_county.db', dbBytes.length, dbBytes),
    );
    for (final suffix in ['-wal', '-shm']) {
      final side = File('$dbPath$suffix');
      if (side.existsSync()) {
        final sideBytes = await side.readAsBytes();
        archive.addFile(
          ArchiveFile(
            'garden_town_county.db$suffix',
            sideBytes.length,
            sideBytes,
          ),
        );
      }
    }
  } finally {
    await db.reopenAfterRestore();
  }
}

Future<void> addCachedFolder(Archive archive, String folderName) async {
  final appDocs = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(appDocs.path, folderName));
  if (!root.existsSync()) return;

  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = p.relative(entity.path, from: appDocs.path);
    final bytes = await entity.readAsBytes();
    archive.addFile(ArchiveFile(relative, bytes.length, bytes));
  }
}

Future<void> restoreSqliteArchive(
  Archive archive,
  DatabaseService db,
  void Function(double progress)? onProgress,
) async {
  final appDocs = await getApplicationDocumentsDirectory();
  final dbEntry = archive.findFile('garden_town_county.db');
  if (dbEntry == null) {
    throw Exception('Backup does not contain a database.');
  }

  final targetPath =
      db.databasePath ?? p.join(appDocs.path, 'garden_town_county.db');
  await db.close();
  try {
    onProgress?.call(0.4);
    await File(targetPath).writeAsBytes(
      dbEntry.content as List<int>,
      flush: true,
    );
    for (final suffix in ['-wal', '-shm']) {
      final side = File('$targetPath$suffix');
      if (side.existsSync()) await side.delete();
      final sideEntry = archive.findFile('garden_town_county.db$suffix');
      if (sideEntry != null) {
        await side.writeAsBytes(sideEntry.content as List<int>, flush: true);
      }
    }
    onProgress?.call(0.6);
    await _restoreCachedFolder(archive, appDocs.path, 'member_files');
    await _restoreCachedFolder(archive, appDocs.path, 'member_photos');
    await _restoreCachedFolder(archive, appDocs.path, 'lro_files');
  } finally {
    await db.reopenAfterRestore();
  }
  onProgress?.call(0.85);
  await db.markAllPendingSync();
  onProgress?.call(1.0);
}

Future<void> _restoreCachedFolder(
  Archive archive,
  String appDocsPath,
  String folderName,
) async {
  for (final file in archive.files) {
    if (!file.isFile) continue;
    if (!file.name.startsWith('$folderName/')) continue;
    final out = File(p.join(appDocsPath, file.name));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(file.content as List<int>, flush: true);
  }
}

Future<void> _pruneAutoBackups(Directory dir) async {
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.gtb'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  if (files.length <= 7) return;
  for (final old in files.skip(7)) {
    try {
      await old.delete();
    } catch (_) {}
  }
}
