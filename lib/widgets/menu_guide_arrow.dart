import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Neon cyan used by the one-time menu onboarding arrow.
const Color kMenuGuideNeonBlue = Color(0xFF00D4FF);

const String kMenuGuideShownPrefsKey = 'menu_guide_shown';

/// Returns true if the MENU guide has already been shown on this device.
Future<bool> isMenuGuideShown() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kMenuGuideShownPrefsKey) ?? false;
}

Future<void> markMenuGuideShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kMenuGuideShownPrefsKey, true);
}

/// Neon blue arrow + "MENU" that pulses 5 times toward the hamburger, then fades.
///
/// Shown once after the landing logo animation completes.
class MenuGuideArrow extends StatefulWidget {
  const MenuGuideArrow({
    super.key,
    required this.onFinished,
  });

  /// Called when the guide finishes (after fade) or is dismissed early.
  final VoidCallback onFinished;

  @override
  State<MenuGuideArrow> createState() => MenuGuideArrowState();
}

class MenuGuideArrowState extends State<MenuGuideArrow>
    with TickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 600);
  static const _pauseBetween = Duration(milliseconds: 200);
  static const _fadeDuration = Duration(milliseconds: 500);
  static const _maxPulses = 5;

  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _scale;
  late final Animation<double> _tilt;
  late final Animation<double> _opacity;

  int _pulseCount = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );
    // Scale 1.0 → 1.2 → 1.0 over one pulse cycle.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    _tilt = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -5.0, end: 5.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 5.0, end: -5.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _pulseController.addStatusListener(_onPulseStatus);
    // Mark as shown immediately so it never replays if app is killed mid-guide.
    markMenuGuideShown();
    _pulseController.forward();
  }

  void _onPulseStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _finished) return;
    _pulseCount++;
    if (_pulseCount >= _maxPulses) {
      _fadeOut();
      return;
    }
    Future<void>.delayed(_pauseBetween, () {
      if (!mounted || _finished) return;
      _pulseController.forward(from: 0);
    });
  }

  Future<void> _fadeOut() async {
    if (_finished) return;
    await _fadeController.forward();
    _complete();
  }

  /// Early dismiss (tap or drawer open).
  void dismiss() {
    if (_finished) return;
    _fadeOut();
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _pulseController.removeStatusListener(_onPulseStatus);
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    // Offset below/right of the menu icon so the tip aims at ~top:20,left:20.
    final top = padding.top + 60;
    const left = 60.0;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _fadeController]),
        builder: (context, _) {
          return Opacity(
            opacity: _opacity.value,
            child: Stack(
              children: [
                Positioned(
                  top: top,
                  left: left,
                  child: Transform.rotate(
                    angle: _tilt.value * math.pi / 180,
                    child: Transform.scale(
                      scale: _scale.value,
                      alignment: Alignment.topLeft,
                      child: const _NeonArrowGraphic(),
                    ),
                  ),
                ),
                Positioned(
                  top: top - 5,
                  left: left + 48,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Text(
                      'MENU',
                      style: TextStyle(
                        color: kMenuGuideNeonBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        shadows: const [
                          Shadow(
                            blurRadius: 12,
                            color: kMenuGuideNeonBlue,
                          ),
                          Shadow(
                            blurRadius: 24,
                            color: Color(0x8800D4FF),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Classic arrow pointing diagonally up-left (toward the hamburger).
class _NeonArrowGraphic extends StatelessWidget {
  const _NeonArrowGraphic();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _MenuArrowPainter(),
    );
  }
}

class _MenuArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = kMenuGuideNeonBlue.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final stroke = Paint()
      ..color = kMenuGuideNeonBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = kMenuGuideNeonBlue
      ..style = PaintingStyle.fill;

    // Shaft from bottom-right toward top-left.
    final start = Offset(size.width * 0.85, size.height * 0.85);
    final tip = Offset(size.width * 0.12, size.height * 0.12);

    for (final paint in [glow, stroke]) {
      canvas.drawLine(start, tip, paint);
    }

    // Arrowhead at tip (pointing up-left).
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + size.width * 0.32, tip.dy + size.height * 0.06)
      ..lineTo(tip.dx + size.width * 0.06, tip.dy + size.height * 0.32)
      ..close();

    canvas.drawPath(head, glow..style = PaintingStyle.fill);
    canvas.drawPath(head, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
