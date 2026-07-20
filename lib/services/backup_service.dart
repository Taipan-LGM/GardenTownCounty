import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'backup_auth_service.dart';
import 'backup_crypto.dart';
import 'backup_service_io_stub.dart'
    if (dart.library.io) 'backup_service_io.dart' as io;
import 'database_service.dart';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart' as web_dl;

class BackupResult {
  final String filePath;
  final DateTime createdAt;

  const BackupResult({required this.filePath, required this.createdAt});
}

/// Creates and restores encrypted .gtb backups.
class BackupService {
  BackupService(this._db, this._auth);

  final DatabaseService _db;
  final BackupAuthService _auth;

  Future<BackupResult> createBackup({
    bool auto = false,
    String? targetDirectoryPath,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.05);
    final archive = await _buildArchive(onProgress);
    onProgress?.call(0.7);

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final encrypted = BackupCrypto.encrypt(zipBytes);
    onProgress?.call(0.85);

    final stamp = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
    final prefix = auto ? 'AutoBackup' : 'Backup';
    final fileName = '${prefix}_$stamp.gtb';

    late final String outPath;
    if (kIsWeb) {
      web_dl.downloadBytes(encrypted, fileName);
      outPath = 'download://$fileName';
    } else {
      outPath = await io.writeBackupFile(
        encrypted: encrypted,
        fileName: fileName,
        targetDirectoryPath: targetDirectoryPath,
        auth: _auth,
        auto: auto,
      );
    }

    final now = DateTime.now();
    await _auth.markBackupCompleted(now);
    onProgress?.call(1.0);
    return BackupResult(filePath: outPath, createdAt: now);
  }

  Future<void> restoreFromFile(
    String gtbPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw Exception('Use restoreFromBytes on web.');
    }
    onProgress?.call(0.05);
    final encrypted = await io.readFileBytes(gtbPath);
    await restoreFromBytes(encrypted, onProgress: onProgress);
  }

  Future<void> restoreFromBytes(
    Uint8List encrypted, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);
    final zipBytes = BackupCrypto.decrypt(encrypted);
    onProgress?.call(0.25);
    final archive = ZipDecoder().decodeBytes(zipBytes);

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

    if (kIsWeb) {
      throw Exception(
        'This backup was made on desktop and cannot be restored in the browser. '
        'Use the desktop app, or restore a web-made backup.',
      );
    }

    await io.restoreSqliteArchive(archive, _db, onProgress);
  }

  Future<Archive> _buildArchive(void Function(double progress)? onProgress) async {
    final archive = Archive();

    if (_db.isMemoryMode || _db.databasePath == null || kIsWeb) {
      final snapshot = _db.exportMemorySnapshot();
      final bytes = utf8.encode(jsonEncode(snapshot));
      archive.addFile(
        ArchiveFile('memory_snapshot.json', bytes.length, bytes),
      );
    } else {
      await io.addSqliteToArchive(archive, _db);
    }

    onProgress?.call(0.35);
    if (!kIsWeb) {
      await io.addCachedFolder(archive, 'member_files');
      onProgress?.call(0.55);
      await io.addCachedFolder(archive, 'member_photos');
    }

    final manifest = utf8.encode(
      jsonEncode({
        'app': 'Garden Town County',
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'platform': kIsWeb ? 'web' : 'desktop',
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    return archive;
  }
}
