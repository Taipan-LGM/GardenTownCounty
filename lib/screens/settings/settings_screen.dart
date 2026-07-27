import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/county_profile.dart';
import '../../providers/providers.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/county_logo.dart';
import '../../widgets/new_county_warning_dialog.dart';
import 'county_info_settings_screen.dart';
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
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.forestGreen,
                side: const BorderSide(color: Colors.white, width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () => showCountySettingsDialog(context, ref),
              child: const Text(
                'County Settings (logos)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                // NEW ADDITION - County Information (Delete ListTile to revert)
                ListTile(
                  leading: const Icon(Icons.business, color: Colors.blue),
                  title: const Text('County Information'),
                  subtitle: const Text(
                    'Update county details and register a new county',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CountyInfoSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
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
              'Sign in as Admin to open County Settings '
              '(logos and County information).',
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
              child: Row(
                children: [
                  Text(
                    'County Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.bodyText,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  // Identity first so fields visible without scrolling past logos.
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.countyInfo,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _name,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: strings.countyName,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _address,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: strings.countyAddress,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            maxLines: 2,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _contact,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    labelText: strings.countyContactNo,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _reg,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    labelText: strings.countyRegNo,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
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
                              if (!allFour) {
                                return Text(
                                  'Changing ALL 4 fields opens a New County '
                                  'warning (type CONFIRM) every time you Save.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                );
                              }
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade300),
                                ),
                                child: Text(
                                  'NEW COUNTY: all 4 fields changed. '
                                  'Save will show CONFIRM warning each time.',
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: (_saving || !_identityReady)
                                  ? null
                                  : _saveCounty,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(strings.save),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.cream,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Logos (Admin)',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.bodyText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'First logo = fixed Home background. '
                            'Second logo = corner emblem after animation.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const RoundCountyLogo(size: 96),
                                  const SizedBox(height: 8),
                                  Text(
                                    'First logo',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const RoundCountyLogo(
                                    secondary: true,
                                    size: 72,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Second logo',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _pickLogo(secondary: false),
                            icon: const Icon(Icons.upload),
                            label: Text(strings.uploadLogo),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _pickLogo(secondary: true),
                            icon: const Icon(Icons.upload_file),
                            label: Text(strings.uploadSecondaryLogo),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
