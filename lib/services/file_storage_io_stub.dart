import 'dart:typed_data';

import '../models/lro_document.dart';
import '../models/member_file.dart';
import 'database_service.dart';
import 'sync_engine.dart';

Future<String> copyPhotoToAppDocs({
  required String sourcePath,
  required String memberId,
  required String ext,
}) async {
  throw UnsupportedError('Desktop photo copy not available.');
}

Future<String> uploadPhotoFile({
  required String localPath,
  required String memberId,
  required String ext,
}) async {
  throw UnsupportedError('Desktop photo upload not available.');
}

Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('Desktop file read not available.');
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
  throw UnsupportedError('Desktop file upload not available.');
}

Future<LroDocument?> pickAndUploadLroDocumentDesktop({
  required DatabaseService db,
  required SyncEngine sync,
  required String parentType,
  required String parentId,
  required String uploadedBy,
  required String docType,
  required String description,
  required String sourcePath,
  required String fileName,
}) async {
  throw UnsupportedError('Desktop file upload not available.');
}
