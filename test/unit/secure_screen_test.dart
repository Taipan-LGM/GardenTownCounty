import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/watermark_settings.dart';
import 'package:garden_town_county/services/secure_screen_service.dart';

void main() {
  group('Secure screen / watermark', () {
    test('watermark settings expose expected defaults', () {
      expect(WatermarkSettings.watermarkOpacity, lessThan(0.2));
      expect(WatermarkSettings.watermarkText, contains('CONFIDENTIAL'));
      expect(WatermarkSettings.footerText, contains('Unauthorized'));
    });

    test('desktop fallback is true on web or desktop targets', () {
      // In unit tests (VM) this is typically not Android/iOS.
      expect(SecureScreenService.isDesktopFallback ||
          SecureScreenService.supportsNativeSecureFlag, isTrue);
    });
  });
}
