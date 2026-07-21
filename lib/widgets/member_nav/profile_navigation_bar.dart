import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';

/// Top bar shown while viewing a member profile.
class ProfileNavigationBar extends StatelessWidget {
  const ProfileNavigationBar({
    super.key,
    required this.currentMember,
    required this.currentIndex,
    required this.totalMembers,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    this.previousName,
    this.nextName,
    this.onEdit,
    this.onUpload,
    this.onDelete,
    this.canEdit = true,
    this.canDelete = true,
  });

  final Member currentMember;
  final int currentIndex;
  final int totalMembers;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String? previousName;
  final String? nextName;
  final VoidCallback? onEdit;
  final VoidCallback? onUpload;
  final VoidCallback? onDelete;
  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < totalMembers - 1;
    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to List (Esc)',
              onPressed: onBack,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: previousName == null
                  ? 'Previous (↑)'
                  : 'Previous: $previousName (↑)',
              onPressed: hasPrev ? onPrevious : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalMembers == 0
                    ? '—'
                    : '${currentIndex < 0 ? '—' : currentIndex + 1} of $totalMembers',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip:
                  nextName == null ? 'Next (↓)' : 'Next: $nextName (↓)',
              onPressed: hasNext ? onNext : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '👤 ${currentMember.fullName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit (Ctrl+E)',
                onPressed: canEdit ? onEdit : null,
              ),
            if (onUpload != null)
              IconButton(
                icon: const Icon(Icons.attach_file),
                tooltip: 'Upload Files (Ctrl+U)',
                onPressed: onUpload,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete (Ctrl+D)',
                onPressed: canDelete ? onDelete : null,
              ),
          ],
        ),
      ),
    );
  }
}
