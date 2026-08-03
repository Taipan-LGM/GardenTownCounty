import 'package:flutter/material.dart';

/// Banner shown above the member form while Edit Mode is active.
class MemberEditModeBanner extends StatelessWidget {
  const MemberEditModeBanner({
    super.key,
    required this.hasUnsavedChanges,
  });

  final bool hasUnsavedChanges;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.orange.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.deepOrange.shade900 : Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '✏️ EDIT MODE ACTIVE - Changes will be saved when you click Save',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'Unsaved Changes: ${hasUnsavedChanges ? 'Yes' : 'No'}',
            style: TextStyle(
                color: isDark
                  ? Colors.white
                  : hasUnsavedChanges
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
