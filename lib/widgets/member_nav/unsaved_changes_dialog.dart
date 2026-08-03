import 'package:flutter/material.dart';

import '../form_dialog_title.dart';
import '../standard_buttons.dart';

/// Result of the unsaved-changes navigation dialog.
enum UnsavedChangesAction { save, discard, stay }

/// Prompt when leaving a member with unsaved edits.
Future<UnsavedChangesAction?> showUnsavedChangesDialog(
  BuildContext context,
) {
  return showDialog<UnsavedChangesAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: FormDialogTitle(
        title: 'Unsaved Changes',
        onClose: () => Navigator.pop(ctx, UnsavedChangesAction.stay),
      ),
      titlePadding: formDialogTitlePadding,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You have unsaved changes to this member.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'What would you like to do?',
            style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.deepOrange.shade900
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your changes will be lost if you navigate away without saving.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        DeleteButton(
          onPressed: () =>
              Navigator.pop(ctx, UnsavedChangesAction.discard),
          text: 'Discard Changes',
        ),
        CancelButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChangesAction.stay),
          text: 'Stay Here',
        ),
        SaveButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChangesAction.save),
          text: 'Save Changes',
          icon: Icons.save,
        ),
      ],
    ),
  );
}

Future<bool?> showDiscardEditsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: FormDialogTitle(
        title: '⚠️ Discard Changes?',
        onClose: () => Navigator.pop(ctx, false),
      ),
      titlePadding: formDialogTitlePadding,
      content: const Text(
        'You have unsaved changes. Are you sure you want to discard them?',
      ),
      actions: [
        CancelButton(
          onPressed: () => Navigator.pop(ctx, false),
          text: 'Keep Editing',
        ),
        DeleteButton(
          onPressed: () => Navigator.pop(ctx, true),
          text: 'Discard Changes',
        ),
      ],
    ),
  );
}
