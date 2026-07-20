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
