import 'dart:typed_data';

/// Stub implementation for web platform.
/// File operations are no-ops on web.
Future<Uint8List?> readFileBytes(String path) async {
  return null;
}

Future<void> writeFileBytes(String path, Uint8List bytes) async {
  throw UnsupportedError('File operations not available on web.');
}