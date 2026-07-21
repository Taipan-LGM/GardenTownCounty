import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/member.dart';
import '../widgets/form_dialog_title.dart';

/// Inline warning shown under SA ID / Global Record when a duplicate is found.
class DuplicateWarningWidget extends StatelessWidget {
  const DuplicateWarningWidget({
    super.key,
    required this.field,
    required this.value,
    required this.isDuplicate,
    this.onViewExisting,
  });

  final String field;
  final String value;
  final bool isDuplicate;
  final VoidCallback? onViewExisting;

  @override
  Widget build(BuildContext context) {
    if (!isDuplicate) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Duplicate $field Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                Text(
                  'Value: $value',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (onViewExisting != null)
            TextButton(
              onPressed: onViewExisting,
              child: const Text('View Existing'),
            ),
        ],
      ),
    );
  }
}

/// Dialog helper for hard duplicate failures on save.
class DuplicateErrorHandler {
  DuplicateErrorHandler._();

  static Future<void> showDuplicateError(
    BuildContext context, {
    required String field,
    required String value,
    VoidCallback? onViewExisting,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const FormDialogTitle(
          title: 'Duplicate Detected',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A member with this $field already exists.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Field: $field',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'Value: $value',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Each member must have a unique SA ID and Global Record No.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (onViewExisting != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onViewExisting();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.forestGreen,
              ),
              child: const Text('View Existing Member'),
            ),
        ],
      ),
    );
  }
}

/// One group of members sharing the same SA ID or Global Record.
class DuplicateGroup {
  const DuplicateGroup({
    required this.field,
    required this.value,
    required this.members,
  });

  final String field;
  final String value;
  final List<Member> members;
}
