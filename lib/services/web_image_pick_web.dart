import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Native browser file input — more reliable than FilePicker on Flutter web.
Future<({Uint8List bytes, String name})?> pickImageBytesWeb() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  final completer = Completer<({Uint8List bytes, String name})?>();

  void finish(({Uint8List bytes, String name})? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;
  Timer? cancelProbe;

  void cleanup() {
    changeSub?.cancel();
    focusSub?.cancel();
    cancelProbe?.cancel();
    try {
      input.remove();
    } catch (_) {}
  }

  changeSub = input.onChange.listen((_) async {
    cancelProbe?.cancel();
    try {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        finish(null);
        return;
      }

      // Data URL path is the most reliable across dart2js / browsers.
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        try {
          final result = reader.result;
          Uint8List? bytes;

          if (result is String) {
            // data:image/...;base64,....
            final data = Uri.parse(result).data;
            if (data != null) {
              bytes = Uint8List.fromList(data.contentAsBytes());
            } else if (result.contains(',')) {
              final b64 = result.split(',').last;
              bytes = Uint8List.fromList(base64Decode(b64));
            }
          } else if (result is ByteBuffer) {
            bytes = result.asUint8List();
          } else if (result is TypedData) {
            bytes = Uint8List.fromList(
              result.buffer.asUint8List(
                result.offsetInBytes,
                result.lengthInBytes,
              ),
            );
          }

          if (bytes == null || bytes.isEmpty) {
            finish(null);
            return;
          }
          finish((bytes: bytes, name: file.name.isEmpty ? 'photo.jpg' : file.name));
        } catch (_) {
          finish(null);
        }
      });
      reader.onError.listen((_) => finish(null));
      reader.readAsDataUrl(file);
    } catch (_) {
      finish(null);
    }
  });

  // If user cancels the dialog, onChange never fires — detect via focus return.
  focusSub = html.window.onFocus.listen((_) {
    cancelProbe?.cancel();
    cancelProbe = Timer(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted &&
          (input.files == null || input.files!.isEmpty)) {
        finish(null);
      }
    });
  });

  input.style
    ..position = 'fixed'
    ..left = '-9999px'
    ..top = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0';
  html.document.body?.append(input);

  // Must run in same user-gesture turn as the button tap.
  input.click();

  try {
    return await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
  } finally {
    cleanup();
  }
}
