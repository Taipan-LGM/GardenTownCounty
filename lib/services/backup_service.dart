import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_auth_service.dart';
import 'backup_crypto.dart';
import 'database_service.dart';

class BackupResult {
  final String filePath;
  final DateTime createdAt;

  const BackupResult({required this.filePath, required this.createdAt});
}

/// Creates and restores encrypted .gtb backups (SQLite + cached files).
class BackupService {
  BackupService(this._db, this._auth);

  final DatabaseService _db;
  final BackupAuthService _auth;

  Future<BackupResult> createBackup({
    bool auto = false,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw Exception('Backups are only supported on desktop/mobile.');
    }

    onProgress?.call(0.05);
    final archive = Archive();

    if (_db.isMemoryMode || _db.databasePath == null) {
      final snapshot = _db.exportMemorySnapshot();
      final bytes = utf8.encode(jsonEncode(snapshot));
      archive.addFile(
        ArchiveFile('memory_snapshot.json', bytes.length, bytes),
      );
    } else {
      // Ensure WAL is flushed by briefly checkpointing via close/reopen.
      final dbPath = _db.databasePath!;
      await _db.close();
      try {
        final dbFile = File(dbPath);
        if (!dbFile.existsSync()) {
          throw Exception('Local database file not found.');
        }
        final dbBytes = await dbFile.readAsBytes();
        archive.addFile(
          ArchiveFile('garden_town_county.db', dbBytes.length, dbBytes),
        );

        // Also include sidecar files if present.
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
        await _db.reopenAfterRestore();
      }
    }

    onProgress?.call(0.35);
    await _addCachedFolder(archive, 'member_files');
    onProgress?.call(0.55);
    await _addCachedFolder(archive, 'member_photos');

    final manifest = utf8.encode(
      jsonEncode({
        'app': 'Garden Town County',
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));

    onProgress?.call(0.7);
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final encrypted = BackupCrypto.encrypt(zipBytes);

    onProgress?.call(0.85);
    final stamp = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
    final prefix = auto ? 'AutoBackup' : 'Backup';
    final dir = await _auth.backupsDirectory(auto: auto);
    final outPath = p.join(dir.path, '${prefix}_$stamp.gtb');
    await File(outPath).writeAsBytes(encrypted, flush: true);

    final now = DateTime.now();
    await _auth.markBackupCompleted(now);
    if (auto) {
      await _pruneAutoBackups(dir);
    }

    onProgress?.call(1.0);
    return BackupResult(filePath: outPath, createdAt: now);
  }

  Future<void> restoreFromFile(
    String gtbPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw Exception('Restore is only supported on desktop/mobile.');
    }

    onProgress?.call(0.05);
    final encrypted = await File(gtbPath).readAsBytes();
    final zipBytes = BackupCrypto.decrypt(Uint8List.fromList(encrypted));
    onProgress?.call(0.25);

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final appDocs = await getApplicationDocumentsDirectory();

    final memoryEntry = archive.findFile('memory_snapshot.json');
    if (memoryEntry != null) {
      final json = utf8.decode(memoryEntry.content as List<int>);
      await _db.importMemorySnapshot(
        jsonDecode(json) as Map<String, dynamic>,
      );
      onProgress?.call(0.8);
      await _db.markAllPendingSync();
      onProgress?.call(1.0);
      return;
    }

    final dbEntry = archive.findFile('garden_town_county.db');
    if (dbEntry == null) {
      throw Exception('Backup does not contain a database.');
    }

    final targetPath =
        _db.databasePath ?? p.join(appDocs.path, 'garden_town_county.db');
    await _db.close();
    try {
      onProgress?.call(0.4);
      await File(targetPath).writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

      // Remove stale WAL/SHM then restore if present in archive.
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
    } finally {
      await _db.reopenAfterRestore();
    }

    onProgress?.call(0.85);
    await _db.markAllPendingSync();
    onProgress?.call(1.0);
  }

  Future<void> _addCachedFolder(Archive archive, String folderName) async {
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
}
