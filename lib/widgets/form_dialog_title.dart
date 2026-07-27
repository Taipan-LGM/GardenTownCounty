import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Standard dialog / form title with close (X) pinned to the far right.
class FormDialogTitle extends StatelessWidget {
  const FormDialogTitle({
    super.key,
    required this.title,
    this.onClose,
    this.style,
  });

  final String title;
  final VoidCallback? onClose;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = TextStyle(
      color: isDark ? Colors.white : AppTheme.bodyText,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: style ?? defaultStyle,
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : AppTheme.bodyText,
          ),
        ),
      ],
    );
  }
}

/// Title padding that leaves room for the far-right X.
const formDialogTitlePadding = EdgeInsets.fromLTRB(24, 12, 8, 0);
