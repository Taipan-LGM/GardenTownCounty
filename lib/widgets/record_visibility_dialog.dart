import 'package:flutter/material.dart';

import '../services/record_field_policy.dart';

import 'standard_buttons.dart';

/// Explains Global / LRO Record No. visibility rules.
///
/// // NEW ADDITION - Delete this file to revert help dialog.
class RecordVisibilityDialog extends StatelessWidget {
  const RecordVisibilityDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const RecordVisibilityDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Number Visibility'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Global Record No. & LRO Record No.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _ruleRow('Admin', 'Always visible & editable', Colors.blue),
          _ruleRow(
            'Recording Secretary',
            'Always visible (read-only after entry)',
            Colors.green,
          ),
          _ruleRow(
            'Member (Self)',
            'Hidden until entered, then visible (read-only)',
            Colors.orange,
          ),
          _ruleRow(
            'Other Members',
            'Hidden until entered, then visible (read-only)',
            Colors.grey,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Fields become visible to the Member once entered by Admin '
              '(or Secretary on first entry).',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
      actions: [
        ActionButton(
          onPressed: () => Navigator.pop(context),
          text: 'Got It',
        ),
      ],
    );
  }

  Widget _ruleRow(String label, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' — $description',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner for Member role about record-number visibility.
///
/// // NEW ADDITION - Delete with RecordVisibilityDialog to revert.
class RecordVisibilityBanner extends StatelessWidget {
  const RecordVisibilityBanner({
    super.key,
    required this.globalRecordNo,
    required this.lroRecordNo,
  });

  final String? globalRecordNo;
  final String? lroRecordNo;

  @override
  Widget build(BuildContext context) {
    final hasGlobal = RecordFieldPolicy.hasValue(globalRecordNo);
    final hasLro = RecordFieldPolicy.hasValue(lroRecordNo);

    if (!hasGlobal && !hasLro) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Global Record No. and LRO Record No. will appear here '
                'once entered by Admin.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Numbers Visible',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                if (hasGlobal)
                  Text(
                    'Global Record No.: ${globalRecordNo!.trim()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (hasLro)
                  Text(
                    'LRO Record No.: ${lroRecordNo!.trim()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                Text(
                  'These fields are read-only. Contact Admin for changes.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
