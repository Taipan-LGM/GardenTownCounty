import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/member_file.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';
import 'sync_engine.dart';

class FileStorageService {
  FileStorageService(this._db, this._sync);

  final DatabaseService _db;
  final SyncEngine _sync;

  Future<List<MemberFile>> listForMember(String memberId) =>
      _db.getFilesForMember(memberId);

  /// Opens the system file explorer (Documents preferred) and uploads.
  Future<MemberFile?> pickAndUpload({
    required String memberId,
    required String uploadedBy,
    required String description,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.any,
      initialDirectory: await _documentsDirectory(),
    );

    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) {
      throw Exception('Could not read selected file path.');
    }

    final appDocs = await getApplicationDocumentsDirectory();
    final memberDir = Directory(
      p.join(appDocs.path, 'member_files', memberId),
    );
    if (!memberDir.existsSync()) {
      await memberDir.create(recursive: true);
    }

    final fileName = picked.name;
    final localCopy = File(p.join(memberDir.path, fileName));
    await File(path).copy(localCopy.path);

    var memberFile = MemberFile.create(
      memberId: memberId,
      fileName: fileName,
      description: description.trim(),
      uploadedBy: uploadedBy,
      localPath: localCopy.path,
      contentType: _guessContentType(fileName),
      sizeBytes: await localCopy.length(),
    );

    if (FirebaseBootstrap.ready) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('member_files')
            .child(memberId)
            .child('${memberFile.id}_$fileName');
        await ref.putFile(localCopy);
        final url = await ref.getDownloadURL();
        memberFile = memberFile.copyWith(storageUrl: url);
      } catch (_) {
        // Keep local copy; SyncEngine will retry upload.
      }
    }

    await _db.upsertMemberFile(memberFile);
    await _sync.pushPending();
    return memberFile;
  }

  Future<void> updateDescription(MemberFile file, String description) async {
    final updated = file.copyWith(
      description: description.trim(),
      pendingSync: true,
    );
    await _db.upsertMemberFile(updated);
    await _sync.pushPending();
  }

  Future<void> deleteFile(MemberFile file) async {
    await _db.softDeleteMemberFile(file.id);
    await _sync.pushPending();
  }

  Future<String?> _documentsDirectory() async {
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          return p.join(userProfile, 'Documents');
        }
      }
      if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final docs = p.join(home, 'Documents');
          if (Directory(docs).existsSync()) return docs;
          return home;
        }
      }
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  String _guessContentType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.doc':
        return 'application/msword';
      case '.xls':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}
