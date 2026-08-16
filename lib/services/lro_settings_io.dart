import 'dart:io';
import 'dart:typed_data';

/// IO implementation for desktop platforms.
Future<Uint8List?> readFileBytes(String path) async {
  final file = File(path);
  if (await file.exists()) {
    return await file.readAsBytes();
  }
  return null;
}

Future<void> writeFileBytes(String path, Uint8List bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
}