import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/county_profile.dart';
import '../../providers/providers.dart';
import '../../services/app_preferences_service.dart';
import '../../widgets/county_logo.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _reg = TextEditingController();
  final _contact = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _reg.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _hydrate(CountyProfile profile) {
    if (_hydrated) return;
    _name.text = profile.countyName;
    _address.text = profile.countyAddress;
    _reg.text = profile.countyRegNo;
    _contact.text = profile.countyContactNo;
    _hydrated = true;
  }

  Future<void> _pickLogo({required bool secondary}) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;
    final bytes = pick.files.single.bytes;
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
            content: Text(secondary ? 'Second logo saved' : 'Logo saved'),
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
    setState(() => _saving = true);
    try {
      final current =
          ref.read(countyProfileProvider).valueOrNull ?? const CountyProfile();
      final updated = current.copyWith(
        countyName: _name.text.trim().isEmpty
            ? 'Garden Town County'
            : _name.text.trim(),
        countyAddress: _address.text.trim(),
        countyRegNo: _reg.text.trim(),
        countyContactNo: _contact.text.trim(),
      );
      await ref.read(countySettingsServiceProvider).save(updated);
      ref.invalidate(countyProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('County information saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final profileAsync = ref.watch(countyProfileProvider);

    profileAsync.whenData(_hydrate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.settings,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.forestGreen,
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
        if (isAdmin) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.countyInfo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const RoundCountyLogo(size: 88),
                      const SizedBox(width: 16),
                      const RoundCountyLogo(secondary: true, size: 56),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: strings.countyName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration:
                        InputDecoration(labelText: strings.countyAddress),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reg,
                    decoration: InputDecoration(labelText: strings.countyRegNo),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contact,
                    decoration:
                        InputDecoration(labelText: strings.countyContactNo),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickLogo(secondary: false),
                        icon: const Icon(Icons.upload),
                        label: Text(strings.uploadLogo),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickLogo(secondary: true),
                        icon: const Icon(Icons.upload_file),
                        label: Text(strings.uploadSecondaryLogo),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _saveCounty,
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
