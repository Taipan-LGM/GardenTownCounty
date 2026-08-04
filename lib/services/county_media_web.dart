import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String createObjectUrl(Uint8List bytes, String contentType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  return web.URL.createObjectURL(blob);
}
