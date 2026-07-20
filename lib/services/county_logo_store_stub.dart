import 'dart:typed_data';

Future<String> saveLogoToDisk(
  Uint8List bytes, {
  required bool secondary,
}) async {
  throw UnsupportedError('Logo disk save is not available on this platform.');
}
