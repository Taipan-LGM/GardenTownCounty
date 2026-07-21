import 'package:flutter/material.dart';

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
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Unsaved Changes'),
        ],
      ),
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
            style: TextStyle(color: Colors.grey.shade600),
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
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, UnsavedChangesAction.discard),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Discard Changes'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChangesAction.stay),
          child: const Text('Stay Here'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, UnsavedChangesAction.save),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Changes'),
        ),
      ],
    ),
  );
}

Future<bool?> showDiscardEditsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('⚠️ Discard Changes?'),
      content: const Text(
        'You have unsaved changes. Are you sure you want to discard them?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep Editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Discard Changes'),
        ),
      ],
    ),
  );
}
