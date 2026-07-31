import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../models/lookup_item.dart';
import '../../providers/providers.dart';
import '../standard_buttons.dart';
import 'lookup_manager_dialog.dart';

class MemberLookupSection extends ConsumerWidget {
  const MemberLookupSection({
    super.key,
    required this.strings,
    required this.formReadOnly,
    required this.fieldDecorationBuilder,
    required this.suburb,
    required this.townCity,
    required this.postalCode,
    required this.onSuburbChanged,
    required this.onTownCityChanged,
    required this.onPostalCodeChanged,
  });

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
  final String? suburb;
  final String? townCity;
  final String? postalCode;
  final ValueChanged<String?> onSuburbChanged;
  final ValueChanged<String?> onTownCityChanged;
  final ValueChanged<String?> onPostalCodeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemberLookupField(
          label: strings.suburb,
          type: LookupType.suburb,
          value: suburb,
          required: true,
          formReadOnly: formReadOnly,
          fieldDecorationBuilder: fieldDecorationBuilder,
          onChanged: onSuburbChanged,
          onManage: () async {
            await showLookupManagerDialog(context, ref, LookupType.suburb);
            ref.invalidate(lookupsProvider(LookupType.suburb));
          },
        ),
        const SizedBox(height: 8),
        MemberLookupField(
          label: strings.townCity,
          type: LookupType.townCity,
          value: townCity,
          required: true,
          formReadOnly: formReadOnly,
          fieldDecorationBuilder: fieldDecorationBuilder,
          onChanged: onTownCityChanged,
          onManage: () async {
            await showLookupManagerDialog(context, ref, LookupType.townCity);
            ref.invalidate(lookupsProvider(LookupType.townCity));
          },
        ),
        const SizedBox(height: 8),
        MemberLookupField(
          label: strings.postalCode,
          type: LookupType.postalCode,
          value: postalCode,
          required: true,
          formReadOnly: formReadOnly,
          fieldDecorationBuilder: fieldDecorationBuilder,
          onChanged: onPostalCodeChanged,
          onManage: () async {
            await showLookupManagerDialog(context, ref, LookupType.postalCode);
            ref.invalidate(lookupsProvider(LookupType.postalCode));
          },
        ),
      ],
    );
  }
}

class MemberLookupField extends ConsumerWidget {
  const MemberLookupField({
    super.key,
    required this.label,
    required this.type,
    required this.value,
    required this.required,
    required this.formReadOnly,
    required this.fieldDecorationBuilder,
    required this.onChanged,
    required this.onManage,
  });

  final String label;
  final LookupType type;
  final String? value;
  final bool required;
  final bool formReadOnly;
  final InputDecoration Function(
    String label, {
    bool isDense,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
    bool filled,
  }) fieldDecorationBuilder;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(lookupsProvider(type));
    return asyncItems.when(
      data: (items) {
        final values = items.map((e) => e.value).toList();
        final effective = value != null && values.contains(value) ? value : null;
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey('${type.storageKey}-${effective ?? 'empty'}'),
                value: effective,
                decoration: fieldDecorationBuilder(
                  required ? '$label *' : label,
                  filled: value != null && value!.trim().isNotEmpty,
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— Select —')),
                  ...values.map((v) => DropdownMenuItem<String?>(value: v, child: Text(v))),
                ],
                onChanged: formReadOnly ? null : onChanged,
                validator: required
                    ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                    : null,
              ),
            ),
            IconButton(
              tooltip: 'Manage $label',
              icon: const Icon(Icons.edit_note),
              onPressed: formReadOnly ? null : onManage,
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Lookup error: $e'),
    );
  }
}
