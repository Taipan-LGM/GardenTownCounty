import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';

/// Top bar shown while viewing a member profile — Previous / Next always visible.
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
    final counter = totalMembers == 0
        ? '—'
        : '${currentIndex < 0 ? '—' : currentIndex + 1} of $totalMembers';

    return Material(
      elevation: 2,
      color: AppTheme.forestGreen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back to List (Esc)',
                  onPressed: onBack,
                ),
                Expanded(
                  child: Text(
                    '👤 ${currentMember.fullName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    tooltip: 'Edit (Ctrl+E)',
                    onPressed: canEdit ? onEdit : null,
                  ),
                if (onUpload != null)
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    tooltip: 'Upload Files (Ctrl+U)',
                    onPressed: onUpload,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    tooltip: 'Delete (Ctrl+D)',
                    onPressed: canDelete ? onDelete : null,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close (Esc)',
                  onPressed: onBack,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: hasPrev ? onPrevious : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(
                      previousName == null
                          ? 'Previous'
                          : 'Previous: $previousName',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      counter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: hasNext ? onNext : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.chevron_right),
                    label: Text(
                      nextName == null ? 'Next' : 'Next: $nextName',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
