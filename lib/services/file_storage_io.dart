import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/member_file.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';
import 'sync_engine.dart';

Future<String> copyPhotoToAppDocs({
  required String sourcePath,
  required String memberId,
  required String ext,
}) async {
  final appDocs = await getApplicationDocumentsDirectory();
  final photoDir = Directory(p.join(appDocs.path, 'member_photos', memberId));
  if (!photoDir.existsSync()) {
    await photoDir.create(recursive: true);
  }
  final localCopy = File(p.join(photoDir.path, 'profile$ext'));
  await File(sourcePath).copy(localCopy.path);
  return localCopy.path;
}

Future<String> uploadPhotoFile({
  required String localPath,
  required String memberId,
  required String ext,
}) async {
  final ref = FirebaseStorage.instance
      .ref()
      .child('member_photos')
      .child(memberId)
      .child('profile$ext');
  await ref.putFile(File(localPath));
  return ref.getDownloadURL();
}

Future<Uint8List> readFileBytes(String path) async {
  return File(path).readAsBytes();
}

Future<MemberFile?> pickAndUploadDesktop({
  required DatabaseService db,
  required SyncEngine sync,
  required String memberId,
  required String uploadedBy,
  required String description,
  required String sourcePath,
  required String fileName,
}) async {
  final appDocs = await getApplicationDocumentsDirectory();
  final memberDir = Directory(
    p.join(appDocs.path, 'member_files', memberId),
  );
  if (!memberDir.existsSync()) {
    await memberDir.create(recursive: true);
  }

  final localCopy = File(p.join(memberDir.path, fileName));
  await File(sourcePath).copy(localCopy.path);

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
    } catch (_) {}
  }

  await db.upsertMemberFile(memberFile);
  await sync.pushPending();
  return memberFile;
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
