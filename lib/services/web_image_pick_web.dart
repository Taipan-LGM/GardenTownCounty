import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Native browser file input — more reliable than FilePicker on Flutter web.
Future<({Uint8List bytes, String name})?> pickImageBytesWeb() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/gif,image/*'
    ..multiple = false;

  final completer = Completer<({Uint8List bytes, String name})?>();

  void finish(({Uint8List bytes, String name})? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  input.onChange.listen((_) {
    try {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        finish(null);
        return;
      }
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        try {
          final result = reader.result;
          if (result is ByteBuffer) {
            finish((bytes: result.asUint8List(), name: file.name));
          } else {
            finish(null);
          }
        } catch (_) {
          finish(null);
        }
      });
      reader.onError.listen((_) => finish(null));
      reader.readAsArrayBuffer(file);
    } catch (_) {
      finish(null);
    }
  });

  html.document.body?.append(input);
  input.style.display = 'none';
  input.click();

  return completer.future
      .timeout(const Duration(minutes: 3), onTimeout: () => null)
      .whenComplete(input.remove);
}
