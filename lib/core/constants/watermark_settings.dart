import 'package:flutter/material.dart';

/// Admin-configurable watermark defaults for locked-member screens.
class WatermarkSettings {
  static const String watermarkText = '🔒 CONFIDENTIAL - Garden Town County';
  static const double watermarkOpacity = 0.08;
  static const double watermarkFontSize = 14;
  static const Color watermarkColor = Colors.black;
  static const double watermarkAngle = -0.3;
  static const double watermarkSpacing = 200;
  static const bool showUserInfo = true;
  static const bool showTimestamp = true;

  static const String footerText =
      '⚠️ Unauthorized screenshots are prohibited and will be logged';
  static const Color footerBackgroundColor = Colors.red;
  static const double footerOpacity = 0.85;

  static const String bannerText =
      '🔒 CONFIDENTIAL: This member information is locked and protected. '
      'Screenshots are prohibited and will be logged.';
}
