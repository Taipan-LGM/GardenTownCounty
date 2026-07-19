import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Full-bleed county logo — 100% of viewport, no margins.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        AppConstants.logoAsset,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stack) {
          return Container(
            color: const Color(0xFF1B4D3E),
            alignment: Alignment.center,
            child: const Text(
              'Garden Town County\nAssembly',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD4A017),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}
