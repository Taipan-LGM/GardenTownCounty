import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/county_info.dart';
import '../../providers/providers.dart';

/// Admin screen: update county identity; optional full data reset for new county.
///
/// // NEW ADDITION - Delete this file to revert County Information Settings UI.
class CountyInfoSettingsScreen extends ConsumerStatefulWidget {
  const CountyInfoSettingsScreen({super.key});

  @override
  ConsumerState<CountyInfoSettingsScreen> createState() =>
      _CountyInfoSettingsScreenState();
}

class _CountyInfoSettingsScreenState
    extends ConsumerState<CountyInfoSettingsScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _registrationController = TextEditingController();
  final _confirmController = TextEditingController();

  CountyInfo? _countyInfo;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _confirmReset = false;

  String _originalName = '';
  String _originalAddress = '';
  String _originalRegistration = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onChanged);
    _addressController.addListener(_onChanged);
    _registrationController.addListener(_onChanged);
    _confirmController.addListener(_onChanged);
    _loadCountyInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _registrationController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _nameChanged =>
      _nameController.text.trim() != _originalName.trim();
  bool get _addressChanged =>
      _addressController.text.trim() != _originalAddress.trim();
  bool get _registrationChanged =>
      _registrationController.text.trim() != _originalRegistration.trim();

  bool get _hasAnyChange =>
      _nameChanged || _addressChanged || _registrationChanged;

  bool get _allFieldsChanged =>
      _nameChanged && _addressChanged && _registrationChanged;

  bool get _willReset =>
      _allFieldsChanged &&
      _confirmReset &&
      _confirmController.text.trim() == 'CONFIRM';

  bool get _canSave {
    if (_isSaving || !_hasAnyChange) return false;
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _registrationController.text.trim().isEmpty) {
      return false;
    }
    // All three changed + checkbox on → require CONFIRM.
    if (_allFieldsChanged && _confirmReset) {
      return _confirmController.text.trim() == 'CONFIRM';
    }
    return true;
  }

  Future<void> _loadCountyInfo() async {
    setState(() => _isLoading = true);
    try {
      final info = await ref.read(countyInfoServiceProvider).getCountyInfo();
      _countyInfo = info;
      _originalName = info.countyName;
      _originalAddress = info.countyAddress;
      _originalRegistration = info.countyRegistrationNo;
      _nameController.text = info.countyName;
      _addressController.text = info.countyAddress;
      _registrationController.text = info.countyRegistrationNo;
      _confirmController.clear();
      _confirmReset = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading county info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCountyInfo() async {
    final admin = ref.read(authUserProvider);
    if (admin == null || !admin.isAdmin) return;
    if (!_canSave) return;

    setState(() => _isSaving = true);
    try {
      final didReset = _willReset;
      await ref.read(countyInfoServiceProvider).updateCountyInfo(
            countyName: _nameController.text.trim(),
            countyAddress: _addressController.text.trim(),
            countyRegistrationNo: _registrationController.text.trim(),
            admin: admin,
            isNewCounty: didReset,
          );

      ref.invalidate(countyProfileProvider);
      ref.invalidate(countyInfoProvider);
      ref.invalidate(membersProvider);
      ref.invalidate(appUsersProvider);
      ref.invalidate(activitiesProvider);
      ref.invalidate(remindersProvider);
      ref.invalidate(activeOnboardingRemindersProvider);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (didReset) {
        await _showNewCountySuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ County information updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _loadCountyInfo();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showNewCountySuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('New County Registered')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The county has been successfully reset.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• All member data has been cleared'),
            Text('• All case data has been cleared'),
            Text('• All file uploads have been cleared'),
            Text('• All reminders have been cleared'),
            Text('• Non-admin users have been removed'),
            Text('• System is ready for new county setup'),
            SizedBox(height: 12),
            Text(
              'You can now start adding new members to the new county.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How It Works'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Updating County Information:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Change 1–2 fields → Normal update'),
            Text('• Change ALL 3 fields → New County option appears'),
            SizedBox(height: 12),
            Text(
              'NEW County Registration:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Check the confirmation box'),
            Text('• Type CONFIRM'),
            Text('• ALL existing operational data is deleted'),
            Text('• Admin account is preserved'),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('County Information'),
          backgroundColor: AppTheme.forestGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Admin access required.')),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('County Information'),
          backgroundColor: AppTheme.forestGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('County Information'),
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showHelpDialog,
            tooltip: 'How it works',
          ),
        ],
      ),
      body: ColoredBox(
        color: const Color(0xFF0A0A0A),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.blue.shade300, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'County Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Update county details. Changing ALL 3 fields can register a NEW county.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _field(
                controller: _nameController,
                label: 'County Name',
                icon: Icons.business,
                changed: _nameChanged,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _addressController,
                label: 'County Address',
                icon: Icons.location_on,
                changed: _addressChanged,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _registrationController,
                label: 'County Registration No.',
                icon: Icons.numbers,
                changed: _registrationChanged,
              ),
              if (_allFieldsChanged) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade300),
                          const SizedBox(width: 8),
                          Text(
                            'NEW COUNTY DETECTED',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All 3 fields have been changed. Check the box and type CONFIRM to delete all existing data and register a new county. Leave unchecked to save details only.',
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _confirmReset,
                            onChanged: (value) {
                              setState(() {
                                _confirmReset = value ?? false;
                                if (!_confirmReset) {
                                  _confirmController.clear();
                                }
                              });
                            },
                            activeColor: Colors.red,
                          ),
                          const Expanded(
                            child: Text(
                              'I confirm this is a NEW county. All existing data will be DELETED.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_confirmReset) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Type "CONFIRM" to proceed:',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _confirmController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type CONFIRM',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: Colors.grey.shade800,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canSave ? _saveCountyInfo : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_willReset ? Icons.warning : Icons.save),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : _willReset
                            ? 'Register NEW County (All Data Will Be Deleted)'
                            : 'Save Changes',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _willReset
                        ? Colors.red.shade700
                        : (_canSave ? Colors.blue : Colors.grey.shade700),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey.shade700,
                    disabledForegroundColor: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_countyInfo != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current County Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _infoRow('Name', _countyInfo!.countyName),
                      _infoRow('Address', _countyInfo!.countyAddress),
                      _infoRow(
                        'Registration',
                        _countyInfo!.countyRegistrationNo,
                      ),
                      _infoRow(
                        'Last Updated',
                        _countyInfo!.lastUpdated
                            .toLocal()
                            .toString()
                            .substring(0, 16),
                      ),
                      if (_countyInfo!.resetCount > 0)
                        _infoRow(
                          'County Resets',
                          _countyInfo!.resetCount.toString(),
                        ),
                      if (_countyInfo!.lastResetDate != null)
                        _infoRow(
                          'Last Reset',
                          _countyInfo!.lastResetDate!
                              .toLocal()
                              .toString()
                              .substring(0, 16),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool changed,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        hintText: 'Enter $label',
        hintStyle: TextStyle(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.blue.shade300),
        suffixIcon: changed
            ? const Icon(Icons.edit, color: Colors.orange)
            : null,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
