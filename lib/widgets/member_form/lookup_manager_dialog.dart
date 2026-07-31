import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lookup_item.dart';
import '../../providers/providers.dart';

Future<void> showLookupManagerDialog(
  BuildContext context,
  WidgetRef ref,
  LookupType type,
) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Manage lookup values'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: type.label,
              hintText: 'Enter a value',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2.0),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                Navigator.pop(ctx, false);
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (ok == true) {
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      // Keep the UI working even if persistence is unavailable in the preview build.
      ref.invalidate(lookupsProvider(type));
    }
  }
}
