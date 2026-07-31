import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../l10n/app_strings.dart';

class MemberContactDetailsSection extends StatelessWidget {
  const MemberContactDetailsSection({
    super.key,
    required this.addressController,
    required this.contactNo1Controller,
    required this.contactNo2Controller,
    required this.emailController,
    required this.commentController,
    required this.strings,
    required this.formReadOnly,
    required this.fieldDecorationBuilder,
    required this.addressValidator,
    required this.contactNo1Validator,
    required this.emailValidator,
  });

  final TextEditingController addressController;
  final TextEditingController contactNo1Controller;
  final TextEditingController contactNo2Controller;
  final TextEditingController emailController;
  final TextEditingController commentController;
  final AppStrings strings;
  final bool formReadOnly;
  final InputDecoration Function(
    String label, {
    bool isDense,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
    bool filled,
  }) fieldDecorationBuilder;
  final FormFieldValidator<String> addressValidator;
  final FormFieldValidator<String> contactNo1Validator;
  final FormFieldValidator<String> emailValidator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: addressController,
          enabled: !formReadOnly,
          decoration: fieldDecorationBuilder(
            'Address *',
            filled: addressController.text.trim().isNotEmpty,
          ),
          maxLines: 2,
          validator: addressValidator,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: contactNo1Controller,
                enabled: !formReadOnly,
                decoration: fieldDecorationBuilder(
                  strings.contactNo1,
                  filled: contactNo1Controller.text.trim().isNotEmpty,
                ),
                maxLength: AppConstants.contactNoMaxLength,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppConstants.contactNoMaxLength),
                ],
                validator: contactNo1Validator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: contactNo2Controller,
                enabled: !formReadOnly,
                decoration: fieldDecorationBuilder(
                  strings.contactNo2,
                  filled: contactNo2Controller.text.trim().isNotEmpty,
                ),
                maxLength: AppConstants.contactNoMaxLength,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppConstants.contactNoMaxLength),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: emailController,
          enabled: !formReadOnly,
          decoration: fieldDecorationBuilder(
            strings.emailAddress,
            filled: emailController.text.trim().isNotEmpty,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: emailValidator,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: commentController,
          enabled: !formReadOnly,
          decoration: fieldDecorationBuilder('Comment'),
          maxLines: 4,
        ),
      ],
    );
  }
}
