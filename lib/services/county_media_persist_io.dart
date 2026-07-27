import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> copyPickedFileToAppDocs({
  required String sourcePath,
  required String subfolder,
  required String fileName,
}) async {
  final appDocs = await getApplicationDocumentsDirectory();
  final targetDir = Directory(p.join(appDocs.path, subfolder));
  if (!targetDir.existsSync()) {
    await targetDir.create(recursive: true);
  }
  final targetPath = p.join(targetDir.path, fileName);
  await File(sourcePath).copy(targetPath);
  return targetPath;
}
