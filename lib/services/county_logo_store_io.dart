import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveLogoToDisk(
  Uint8List bytes, {
  required bool secondary,
}) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'county_branding'));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  final file = File(
    p.join(dir.path, secondary ? 'secondary_logo.png' : 'primary_logo.png'),
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
