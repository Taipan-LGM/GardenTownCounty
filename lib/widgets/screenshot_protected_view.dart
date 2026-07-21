import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/watermark_settings.dart';
import '../models/member.dart';
import '../services/auth_service.dart';
import '../services/secure_screen_service.dart';

/// Top confidentiality strip shown on locked member profiles.
class ConfidentialityBanner extends StatelessWidget {
  const ConfidentialityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade900],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              WatermarkSettings.bannerText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
        ],
      ),
    );
  }
}

/// Wraps locked-member UI with banners + diagonal watermark.
///
/// On Android/iOS, also enables FLAG_SECURE / isSecure via [SecureScreenService].
/// Desktop/Web cannot block OS screenshots — watermark is the deterrent.
class ScreenshotProtectedView extends StatefulWidget {
  const ScreenshotProtectedView({
    super.key,
    required this.member,
    required this.user,
    required this.child,
    this.onScreenshotAttempt,
  });

  final Member member;
  final AuthUser user;
  final Widget child;
  final VoidCallback? onScreenshotAttempt;

  @override
  State<ScreenshotProtectedView> createState() =>
      _ScreenshotProtectedViewState();
}

class _ScreenshotProtectedViewState extends State<ScreenshotProtectedView> {
  final _stamp = DateTime.now();
  bool _listeningKeys = false;

  @override
  void initState() {
    super.initState();
    SecureScreenService.enableSecureScreen();
    SecureScreenService.setScreenshotDetectedHandler(() {
      widget.onScreenshotAttempt?.call();
      _showWarning();
    });
    // Print Screen detection is best-effort on desktop only.
    // Many OSes do not deliver PrintScreen to the app.
    if (SecureScreenService.isDesktopFallback) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _listeningKeys = true;
    }
  }

  @override
  void dispose() {
    if (_listeningKeys) {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    SecureScreenService.setScreenshotDetectedHandler(null);
    SecureScreenService.disableSecureScreen();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.printScreen) {
      widget.onScreenshotAttempt?.call();
      _showWarning();
      return false;
    }
    return false;
  }

  void _showWarning() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Screenshot Attempt Detected'),
        content: const Text(
          'You have attempted to take a screenshot of a locked member\'s '
          'information.\n\n'
          'This action has been logged. Unauthorized screenshots are '
          'prohibited.\n\n'
          'Please contact the System Administrator if you need to share '
          'this information.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  String get _watermarkText {
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buf = StringBuffer(WatermarkSettings.watermarkText);
    if (WatermarkSettings.showUserInfo) {
      buf
        ..writeln()
        ..writeln(
          'Member: ${widget.member.memberName} ${widget.member.surname}',
        )
        ..writeln(
          'Viewed by: ${widget.user.displayName} (${widget.user.userRole.label})',
        );
    }
    if (WatermarkSettings.showTimestamp) {
      buf
        ..writeln()
        ..write('Date: ${fmt.format(_stamp)}');
    }
    buf
      ..writeln()
      ..write('UNAUTHORIZED SCREENSHOT PROHIBITED');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConfidentialityBanner(),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: WatermarkPainter(
                text: _watermarkText,
                opacity: WatermarkSettings.watermarkOpacity,
                fontSize: WatermarkSettings.watermarkFontSize,
                angle: WatermarkSettings.watermarkAngle,
                spacing: WatermarkSettings.watermarkSpacing,
                color: WatermarkSettings.watermarkColor,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(8),
              color: WatermarkSettings.footerBackgroundColor
                  .withValues(alpha: WatermarkSettings.footerOpacity),
              child: Text(
                WatermarkSettings.footerText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WatermarkPainter extends CustomPainter {
  WatermarkPainter({
    required this.text,
    required this.opacity,
    this.fontSize = 14,
    this.angle = -0.3,
    this.spacing = 200,
    this.color = Colors.black,
  });

  final String text;
  final double opacity;
  final double fontSize;
  final double angle;
  final double spacing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color.withValues(alpha: opacity),
        height: 1.25,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 280);

    for (var y = -size.height; y < size.height * 2; y += spacing) {
      for (var x = -size.width; x < size.width * 2; x += spacing) {
        canvas
          ..save()
          ..translate(x, y)
          ..rotate(angle);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.opacity != opacity;
}
