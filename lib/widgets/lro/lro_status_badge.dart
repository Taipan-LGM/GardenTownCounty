import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Colored chip for LRO case / notice statuses.
///
/// Accepts the raw status code (e.g. `underReview`, `published`) plus an
/// optional human label; falls back to the code itself when no label is
/// supplied.
class LroStatusBadge extends StatelessWidget {
  const LroStatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  /// LRO brand accent, used for "in progress" style statuses.
  static const Color lroOrange = Color(0xFFE54D26);

  Color _colorFor(String code) {
    switch (code) {
      case 'draft':
        return Colors.grey.shade600;
      case 'submitted':
        return AppTheme.sky;
      case 'underReview':
        return lroOrange;
      case 'processing':
        return AppTheme.gold;
      case 'published':
        return AppTheme.forestGreen;
      case 'rejected':
        return AppTheme.brick;
      case 'archived':
        return Colors.grey.shade500;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label ?? status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
