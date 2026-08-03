import 'package:flutter/material.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValues = [globalRecordNo, lroRecordNo].any((value) => (value ?? '').trim().isNotEmpty);
    if (!hasValues) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        'Record visibility is managed for the current member.',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.blue.shade800,
          fontSize: 12,
        ),
      ),
    );
  }
}
