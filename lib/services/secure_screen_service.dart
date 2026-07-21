import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel for screenshot prevention on Android / iOS.
///
/// Desktop (Windows / macOS / Linux) and Web cannot block OS screenshots —
/// use watermark overlays as the fallback.
class SecureScreenService {
  SecureScreenService._();

  static const MethodChannel _channel =
      MethodChannel('com.gardentown.secure');

  static bool get supportsNativeSecureFlag =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isDesktopFallback =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  static Future<void> enableSecureScreen() async {
    if (!supportsNativeSecureFlag) return;
    try {
      await _channel.invokeMethod<void>('enableSecureScreen');
    } catch (e) {
      debugPrint('Failed to enable secure screen: $e');
    }
  }

  static Future<void> disableSecureScreen() async {
    if (!supportsNativeSecureFlag) return;
    try {
      await _channel.invokeMethod<void>('disableSecureScreen');
    } catch (e) {
      debugPrint('Failed to disable secure screen: $e');
    }
  }

  /// Optional callback when iOS reports a screenshot while secure mode is on.
  static void setScreenshotDetectedHandler(VoidCallback? handler) {
    if (!supportsNativeSecureFlag) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'screenshotDetected') {
        handler?.call();
      }
      return null;
    });
  }
}
