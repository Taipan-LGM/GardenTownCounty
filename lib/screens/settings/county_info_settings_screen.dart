import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/cancel_button.dart';
import '../../widgets/county_logo.dart';
import '../../widgets/new_county_warning_dialog.dart';

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

    // Always re-check at save time — warning every Save when all 4 differ.
    final allFourChanged = countyAllFourFieldsChanged(
      name: _nameController.text,
      address: _addressController.text,
      contact: _contactController.text,
      registration: _registrationController.text,
      originalName: _originalName,
      originalAddress: _originalAddress,
      originalContact: _originalContact,
      originalRegistration: _originalRegistration,
    );
    var isNewCounty = false;

    if (allFourChanged) {
      final confirmed = await showNewCountyWarningDialog(context);
      if (!confirmed || !mounted) {
        setState(() {}); // keep Save enabled; warning will show again next Save
        return;
      }
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
        title: const Text(
          'County Information',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showHelpDialog,
            tooltip: 'How it works',
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.black,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Logo on top
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: const Row(
                        children: [
                          RoundCountyLogo(size: 56),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'County Information',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Update county details',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _nameController,
                      label: 'County Name',
                      icon: Icons.business,
                      changed: _nameChanged,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _addressController,
                      label: 'County Address',
                      icon: Icons.location_on,
                      changed: _addressChanged,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _contactController,
                            label: 'Contact No.',
                            icon: Icons.phone,
                            changed: _contactChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _registrationController,
                            label: 'Registration No.',
                            icon: Icons.numbers,
                            changed: _registrationChanged,
                          ),
                        ),
                      ],
                    ),
                    if (_allFieldsChanged) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: const Text(
                          'NEW COUNTY: all 4 fields changed. Each Save opens CONFIRM.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 45,
                            child: ElevatedButton.icon(
                              onPressed: _canSave ? _saveCountyInfo : null,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _allFieldsChanged
                                          ? Icons.warning
                                          : Icons.save,
                                    ),
                              label: Text(
                                _isSaving
                                    ? 'Saving...'
                                    : _allFieldsChanged
                                        ? 'Register New County'
                                        : 'Save Changes',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _allFieldsChanged
                                    ? Colors.red.shade700
                                    : (_canSave
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade700,
                                disabledForegroundColor: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CancelButton(
                          onPressed: () => Navigator.pop(context),
                          text: 'Cancel',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
    bool isLarge = false,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: Colors.white,
        fontSize: isLarge ? 16 : 14,
      ),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: isLarge ? 15 : 13,
        ),
        hintText: 'Enter $label',
        hintStyle: TextStyle(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade800,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isLarge ? 18 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: changed ? Colors.orange.shade700 : Colors.grey.shade700,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: changed ? Colors.orange : Colors.blue,
            width: 2,
          ),
        ),
        prefixIcon: Icon(
          icon,
          color: changed ? Colors.orange : Colors.blue.shade300,
        ),
        suffixIcon: changed
            ? const Icon(Icons.edit, color: Colors.orange, size: 18)
            : null,
      ),
    );
  }
}
