import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lro_document.dart';
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
  static const _maxPhotoBytes = 5 * 1024 * 1024;

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
    var bytes = picked.bytes;
    final path = picked.path;

    // Desktop sometimes returns path only — read file when needed.
    if (bytes == null && path != null && !kIsWeb) {
      final localCopy = await io.copyPhotoToAppDocs(
        sourcePath: path,
        memberId: memberId,
        ext: _extOf(picked.name),
      );
      var photoUrl = '';
      if (FirebaseBootstrap.ready) {
        try {
          photoUrl = await io.uploadPhotoFile(
            localPath: localCopy,
            memberId: memberId,
            ext: _extOf(picked.name),
          );
        } catch (_) {}
      }
      await _db.updateMemberPhoto(
        id: memberId,
        photoLocalPath: localCopy,
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
      );
      await _safePush();
      return localCopy;
    }

    if (bytes == null) {
      throw Exception(
        'Could not read selected image. Try JPG/PNG under 5 MB.',
      );
    }

    if (bytes.length > _maxPhotoBytes) {
      throw Exception('Photo too large (max 5 MB).');
    }

    // Downscale so web localStorage / data-URI stays under quota.
    bytes = await _downscaleImage(bytes, maxSide: 1024);
    final ext = '.png';

    final dataUri = Uri.dataFromBytes(
      bytes,
      mimeType: 'image/png',
    ).toString();

    // Prefs cache is best-effort (web localStorage quota).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webPhotoPrefix$memberId', dataUri);
    } catch (_) {}

    var photoUrl = dataUri;
    if (FirebaseBootstrap.ready) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('member_photos')
            .child(memberId)
            .child('profile$ext');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
        photoUrl = await ref.getDownloadURL();
      } catch (_) {
        // Keep data URI for local display / offline.
      }
    }

    final marker = 'web-photo://$memberId';
    await _db.updateMemberPhoto(
      id: memberId,
      photoLocalPath: marker,
      photoUrl: photoUrl,
    );
    await _safePush();
    return marker;
  }

  Future<void> _safePush() async {
    try {
      await _sync.pushPending();
    } catch (_) {}
  }

  Future<Uint8List> _downscaleImage(
    Uint8List bytes, {
    required int maxSide,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxSide,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bd == null) return bytes;
      return bd.buffer.asUint8List();
    } catch (_) {
      return bytes;
    }
  }

  String _extOf(String name) {
    final ext = p.extension(name);
    return ext.isEmpty ? '.jpg' : ext;
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
      await _safePush();
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

  /// Pick a file and attach it as an [LroDocument] to a case or notice.
  Future<LroDocument?> pickAndUploadLroDocument({
    required String parentType,
    required String parentId,
    required String uploadedBy,
    String description = '',
    String docType = 'other',
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
      var document = LroDocument.create(
        parentType: parentType,
        parentId: parentId,
        fileName: fileName,
        uploadedBy: uploadedBy,
        docType: docType,
        description: description.trim(),
        contentType: _guessContentType(fileName),
        sizeBytes: bytes.length,
      );
      if (FirebaseBootstrap.ready) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('lro_files')
              .child(parentId)
              .child('${document.id}_$fileName');
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          document = document.copyWith(storageUrl: url);
        } catch (_) {}
      }
      await _db.upsertLroDocument(document);
      await _safePush();
      return document;
    }

    final path = picked.path;
    if (path == null) {
      throw Exception('Could not read selected file path.');
    }
    return io.pickAndUploadLroDocumentDesktop(
      db: _db,
      sync: _sync,
      parentType: parentType,
      parentId: parentId,
      uploadedBy: uploadedBy,
      docType: docType,
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
    await _safePush();
  }

  Future<void> deleteFile(MemberFile file) async {
    await _db.softDeleteMemberFile(file.id);
    await _safePush();
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
