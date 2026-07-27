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
  final _contactController = TextEditingController();
  final _registrationController = TextEditingController();

  CountyInfo? _countyInfo;
  bool _isLoading = true;
  bool _isSaving = false;

  String _originalName = '';
  String _originalAddress = '';
  String _originalContact = '';
  String _originalRegistration = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_checkChanges);
    _addressController.addListener(_checkChanges);
    _contactController.addListener(_checkChanges);
    _registrationController.addListener(_checkChanges);
    _loadCountyInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  void _checkChanges() {
    if (!mounted) return;
    assert(() {
      debugPrint('📝 County Info Changes:');
      debugPrint('  Name changed: $_nameChanged');
      debugPrint('  Address changed: $_addressChanged');
      debugPrint('  Contact changed: $_contactChanged');
      debugPrint('  Registration changed: $_registrationChanged');
      debugPrint('  All 4 changed: $_allFieldsChanged');
      return true;
    }());
    setState(() {});
  }

  bool get _nameChanged =>
      _nameController.text.trim() != _originalName.trim();
  bool get _addressChanged =>
      _addressController.text.trim() != _originalAddress.trim();
  bool get _contactChanged =>
      _contactController.text.trim() != _originalContact.trim();
  bool get _registrationChanged =>
      _registrationController.text.trim() != _originalRegistration.trim();

  bool get _hasAnyChange =>
      _nameChanged ||
      _addressChanged ||
      _contactChanged ||
      _registrationChanged;

  bool get _allFieldsChanged =>
      _nameChanged &&
      _addressChanged &&
      _contactChanged &&
      _registrationChanged;

  bool get _canSave {
    if (_isSaving || !_hasAnyChange) return false;
    return _nameController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty &&
        _contactController.text.trim().isNotEmpty &&
        _registrationController.text.trim().isNotEmpty;
  }

  Future<void> _loadCountyInfo() async {
    setState(() => _isLoading = true);
    try {
      final info = await ref.read(countyInfoServiceProvider).getCountyInfo();
      _countyInfo = info;
      _originalName = info.countyName;
      _originalAddress = info.countyAddress;
      _originalContact = info.countyContactNo;
      _originalRegistration = info.countyRegistrationNo;
      _nameController.text = info.countyName;
      _addressController.text = info.countyAddress;
      _contactController.text = info.countyContactNo;
      _registrationController.text = info.countyRegistrationNo;
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

    final allFourChanged = _allFieldsChanged;
    var isNewCounty = false;

    // Modal warning when ALL 4 fields changed — must type CONFIRM.
    if (allFourChanged) {
      final confirmed = await _showNewCountyWarningDialog();
      if (!confirmed) return;
      isNewCounty = true;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(countyInfoServiceProvider).updateCountyInfo(
            countyName: _nameController.text.trim(),
            countyAddress: _addressController.text.trim(),
            countyContactNo: _contactController.text.trim(),
            countyRegistrationNo: _registrationController.text.trim(),
            admin: admin,
            isNewCounty: isNewCounty,
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

      if (isNewCounty) {
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

  Future<bool> _showNewCountyWarningDialog() async {
    var confirmText = '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canConfirm = confirmText.trim() == 'CONFIRM';
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Expanded(child: Text('NEW COUNTY DETECTED')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You have changed ALL 4 county information fields.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This will register a NEW COUNTY and will:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• DELETE all existing member data',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• DELETE all case data (528, 928, LRO)',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• DELETE all file uploads',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• DELETE all reminders',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• DELETE all users (except Admin)',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• DELETE all remuneration records',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Type "CONFIRM" to proceed:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() => confirmText = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Type CONFIRM',
                        border: const OutlineInputBorder(),
                        errorText: confirmText.isNotEmpty && !canConfirm
                            ? 'Must type "CONFIRM" exactly'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      canConfirm ? () => Navigator.pop(context, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canConfirm ? Colors.red : Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm New County'),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
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
            Text('• Change 1–3 fields → Normal update'),
            Text('• Change ALL 4 fields → Warning popup'),
            SizedBox(height: 12),
            Text(
              'NEW County Registration:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Type CONFIRM in the warning dialog'),
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
                            'Update county details. Changing ALL 4 fields registers a NEW county.',
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
              // Order: Name → Address → Contact → Registration
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
                controller: _contactController,
                label: 'County Contact No.',
                icon: Icons.phone,
                changed: _contactChanged,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _registrationController,
                label: 'County Registration No.',
                icon: Icons.numbers,
                changed: _registrationChanged,
              ),
              if (_allFieldsChanged) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade300),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All 4 fields changed. Saving will open a New County confirmation dialog.',
                          style: TextStyle(
                            color: Colors.orange.shade100,
                            fontSize: 12,
                          ),
                        ),
                      ),
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
                      : Icon(
                          _allFieldsChanged ? Icons.warning : Icons.save,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : _allFieldsChanged
                            ? 'Save (New County Warning)'
                            : 'Save Changes',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allFieldsChanged
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
                      _infoRow('Contact', _countyInfo!.countyContactNo),
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
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
