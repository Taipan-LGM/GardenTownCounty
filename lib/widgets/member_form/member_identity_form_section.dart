import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/duplicate_warning_widget.dart';
import '../../widgets/smart_record_field.dart';
import '../../widgets/record_visibility_banner.dart';
import '../member_lock_banners.dart';
import '../standard_buttons.dart';

class MemberIdentityFormSection extends StatelessWidget {
  const MemberIdentityFormSection({
    super.key,
    required this.saIdController,
    required this.globalRecordNoController,
    required this.lroRecordNoController,
    required this.memberNameController,
    required this.surnameController,
    required this.strings,
    required this.isEditing,
    required this.formReadOnly,
    required this.viewerIsAdmin,
    required this.viewerIsSecretary,
    required this.isMemberOnly,
    required this.showGlobalRecordField,
    required this.globalRecordReadOnly,
    required this.isCheckingSaId,
    required this.isCheckingGlobalRecord,
    required this.saIdError,
    required this.saIdWarning,
    required this.globalRecordError,
    required this.lroRecordError,
    required this.duplicateSaIdMemberId,
    required this.duplicateGlobalRecordMemberId,
    required this.persistedGlobalRecord,
    required this.persistedLroRecord,
    required this.fieldDecorationBuilder,
    required this.saIdValidator,
    required this.globalRecordValidator,
    required this.lroValidator,
    required this.memberNameValidator,
    required this.surnameValidator,
    required this.onManageRecordVisibility,
    required this.onViewExistingSaIdDuplicate,
    required this.onViewExistingGlobalRecordDuplicate,
    required this.onLroChanged,
  });

  final TextEditingController saIdController;
  final TextEditingController globalRecordNoController;
  final TextEditingController lroRecordNoController;
  final TextEditingController memberNameController;
  final TextEditingController surnameController;
  final AppStrings strings;
  final bool isEditing;
  final bool formReadOnly;
  final bool viewerIsAdmin;
  final bool viewerIsSecretary;
  final bool isMemberOnly;
  final bool showGlobalRecordField;
  final bool globalRecordReadOnly;
  final bool isCheckingSaId;
  final bool isCheckingGlobalRecord;
  final String? saIdError;
  final String? saIdWarning;
  final String? globalRecordError;
  final String? lroRecordError;
  final String? duplicateSaIdMemberId;
  final String? duplicateGlobalRecordMemberId;
  final String? persistedGlobalRecord;
  final String? persistedLroRecord;
  final InputDecoration Function(
    String label, {
    bool isDense,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
    bool filled,
  }) fieldDecorationBuilder;
  final String? Function(String?)? saIdValidator;
  final String? Function(String?)? globalRecordValidator;
  final String? Function(String?)? lroValidator;
  final String? Function(String?)? memberNameValidator;
  final String? Function(String?)? surnameValidator;
  final VoidCallback onManageRecordVisibility;
  final VoidCallback onViewExistingSaIdDuplicate;
  final VoidCallback onViewExistingGlobalRecordDuplicate;
  final ValueChanged<String> onLroChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: saIdController,
          enabled: !formReadOnly,
          decoration: fieldDecorationBuilder(
            'SA ID No.',
            isDense: true,
            errorText: saIdError,
            helperText: saIdError == null ? saIdWarning : null,
            suffixIcon: isCheckingSaId
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : saIdError == null && saIdController.text.isNotEmpty && isEditing
                    ? Icon(
                        saIdWarning == null
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        color: saIdWarning == null
                            ? Colors.green
                            : Colors.orange,
                        size: 18,
                      )
                    : null,
          ),
          maxLength: AppConstants.saIdMaxLength,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: saIdValidator,
        ),
        DuplicateWarningWidget(
          field: 'SA ID',
          value: saIdController.text.trim(),
          isDuplicate: duplicateSaIdMemberId != null,
          onViewExisting: onViewExistingSaIdDuplicate,
        ),
        if (viewerIsAdmin || viewerIsSecretary)
          Align(
            alignment: Alignment.centerRight,
            child: ActionButton(
              onPressed: onManageRecordVisibility,
              text: strings.recordVisibility,
              icon: Icons.info_outline,
              height: 35,
              backgroundColor: AppButtonColors.viewBg,
              foregroundColor: AppButtonColors.viewFg,
              borderColor: AppButtonColors.blackRing,
            ),
          ),
        if (isMemberOnly)
          RecordVisibilityBanner(
            globalRecordNo: persistedGlobalRecord ?? globalRecordNoController.text,
            lroRecordNo: persistedLroRecord ?? lroRecordNoController.text,
          ),
        if (showGlobalRecordField) ...[
          TextFormField(
            controller: globalRecordNoController,
            enabled: !globalRecordReadOnly,
            decoration: fieldDecorationBuilder(
              strings.globalRecordNo,
              isDense: true,
              errorText: globalRecordError,
              suffixIcon: isCheckingGlobalRecord
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : globalRecordReadOnly
                      ? Icon(Icons.lock, color: Colors.grey.shade600, size: 18)
                      : globalRecordError == null &&
                              globalRecordNoController.text.isNotEmpty &&
                              isEditing
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            )
                          : Icon(
                              Icons.lock_outline,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
            ),
            maxLength: AppConstants.globalRecordNoMaxLength,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: globalRecordValidator,
          ),
          DuplicateWarningWidget(
            field: strings.globalRecordNo,
            value: globalRecordNoController.text.trim(),
            isDuplicate: duplicateGlobalRecordMemberId != null,
            onViewExisting: onViewExistingGlobalRecordDuplicate,
          ),
        ],
        SmartRecordField(
          label: strings.lroRecordNo,
          controller: lroRecordNoController,
          hint: strings.enterLroRecordNo,
          isEditing: isEditing && !formReadOnly,
          isAdmin: viewerIsAdmin,
          isSecretary: viewerIsSecretary,
          isMember: isMemberOnly,
          persistedValue: persistedLroRecord,
          errorText: lroRecordError,
          maxLength: AppConstants.lroRecordNoMaxLength,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))],
          validator: lroValidator,
          onChanged: onLroChanged,
          decorationBuilder: (base) => fieldDecorationBuilder(
            'LRO Record No.',
            isDense: true,
            errorText: lroRecordError,
            suffixIcon: base.suffixIcon,
          ),
        ),
        TextFormField(
          controller: memberNameController,
          enabled: !formReadOnly,
          decoration: fieldDecorationBuilder(
            strings.memberName,
            isDense: true,
            filled: memberNameController.text.trim().isNotEmpty,
          ),
          validator: memberNameValidator ??
              (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: surnameController,
          enabled: !formReadOnly,
          decoration: fieldDecorationBuilder(
            strings.surname,
            isDense: true,
            filled: surnameController.text.trim().isNotEmpty,
          ),
          validator: surnameValidator ??
              (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
        ),
      ],
    );
  }
}
