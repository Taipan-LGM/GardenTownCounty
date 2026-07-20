import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/member_file.dart';
import 'database_service.dart';
import 'file_storage_io_stub.dart'
    if (dart.library.io) 'file_storage_io.dart' as io;
import 'firebase_bootstrap.dart';
import 'sync_engine.dart';

class FileStorageService {
  FileStorageService(this._db, this._sync);

  final DatabaseService _db;
  final SyncEngine _sync;

  static const _webPhotoPrefix = 'gtc_member_photo_';

  Future<List<MemberFile>> listForMember(String memberId) =>
      _db.getFilesForMember(memberId);

  /// Pick a member profile photo. Returns a display path / web marker.
  Future<String?> pickMemberPhoto({required String memberId}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final bytes = picked.bytes;
    final path = picked.path;

    if (bytes == null && path == null) {
      throw Exception('Could not read selected image.');
    }

    final ext = p.extension(picked.name).isEmpty
        ? '.jpg'
        : p.extension(picked.name);

    if (kIsWeb || bytes != null) {
      final data = bytes!;
      if (data.length > 2 * 1024 * 1024) {
        throw Exception('Photo too large (max 2 MB).');
      }
      final prefs = await SharedPreferences.getInstance();
      final dataUri = Uri.dataFromBytes(
        data,
        mimeType: _mimeForExt(ext),
      ).toString();
      await prefs.setString('$_webPhotoPrefix$memberId', dataUri);

      var photoUrl = dataUri;
      if (FirebaseBootstrap.ready) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('member_photos')
              .child(memberId)
              .child('profile$ext');
          await ref.putData(data);
          photoUrl = await ref.getDownloadURL();
        } catch (_) {
          // Keep data URI for local display.
        }
      }

      final marker = 'web-photo://$memberId';
      await _db.updateMemberPhoto(
        id: memberId,
        photoLocalPath: marker,
        photoUrl: photoUrl,
      );
      await _sync.pushPending();
      return marker;
    }

    // Desktop path-based copy.
    final localCopy = await io.copyPhotoToAppDocs(
      sourcePath: path!,
      memberId: memberId,
      ext: ext,
    );

    var photoUrl = '';
    if (FirebaseBootstrap.ready) {
      try {
        photoUrl = await io.uploadPhotoFile(
          localPath: localCopy,
          memberId: memberId,
          ext: ext,
        );
      } catch (_) {}
    }

    await _db.updateMemberPhoto(
      id: memberId,
      photoLocalPath: localCopy,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
    );
    await _sync.pushPending();
    return localCopy;
  }

  Future<Uint8List?> loadWebPhotoBytes(String memberId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_webPhotoPrefix$memberId');
    if (raw == null) return null;
    if (raw.startsWith('data:')) {
      return Uri.parse(raw).data?.contentAsBytes();
    }
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<MemberFile?> pickAndUpload({
    required String memberId,
    required String uploadedBy,
    required String description,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final fileName = picked.name;

    if (kIsWeb) {
      final bytes = picked.bytes;
      if (bytes == null) {
        throw Exception('Could not read selected file.');
      }
      var memberFile = MemberFile.create(
        memberId: memberId,
        fileName: fileName,
        description: description.trim(),
        uploadedBy: uploadedBy,
        localPath: null,
        contentType: _guessContentType(fileName),
        sizeBytes: bytes.length,
      );
      if (FirebaseBootstrap.ready) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('member_files')
              .child(memberId)
              .child('${memberFile.id}_$fileName');
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          memberFile = memberFile.copyWith(storageUrl: url);
        } catch (_) {}
      }
      await _db.upsertMemberFile(memberFile);
      await _sync.pushPending();
      return memberFile;
    }

    final path = picked.path;
    if (path == null) {
      throw Exception('Could not read selected file path.');
    }
    return io.pickAndUploadDesktop(
      db: _db,
      sync: _sync,
      memberId: memberId,
      uploadedBy: uploadedBy,
      description: description,
      sourcePath: path,
      fileName: fileName,
    );
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

  String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
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
