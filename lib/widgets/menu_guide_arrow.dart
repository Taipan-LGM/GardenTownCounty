import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// White fill / black outline for the MENU guide.
const Color kMenuGuideFill = Colors.white;
const Color kMenuGuideOutline = Colors.black;

const String kMenuGuideLoginCountKey = 'menu_guide_login_count';
const String kMenuGuidePendingKey = 'menu_guide_pending';
const int kMenuGuideMaxLogins = 3;

/// Call after a successful sign-in. Counts toward the first 3 logins and
/// arms the guide for this session's landing animation.
Future<void> registerMenuGuideLoginAttempt() async {
  final prefs = await SharedPreferences.getInstance();
  final count = prefs.getInt(kMenuGuideLoginCountKey) ?? 0;
  if (count >= kMenuGuideMaxLogins) {
    await prefs.setBool(kMenuGuidePendingKey, false);
    return;
  }
  await prefs.setInt(kMenuGuideLoginCountKey, count + 1);
  await prefs.setBool(kMenuGuidePendingKey, true);
}

/// Returns true once if this login armed the guide; clears the pending flag.
Future<bool> takeMenuGuidePending() async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getBool(kMenuGuidePendingKey) ?? false;
  if (pending) {
    await prefs.setBool(kMenuGuidePendingKey, false);
  }
  return pending;
}

/// Horizontal bold arrow + "MENU" in one row, pointing left at the hamburger.
///
/// Shown only for the first [kMenuGuideMaxLogins] consecutive logins.
class MenuGuideArrow extends StatefulWidget {
  const MenuGuideArrow({
    super.key,
    required this.onFinished,
  });

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

    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _pulseController.addStatusListener(_onPulseStatus);
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
    // Far left, next to the hamburger (top-left).
    final top = padding.top + 32;
    const left = 48.0;

    return SizedBox.expand(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _fadeController]),
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: top,
                    left: left,
                    child: Transform.scale(
                      scale: _scale.value,
                      alignment: Alignment.centerLeft,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _HorizontalArrowGraphic(),
                          SizedBox(width: 10),
                          _OutlinedMenuLabel(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OutlinedMenuLabel extends StatelessWidget {
  const _OutlinedMenuLabel();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.6,
      height: 1,
    );
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Text(
          'MENU',
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7
              ..strokeJoin = StrokeJoin.round
              ..color = kMenuGuideOutline,
          ),
        ),
        const Text(
          'MENU',
          style: TextStyle(
            color: kMenuGuideFill,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _HorizontalArrowGraphic extends StatelessWidget {
  const _HorizontalArrowGraphic();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(80, 32),
      painter: _HorizontalArrowPainter(),
    );
  }
}

class _HorizontalArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = kMenuGuideOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillStroke = Paint()
      ..color = kMenuGuideFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = kMenuGuideFill
      ..style = PaintingStyle.fill;

    final outlineFill = Paint()
      ..color = kMenuGuideOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.round;

    final cy = size.height / 2;
    final tip = Offset(2, cy);
    final shaftEnd = Offset(size.width - 2, cy);

    canvas.drawLine(shaftEnd, tip, outline);
    canvas.drawLine(shaftEnd, tip, fillStroke);

    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + size.width * 0.40, tip.dy - size.height * 0.45)
      ..lineTo(tip.dx + size.width * 0.40, tip.dy + size.height * 0.45)
      ..close();

    canvas.drawPath(head, fill);
    canvas.drawPath(head, outlineFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
