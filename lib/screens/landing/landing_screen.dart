import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../providers/providers.dart';
import '../../widgets/county_logo.dart';

/// Splash / landing with shrink+slide second-logo animation.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2500);
  static const _animDuration = Duration(milliseconds: 1500);
  static const _finalSize = 60.0;

  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_finished) {
        _finished = true;
        widget.onFinished();
      }
    });
    Future<void>.delayed(_holdDuration, () {
      if (mounted && !_started) _beginTransition();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _beginTransition() {
    if (_started || _finished) return;
    setState(() => _started = true);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    // Final top-right center of the small logo.
    final endCx = size.width - CornerLogoOverlay.right - _finalSize / 2;
    final endCy =
        padding.top + CornerLogoOverlay.top + _finalSize / 2;
    final startCx = size.width / 2;
    final startCy = size.height / 2;

    // Full-screen diameter for the round logos.
    final fullDiameter = size.shortestSide;

    return ColoredBox(
      color: AppTheme.forestGreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // First (background) logo — fades out during animation.
          AnimatedBuilder(
            animation: _t,
            builder: (context, child) {
              return Opacity(
                opacity: _started ? (1.0 - _t.value) : 1.0,
                child: child,
              );
            },
            child: Center(
              child: SizedBox(
                width: fullDiameter,
                height: fullDiameter,
                child: const RoundCountyLogo(),
              ),
            ),
          ),

          // Second logo — shrink + slide.
          if (_started)
            AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = _t.value;
                final diameter =
                    fullDiameter + (_finalSize - fullDiameter) * t;
                final cx = startCx + (endCx - startCx) * t;
                final cy = startCy + (endCy - startCy) * t;
                return Positioned(
                  left: cx - diameter / 2,
                  top: cy - diameter / 2,
                  width: diameter,
                  height: diameter,
                  child: const RoundCountyLogo(secondary: true),
                );
              },
            ),

          // Continue control during hold phase.
          if (!_started)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: FilledButton(
                    onPressed: _beginTransition,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.forestGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: Text(strings.continueLabel),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
