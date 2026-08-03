import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/member_form_mode.dart';
import '../standard_buttons.dart';
import 'member_form_status_chip.dart';

class MemberProfileHeader extends StatelessWidget {
  const MemberProfileHeader({
    super.key,
    required this.modeLabel,
    required this.formMode,
    required this.member,
    required this.isEditing,
    required this.hasUnsavedChanges,
    required this.saving,
    required this.canEnterEditMode,
    required this.fieldsMasked,
    required this.canPressSave,
    required this.currentId,
    required this.strings,
    required this.onEnterEdit,
    required this.onCancelEdit,
    required this.onSave,
    required this.onUploadFiles,
  });

  final String modeLabel;
  final MemberFormMode formMode;
  final dynamic member;
  final bool isEditing;
  final bool hasUnsavedChanges;
  final bool saving;
  final bool canEnterEditMode;
  final bool fieldsMasked;
  final bool canPressSave;
  final String? currentId;
  final AppStrings strings;
  final VoidCallback onEnterEdit;
  final VoidCallback onCancelEdit;
  final Future<bool> Function() onSave;
  final Future<void> Function() onUploadFiles;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        MemberFormStatusChip(mode: formMode, member: member),
        const SizedBox(width: 8),
        Chip(
          visualDensity: VisualDensity.compact,
          backgroundColor: isEditing
              ? Colors.orange.withValues(alpha: 0.15)
              : AppTheme.forestGreen,
          label: Text(
            modeLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
                color: isEditing && isDark
                  ? Colors.white
                  : isEditing
                  ? Colors.orange.shade800
                  : Colors.white,
            ),
          ),
        ),
        const Spacer(),
        if (currentId != null && !fieldsMasked)
          ActionButton(
            onPressed: () async => onUploadFiles(),
            text: strings.uploadFiles,
            icon: Icons.attach_file,
          ),
        const SizedBox(width: 8),
        if (!isEditing && canEnterEditMode)
          EditButton(
            onPressed: onEnterEdit,
            text: strings.edit,
            icon: Icons.edit,
          ),
        if (isEditing) ...[
          CancelButton(
            onPressed: saving ? null : onCancelEdit,
            text: strings.cancel,
          ),
          const SizedBox(width: 8),
          SaveButton(
            onPressed: canPressSave ? () => onSave() : null,
            text: strings.save,
            isLoading: saving,
            icon: Icons.save,
          ),
        ],
      ],
    );
  }
}
