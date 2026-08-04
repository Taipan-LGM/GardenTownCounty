// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({Uint8List bytes, String name})?> pickMediaBytesWeb({
  required String accept,
}) async {
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false;
  final completer = Completer<({Uint8List bytes, String name})?>();

  void finish(({Uint8List bytes, String name})? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;
  Timer? cancelProbe;

  changeSub = input.onChange.listen((_) {
    final file = input.files?.firstOrNull;
    if (file == null) {
      finish(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      final data = result is String ? Uri.tryParse(result)?.data : null;
      if (data == null) {
        finish(null);
        return;
      }
      finish((
        bytes: Uint8List.fromList(data.contentAsBytes()),
        name: file.name,
      ));
    });
    reader.onError.listen((_) => finish(null));
    reader.readAsDataUrl(file);
  });

  focusSub = html.window.onFocus.listen((_) {
    cancelProbe?.cancel();
    cancelProbe = Timer(const Duration(milliseconds: 600), () {
      if (input.files?.isEmpty ?? true) finish(null);
    });
  });

  input.style
    ..position = 'fixed'
    ..left = '-9999px';
  html.document.body?.append(input);
  input.click();

  try {
    return await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
  } finally {
    await changeSub.cancel();
    await focusSub.cancel();
    cancelProbe?.cancel();
    input.remove();
  }
}
