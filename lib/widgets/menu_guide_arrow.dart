import 'package:flutter/material.dart';

/// White fill / black outline for the always-on MENU guide.
const Color kMenuGuideFill = Colors.white;
const Color kMenuGuideOutline = Colors.black;

/// Horizontal arrow + "MENU" in one row, pointing left toward the hamburger.
///
/// Shown every time the landing logo animation completes (refresh / restart /
/// new login) — no SharedPreferences gate.
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
    // Sit just below/right of the hamburger; arrow points left toward it.
    final top = padding.top + 52;
    const left = 52.0;

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
    // White fill with black outline via stacked text strokes.
    const style = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
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
              ..strokeWidth = 4
              ..color = kMenuGuideOutline,
          ),
        ),
        const Text(
          'MENU',
          style: TextStyle(
            color: kMenuGuideFill,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Horizontal arrow pointing left (←) toward the hamburger.
class _HorizontalArrowGraphic extends StatelessWidget {
  const _HorizontalArrowGraphic();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(72, 28),
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
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillStroke = Paint()
      ..color = kMenuGuideFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = kMenuGuideFill
      ..style = PaintingStyle.fill;

    final outlineFill = Paint()
      ..color = kMenuGuideOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    final cy = size.height / 2;
    // Tip on the left (toward hamburger), shaft to the right.
    final tip = Offset(2, cy);
    final shaftEnd = Offset(size.width - 2, cy);

    // Shaft outline then white.
    canvas.drawLine(shaftEnd, tip, outline);
    canvas.drawLine(shaftEnd, tip, fillStroke);

    // Arrowhead pointing left.
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + size.width * 0.38, tip.dy - size.height * 0.42)
      ..lineTo(tip.dx + size.width * 0.38, tip.dy + size.height * 0.42)
      ..close();

    canvas.drawPath(head, fill);
    canvas.drawPath(head, outlineFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
