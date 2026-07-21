import 'package:flutter/material.dart';

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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: style ?? Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

/// Title padding that leaves room for the far-right X.
const formDialogTitlePadding = EdgeInsets.fromLTRB(24, 12, 8, 0);
