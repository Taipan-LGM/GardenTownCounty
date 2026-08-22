import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/county.dart';
import '../../../providers/providers.dart';
import '../../../services/database_service.dart';
import '../../../widgets/standard_buttons.dart';

/// Dialog that creates a new County. Validates the 3-digit Unique Number for
/// system-wide uniqueness and optionally clones settings from an existing one.
class CreateCountyDialog extends ConsumerStatefulWidget {
  const CreateCountyDialog({super.key});

  @override
  ConsumerState<CreateCountyDialog> createState() => _CreateCountyDialogState();
}

class _CreateCountyDialogState extends ConsumerState<CreateCountyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _uniqueCtrl = TextEditingController();
  String? _cloneFromId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _regCtrl.dispose();
    _facebookCtrl.dispose();
    _uniqueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final db = ref.read(databaseServiceProvider);
    try {
      final cloneSource = _cloneFromId != null && _cloneFromId!.isNotEmpty
          ? await db.getCountyById(_cloneFromId!)
          : null;
      final now = DateTime.now().toUtc();
      final county = County(
        id: const Uuid().v4(),
        countyName: _nameCtrl.text.trim(),
        countyAddress: _addressCtrl.text.trim(),
        countyContactNo: _contactCtrl.text.trim(),
        countyEmail: _emailCtrl.text.trim(),
        countyRegistrationNo: _regCtrl.text.trim(),
        facebookUrl: _facebookCtrl.text.trim(),
        uniqueNumber: _uniqueCtrl.text.trim(),
        logoPath: cloneSource?.logoPath,
        secondaryLogoPath: cloneSource?.secondaryLogoPath,
        sealPath: cloneSource?.sealPath,
        createdAt: now,
        updatedAt: now,
      );
      await db.createCounty(county);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final counties = ref.watch(countiesProvider).valueOrNull ?? [];
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(strings.createNewCounty),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: strings.countyNameLabel),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? strings.requiredField : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                decoration: InputDecoration(labelText: strings.countyAddressLabel),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactCtrl,
                decoration: InputDecoration(labelText: strings.countyContactNoLabel),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: strings.countyEmailLabel),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _regCtrl,
                decoration: InputDecoration(labelText: strings.countyRegNoLabel),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _facebookCtrl,
                decoration:
                    InputDecoration(labelText: strings.countyFacebookUrlLabel),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _uniqueCtrl,
                decoration: InputDecoration(
                  labelText: strings.countyUniqueNumberLabel,
                  hintText: '024',
                ),
                maxLength: 3,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return strings.requiredField;
                  if (!RegExp(r'^\d{3}$').hasMatch(val)) {
                    return 'Must be exactly 3 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              if (counties.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _cloneFromId,
                  decoration:
                      InputDecoration(labelText: strings.cloneSettingsFrom),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(strings.none),
                    ),
                    for (final c in counties)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.countyName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cloneFromId = v),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        CancelButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          text: strings.cancel,
        ),
        ActionButton(
          onPressed: _saving ? null : _submit,
          text: strings.createNewCounty,
          isLoading: _saving,
        ),
      ],
    );
  }
}
