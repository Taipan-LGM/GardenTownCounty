import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/county_info.dart';
import '../../providers/providers.dart';
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
        title: const Text('County Information'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showHelpDialog,
            tooltip: 'How it works',
            color: Colors.white,
          ),
        ],
      ),
      body: ColoredBox(
        color: const Color(0xFF0A0A0A),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 900,
                  minHeight: constraints.maxHeight < 650
                      ? constraints.maxHeight
                      : 650,
                ),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: wide ? 48 : 16,
                    vertical: wide ? 32 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade700),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 40 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              color: Colors.blue.shade300,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'County Information',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Update county details. Changing ALL 4 fields '
                                    'registers a NEW county (CONFIRM required each time).',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _field(
                          controller: _nameController,
                          label: 'County Name',
                          icon: Icons.business,
                          changed: _nameChanged,
                          isLarge: true,
                        ),
                        const SizedBox(height: 20),
                        _field(
                          controller: _addressController,
                          label: 'County Address',
                          icon: Icons.location_on,
                          changed: _addressChanged,
                          maxLines: 2,
                          isLarge: true,
                        ),
                        const SizedBox(height: 20),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _contactController,
                                  label: 'County Contact No.',
                                  icon: Icons.phone,
                                  changed: _contactChanged,
                                  isLarge: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _field(
                                  controller: _registrationController,
                                  label: 'County Registration No.',
                                  icon: Icons.numbers,
                                  changed: _registrationChanged,
                                  isLarge: true,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _field(
                            controller: _contactController,
                            label: 'County Contact No.',
                            icon: Icons.phone,
                            changed: _contactChanged,
                            isLarge: true,
                          ),
                          const SizedBox(height: 20),
                          _field(
                            controller: _registrationController,
                            label: 'County Registration No.',
                            icon: Icons.numbers,
                            changed: _registrationChanged,
                            isLarge: true,
                          ),
                        ],
                        if (_allFieldsChanged) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade400),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.red.shade200,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'NEW COUNTY: all 4 fields changed. '
                                    'Each Save opens the CONFIRM warning dialog.',
                                    style: TextStyle(
                                      color: Colors.red.shade100,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _canSave ? _saveCountyInfo : null,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
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
                                      ? 'Save (New County Warning)'
                                      : 'Save Changes',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _allFieldsChanged
                                  ? Colors.red.shade700
                                  : (_canSave
                                      ? Colors.blue
                                      : Colors.grey.shade700),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade700,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        if (_countyInfo != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade800),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current County Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade300,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _infoRow('Name', _countyInfo!.countyName),
                                _infoRow('Address', _countyInfo!.countyAddress),
                                _infoRow(
                                  'Contact',
                                  _countyInfo!.countyContactNo.isEmpty
                                      ? 'Not set'
                                      : _countyInfo!.countyContactNo,
                                ),
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
            ? const Icon(Icons.edit, color: Colors.orange)
            : null,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
