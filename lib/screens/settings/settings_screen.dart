import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/county_profile.dart';
import '../../providers/providers.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/standard_buttons.dart';
import '../../widgets/county_logo.dart';
import '../../widgets/new_county_warning_dialog.dart';
import 'remuneration_dashboard_screen.dart';
import 'remuneration_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.settings,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.bodyText,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.theme,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(strings.light),
                      icon: const Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(strings.dark),
                      icon: const Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {
                    themeMode == ThemeMode.dark
                        ? ThemeMode.dark
                        : ThemeMode.light,
                  },
                  onSelectionChanged: (set) async {
                    final mode = set.first;
                    ref.read(themeModeProvider.notifier).state = mode;
                    await ref
                        .read(appPreferencesServiceProvider)
                        .saveThemeMode(mode);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  strings.language,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AppLanguage>(
                  segments: [
                    ButtonSegment(
                      value: AppLanguage.english,
                      label: Text(strings.english),
                    ),
                    ButtonSegment(
                      value: AppLanguage.afrikaans,
                      label: Text(strings.afrikaans),
                    ),
                  ],
                  selected: {language},
                  onSelectionChanged: (set) async {
                    final lang = set.first;
                    ref.read(appLanguageProvider.notifier).state = lang;
                    await ref
                        .read(appPreferencesServiceProvider)
                        .saveLanguage(lang);
                  },
                ),
              ],
            ),
          ),
        ),
        // Outside Theme card — far left, under Theme/Language form.
        if (isAdmin) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionButton(
              onPressed: () => showCountySettingsDialog(context, ref),
              text: 'County Settings (logos)',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.attach_money, color: Colors.green),
                  title: const Text('RS Remuneration'),
                  subtitle: const Text(
                    'Configure Recording Secretary payment amounts',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RemunerationSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.blue),
                  title: const Text('Remuneration Dashboard'),
                  subtitle: const Text('Pending / approved / paid overview'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RemunerationDashboardScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.science, color: Colors.orange),
                  title: const Text('Generate Test Data'),
                  subtitle: const Text(
                    'Secretaries, members, reminders, remuneration',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _generateTestData(context),
                ),
              ],
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Sign in as Admin to open County Settings (logos).',
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 48),
      ],
    );
  }

  // NEW ADDITION - test data confirm dialog (Delete method to revert)
  Future<void> _generateTestData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Test Data?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create test data including:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 3 Recording Secretaries'),
            Text('• 4 Test Members'),
            Text('• 3 Active Reminders'),
            Text('• 3 Remuneration Records'),
            SizedBox(height: 8),
            Text('Existing rows with same IDs are skipped.'),
          ],
        ),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(context, false),
            text: 'Cancel',
          ),
          ActionButton(
            onPressed: () => Navigator.pop(context, true),
            text: 'Generate',
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(testDataServiceProvider).generateTestData();
      ref.invalidate(membersProvider);
      ref.invalidate(appUsersProvider);
      ref.invalidate(activeOnboardingRemindersProvider);
      ref.invalidate(reminderStatsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test data generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating test data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> showCountySettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => const CountySettingsDialog(),
  );
}

class CountySettingsDialog extends ConsumerStatefulWidget {
  const CountySettingsDialog({super.key});

  @override
  ConsumerState<CountySettingsDialog> createState() =>
      _CountySettingsDialogState();
}

class _CountySettingsDialogState extends ConsumerState<CountySettingsDialog> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _reg = TextEditingController();
  bool _logosReady = false;
  bool _identityReady = false;
  bool _saving = false;

  String _originalName = '';
  String _originalAddress = '';
  String _originalContact = '';
  String _originalRegistration = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIdentity());
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contact.dispose();
    _reg.dispose();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    try {
      final info = await ref.read(countyInfoServiceProvider).getCountyInfo();
      if (!mounted) return;
      setState(() {
        _originalName = info.countyName;
        _originalAddress = info.countyAddress;
        _originalContact = info.countyContactNo;
        _originalRegistration = info.countyRegistrationNo;
        _name.text = info.countyName;
        _address.text = info.countyAddress;
        _contact.text = info.countyContactNo;
        _reg.text = info.countyRegistrationNo;
        _identityReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading county info: $e')),
      );
    }
  }

  void _markLogosReady(CountyProfile profile) {
    if (_logosReady) return;
    _logosReady = true;
  }

  Future<void> _pickLogo({required bool secondary}) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty) return;

    var bytes = pick.files.single.bytes;
    if (bytes == null && !kIsWeb && pick.files.single.path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please re-select the image (bytes required).'),
        ),
      );
      return;
    }
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read image bytes.')),
        );
      }
      return;
    }

    try {
      final path = await ref
          .read(countySettingsServiceProvider)
          .saveLogoBytes(bytes, secondary: secondary);
      final current =
          ref.read(countyProfileProvider).valueOrNull ?? const CountyProfile();
      final updated = secondary
          ? current.copyWith(secondaryLogoPath: path)
          : current.copyWith(logoPath: path);
      await ref.read(countySettingsServiceProvider).save(updated);
      ref.invalidate(countyProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              secondary
                  ? 'Second (corner) logo saved'
                  : 'First (background) logo saved',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _saveCounty() async {
    final admin = ref.read(authUserProvider);
    if (admin == null || !admin.isAdmin) return;
    if (!_identityReady) return;

    final name = _name.text.trim().isEmpty
        ? 'Garden Town County'
        : _name.text.trim();
    final address = _address.text.trim();
    final contact = _contact.text.trim();
    final registration = _reg.text.trim();

    if (address.isEmpty || contact.isEmpty || registration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Address, Contact No., and Registration No. are required.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final allFourChanged = countyAllFourFieldsChanged(
      name: name,
      address: address,
      contact: contact,
      registration: registration,
      originalName: _originalName,
      originalAddress: _originalAddress,
      originalContact: _originalContact,
      originalRegistration: _originalRegistration,
    );

    var isNewCounty = false;
    if (allFourChanged) {
      final confirmed = await showNewCountyWarningDialog(context);
      if (!confirmed || !mounted) {
        setState(() {}); // warning must show again on next Save
        return;
      }
      isNewCounty = true;
    }

    setState(() => _saving = true);
    try {
      await ref.read(countyInfoServiceProvider).updateCountyInfo(
            countyName: name,
            countyAddress: address,
            countyContactNo: contact,
            countyRegistrationNo: registration,
            admin: admin,
            isNewCounty: isNewCounty,
          );

      ref.invalidate(countyProfileProvider);
      ref.invalidate(countyInfoProvider);
      if (isNewCounty) {
        ref.invalidate(membersProvider);
        ref.invalidate(appUsersProvider);
        ref.invalidate(activitiesProvider);
        ref.invalidate(remindersProvider);
        ref.invalidate(activeOnboardingRemindersProvider);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNewCounty
                ? 'New county registered — operational data cleared'
                : 'County information saved',
          ),
          backgroundColor: isNewCounty ? Colors.orange.shade800 : Colors.green,
        ),
      );
      if (isNewCounty) {
        Navigator.pop(context);
      } else {
        await _loadIdentity();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final profileAsync = ref.watch(countyProfileProvider);
    profileAsync.whenData(_markLogosReady);

    final allFour = countyAllFourFieldsChanged(
      name: _name.text,
      address: _address.text,
      contact: _contact.text,
      registration: _reg.text,
      originalName: _originalName,
      originalAddress: _originalAddress,
      originalContact: _originalContact,
      originalRegistration: _originalRegistration,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Material(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'County Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 1. LOGOS ON TOP
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Logos (Admin)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              RoundCountyLogo(size: 72),
                              SizedBox(height: 6),
                              Text(
                                'First logo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              RoundCountyLogo(secondary: true, size: 56),
                              SizedBox(height: 6),
                              Text(
                                'Second logo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AddButton(
                              onPressed: () => _pickLogo(secondary: false),
                              text: strings.uploadLogo,
                              icon: Icons.upload,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AddButton(
                              onPressed: () => _pickLogo(secondary: true),
                              text: strings.uploadSecondaryLogo,
                              icon: Icons.upload_file,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 2. FORM FIELDS
                Text(
                  strings.countyInfo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _darkFieldDecoration(strings.countyName),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _address,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 4,
                  decoration: _darkFieldDecoration(strings.countyAddress),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contact,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration:
                            _darkFieldDecoration(strings.countyContactNo),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _reg,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _darkFieldDecoration(strings.countyRegNo),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (allFour) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade400),
                    ),
                    child: const Text(
                      'NEW COUNTY: all 4 fields changed. Save shows CONFIRM each time.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Cancel left, Save right
                Row(
                  children: [
                    CancelButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Cancel',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: allFour
                          ? ActionButton(
                              onPressed: (_saving || !_identityReady)
                                  ? null
                                  : _saveCounty,
                              text: _saving
                                  ? 'Saving...'
                                  : 'Register New County',
                              isLoading: _saving,
                              icon: Icons.warning,
                            )
                          : SaveButton(
                              onPressed: (_saving || !_identityReady)
                                  ? null
                                  : _saveCounty,
                              text: _saving ? 'Saving...' : strings.save,
                              isLoading: _saving,
                              icon: Icons.save,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _darkFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
      filled: true,
      fillColor: Colors.grey.shade800,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }
}
