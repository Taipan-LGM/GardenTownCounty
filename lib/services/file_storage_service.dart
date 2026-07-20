import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lro_document.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import 'database_service.dart';
import 'file_storage_io_stub.dart'
    if (dart.library.io) 'file_storage_io.dart' as io;
import 'firebase_bootstrap.dart';
import 'sync_engine.dart';
import 'web_image_pick_stub.dart'
    if (dart.library.html) 'web_image_pick_web.dart' as web_pick;

class MemberPhotoPickResult {
  const MemberPhotoPickResult({
    required this.path,
    required this.bytes,
    this.photoUrl,
  });

  final String path;
  final Uint8List bytes;
  final String? photoUrl;
}

class FileStorageService {
  FileStorageService(this._db, this._sync);

  final DatabaseService _db;
  final SyncEngine _sync;

  static const _webPhotoPrefix = 'gtc_member_photo_';
  static const _maxPhotoBytes = 12 * 1024 * 1024;

  final Map<String, Uint8List> _photoMemory = {};

  Future<List<MemberFile>> listForMember(String memberId) =>
      _db.getFilesForMember(memberId);

  /// Pick a member profile photo. Always returns display bytes on success.
  Future<MemberPhotoPickResult?> pickMemberPhoto({
    required String memberId,
  }) async {
    Uint8List? bytes;
    String fileName = 'photo.jpg';

    // Web: native <input type=file> — FilePicker often returns empty bytes.
    if (kIsWeb) {
      final picked = await web_pick.pickImageBytesWeb();
      if (picked == null) return null;
      bytes = picked.bytes;
      fileName = picked.name;
    } else {
      final picked = await _pickImageFileDesktop();
      if (picked == null) return null;
      bytes = picked.bytes;
      fileName = picked.name;
      final path = picked.path;

      if ((bytes == null || bytes.isEmpty) && path != null) {
        final localCopy = await io.copyPhotoToAppDocs(
          sourcePath: path,
          memberId: memberId,
          ext: _extOf(fileName),
        );
        String? photoUrl;
        if (FirebaseBootstrap.ready) {
          try {
            photoUrl = await io.uploadPhotoFile(
              localPath: localCopy,
              memberId: memberId,
              ext: _extOf(fileName),
            );
          } catch (_) {}
        }
        Uint8List preview;
        try {
          preview = await io.readFileBytes(localCopy);
        } catch (_) {
          preview = Uint8List(0);
        }
        if (preview.isNotEmpty) {
          _photoMemory[memberId] = preview;
        }
        await _persistPhotoMeta(
          memberId: memberId,
          localPath: localCopy,
          photoUrl: photoUrl,
        );
        await _safePush();
        return MemberPhotoPickResult(
          path: localCopy,
          bytes: preview.isNotEmpty ? preview : Uint8List(0),
          photoUrl: photoUrl,
        );
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception(
        'Could not read image bytes. Please choose a JPG or PNG file.',
      );
    }

    if (bytes.length > _maxPhotoBytes) {
      throw Exception('Photo too large (max 12 MB).');
    }

    var imageBytes = bytes;
    try {
      imageBytes = await _downscaleImage(imageBytes, maxSide: 720);
    } catch (_) {}

    // Cache for this session first — UI must show photo even if prefs fail.
    _photoMemory[memberId] = imageBytes;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Store raw base64 only (never data-URI in Firestore).
      await prefs.setString(
        '$_webPhotoPrefix$memberId',
        base64Encode(imageBytes),
      );
    } catch (_) {}

    String? photoUrl;
    if (FirebaseBootstrap.ready) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('member_photos')
            .child(memberId)
            .child('profile.png');
        await ref.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/png'),
        );
        photoUrl = await ref.getDownloadURL();
      } catch (_) {}
    }

    final marker = 'web-photo://$memberId';
    await _persistPhotoMeta(
      memberId: memberId,
      localPath: marker,
      photoUrl: photoUrl,
    );
    // Do not block UI on sync.
    unawaited(_safePush());

    return MemberPhotoPickResult(
      path: marker,
      bytes: imageBytes,
      photoUrl: photoUrl,
    );
  }

  Future<PlatformFile?> _pickImageFileDesktop() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.single;
      }
    } catch (_) {}

    final fallback = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (fallback == null || fallback.files.isEmpty) return null;
    return fallback.files.single;
  }

  Future<void> _persistPhotoMeta({
    required String memberId,
    required String localPath,
    String? photoUrl,
  }) async {
    final existing = await _db.getMemberById(memberId);
    if (existing == null) {
      final short = memberId.replaceAll('-', '');
      final saId = short.length >= 13 ? short.substring(0, 13) : short;
      await _db.upsertMember(
        Member(
          id: memberId,
          saId: saId,
          globalRecordNo: 'P-${memberId.substring(0, 8)}',
          memberName: 'Photo',
          surname: 'Pending',
          photoLocalPath: localPath,
          photoUrl: photoUrl,
          updatedAt: DateTime.now().toUtc(),
          pendingSync: true,
        ),
      );
      return;
    }
    await _db.updateMemberPhoto(
      id: memberId,
      photoLocalPath: localPath,
      photoUrl: photoUrl,
    );
  }

  Future<void> _safePush() async {
    try {
      await _sync.pushPending();
    } catch (_) {}
  }

  void unawaited(Future<void> future) {
    future.then((_) {}, onError: (_) {});
  }

  Future<Uint8List> _downscaleImage(
    Uint8List bytes, {
    required int maxSide,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxSide,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return bytes;
      return bd.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  String _extOf(String name) {
    final ext = p.extension(name);
    return ext.isEmpty ? '.jpg' : ext;
  }

  Future<Uint8List?> loadWebPhotoBytes(String memberId) async {
    final cached = _photoMemory[memberId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_webPhotoPrefix$memberId');
      if (raw == null) return null;
      if (raw.startsWith('data:')) {
        final bytes = Uri.parse(raw).data?.contentAsBytes();
        if (bytes != null) _photoMemory[memberId] = bytes;
        return bytes;
      }
      final bytes = base64Decode(raw);
      _photoMemory[memberId] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Uint8List? peekPhotoBytes(String memberId) => _photoMemory[memberId];

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
      var doc = LroDocument.create(
        parentType: parentType,
        parentId: parentId,
        fileName: fileName,
        uploadedBy: uploadedBy,
        docType: docType,
        description: description,
        contentType: _guessContentType(fileName),
        sizeBytes: bytes.length,
      );
      if (FirebaseBootstrap.ready) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('lro_files')
              .child(parentId)
              .child('${doc.id}_$fileName');
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          doc = doc.copyWith(storageUrl: url);
        } catch (_) {}
      }
      await _db.upsertLroDocument(doc);
      await _safePush();
      return doc;
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
      description: description,
      docType: docType,
      sourcePath: path,
      fileName: fileName,
    );
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
