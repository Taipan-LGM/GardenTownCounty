import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Full-viewport landing — logo centred, aspect ratio preserved (not stretched).
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.forestGreen,
      child: SizedBox.expand(
        child: Center(
          child: Image.asset(
            AppConstants.logoAsset,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stack) {
              return const Text(
                'Garden Town County\nAssembly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
