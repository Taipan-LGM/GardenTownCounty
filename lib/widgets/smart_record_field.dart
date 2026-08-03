import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../services/record_field_policy.dart';

/// Record number field with role-based show / read-only rules.
///
/// // NEW ADDITION - Delete this file to revert SmartRecordField.
class SmartRecordField extends StatefulWidget {
  const SmartRecordField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    required this.isEditing,
    required this.isAdmin,
    required this.isSecretary,
    required this.isMember,
    this.persistedValue,
    this.errorText,
    this.maxLength = AppConstants.lroRecordNoMaxLength,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.decorationBuilder,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isEditing;
  final bool isAdmin;
  final bool isSecretary;
  final bool isMember;
  /// Value already stored in DB (drives secretary lock-after-entry).
  final String? persistedValue;
  final String? errorText;
  final int maxLength;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final InputDecoration Function(InputDecoration base)? decorationBuilder;
  final Widget? suffixIcon;

  @override
  State<SmartRecordField> createState() => _SmartRecordFieldState();
}

class _SmartRecordFieldState extends State<SmartRecordField> {
  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final shouldShow = RecordFieldPolicy.shouldShow(
      isAdmin: widget.isAdmin,
      isSecretary: widget.isSecretary,
      value: widget.persistedValue ?? value,
    );
    if (!shouldShow) return const SizedBox.shrink();

    final formReadOnly = !widget.isEditing;
    final readOnly = RecordFieldPolicy.isReadOnly(
      isAdmin: widget.isAdmin,
      isSecretary: widget.isSecretary,
      persistedValue: widget.persistedValue,
      formReadOnly: formReadOnly,
    );
    final hasValue = RecordFieldPolicy.hasValue(value);

    final base = InputDecoration(
      labelText: widget.label,
      hintText: widget.hint ?? 'Enter ${widget.label}',
      errorText: widget.errorText,
      counterText: '',
      isDense: true,
      suffixIcon: widget.suffixIcon ?? _buildSuffixIcon(readOnly, hasValue),
      enabledBorder: readOnly
          ? OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300),
            )
          : null,
      disabledBorder: readOnly
          ? OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300),
            )
          : null,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: widget.controller,
        enabled: !readOnly,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        decoration: widget.decorationBuilder != null
            ? widget.decorationBuilder!(base)
            : base,
        validator: readOnly ? null : widget.validator,
        onChanged: (v) {
          widget.onChanged?.call(v);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSuffixIcon(bool isReadOnly, bool hasValue) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    if (!hasValue) {
      return Icon(Icons.lock_outline, color: color, size: 18);
    }
    if (isReadOnly) {
      return Icon(Icons.lock, color: color, size: 18);
    }
    return const Icon(Icons.edit, color: Colors.blue, size: 18);
  }
}
