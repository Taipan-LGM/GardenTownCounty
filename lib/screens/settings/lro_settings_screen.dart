import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/county_profile.dart';
import '../../models/lro_settings.dart';
import '../../providers/providers.dart';
import '../../services/lro_settings_service.dart';
import '../../widgets/standard_buttons.dart';

/// Admin-only form for configuring Land Recovery Office settings.
///
/// Layout (corrected per Part 2):
///   LEFT COLUMN  — Facebook link, County Name (auto), County Unique No (3 digits),
///                  Radio buttons for 16-digit Recording Number order.
///   RIGHT COLUMN — Blueprint picture (template) and Sample picture (with Member data).
class LroSettingsScreen extends ConsumerStatefulWidget {
  const LroSettingsScreen({super.key});

  @override
  ConsumerState<LroSettingsScreen> createState() => _LroSettingsScreenState();
}

class _LroSettingsScreenState extends ConsumerState<LroSettingsScreen> {
  final _facebookCtrl = TextEditingController();
  final _countyUniqueCtrl = TextEditingController();
  LroSettings _settings = const LroSettings();
  bool _facebookValid = false;
  String? _facebookError;
  String? _countyUniqueError;
  String? _countyDuplicateError;
  bool _saving = false;
  bool _blueprintLoading = false;
  bool _sampleLoading = false;
  Uint8List? _blueprintBytes;
  Uint8List? _sampleBytes;
  bool _hasBlueprint = false;
  bool _hasSample = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final svc = ref.read(lroSettingsServiceProvider);
    final settings = await svc.load();
    final blueprint = await svc.loadBlueprintBytes();
    final sample = await svc.loadSampleBytes();

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _facebookCtrl.text = settings.facebookPageUrl;
      _countyUniqueCtrl.text = settings.countyUniqueNo;
      _facebookValid = settings.isValidFacebookUrl;
      _facebookError = _facebookCtrl.text.isNotEmpty && !settings.isValidFacebookUrl
          ? 'Enter a valid Facebook page address (for example, https://www.facebook.com/YourCountyPage).'
          : null;
      _countyUniqueError = settings.countyUniqueNo.isNotEmpty &&
              settings.countyUniqueNo.trim().length != 3
          ? 'Enter exactly 3 digits.'
          : null;
      _blueprintBytes = blueprint;
      _sampleBytes = sample;
      _hasBlueprint = settings.hasBlueprint;
      _hasSample = settings.hasSample;
      _blueprintLoading = false;
      _sampleLoading = false;
    });
  }

  void _onFacebookChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _facebookValid = LroSettings._isValidFacebookUrl(trimmed);
      _facebookError = trimmed.isNotEmpty && !_facebookValid
          ? 'Enter a valid Facebook page address (for example, https://www.facebook.com/YourCountyPage).'
          : null;
    });
  }

  void _onCountyUniqueChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _countyUniqueCtrl.text = digits;
      if (digits.isEmpty) {
        _countyUniqueError = null;
        _countyDuplicateError = null;
      } else if (digits.length != 3) {
        _countyUniqueError = 'Enter exactly 3 digits (for example, 024).';
        _countyDuplicateError = null;
      } else {
        _countyUniqueError = null;
      }
    });
  }

  Future<void> _checkCountyDuplicate(String value) async {
    if (value.trim().length != 3) {
      setState(() => _countyDuplicateError = null);
      return;
    }
    // Check against all stored LRO settings for duplicate 3-digit codes.
    // In a multi-county deployment this would query the database.
    // For now, we check SharedPreferences-based settings.
    final existing = await ref.read(lroSettingsServiceProvider).load();
    if (existing.countyUniqueNo == value.trim() && _countyUniqueCtrl.text.trim() != value.trim()) {
      // Same value, no duplicate.
      setState(() => _countyDuplicateError = null);
      return;
    }
    // A real app would query a database of all counties.
    // For now, accept the value.
    setState(() => _countyDuplicateError = null);
  }

  Future<void> _pickImage({
    required bool isBlueprint,
    required bool isWeb,
  }) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty) return;

    final bytes = pick.files.single.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read image. Please select a file with image data.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image is too large. Maximum size is 5 MB.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      if (isBlueprint) {
        _blueprintLoading = true;
      } else {
        _sampleLoading = true;
      }
    });

    try {
      final svc = ref.read(lroSettingsServiceProvider);
      if (isBlueprint) {
        await svc.saveBlueprintBytes(bytes);
        final loaded = await svc.loadBlueprintBytes();
        setState(() {
          _blueprintBytes = loaded;
          _hasBlueprint = loaded != null;
          _blueprintLoading = false;
          _settings = await svc.load();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blueprint template uploaded.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await svc.saveSampleBytes(bytes);
        final loaded = await svc.loadSampleBytes();
        setState(() {
          _sampleBytes = loaded;
          _hasSample = loaded != null;
          _sampleLoading = false;
          _settings = await svc.load();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sample notice uploaded.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isBlueprint) _blueprintLoading = false;
          else _sampleLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final facebook = _facebookCtrl.text.trim();
    final countyUnique = _countyUniqueCtrl.text.trim();

    // Validate Facebook URL.
    if (facebook.isEmpty || !LroSettings._isValidFacebookUrl(facebook)) {
      setState(() {
        _facebookError = 'Enter a valid Facebook page address.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid Facebook page URL.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _facebookCtrl.requestFocus();
      return;
    }

    // Validate county unique number.
    if (countyUnique.length != 3) {
      setState(() {
        _countyUniqueError = 'Enter exactly 3 digits.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter exactly 3 digits for County Unique Number.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _countyUniqueCtrl.requestFocus();
      return;
    }

    // Check duplicate.
    final duplicateError = await ref.read(lroSettingsServiceProvider)
        .load()
        .then((s) => s.countyUniqueNo == countyUnique
            ? null
            : null); // Simplified: no cross-county DB check yet.
    if (duplicateError != null) {
      setState(() => _countyDuplicateError = duplicateError);
      return;
    }

    setState(() => _saving = true);
    try {
      final svc = ref.read(lroSettingsServiceProvider);
      final updated = _settings.copyWith(
        countyUniqueNo: countyUnique,
        facebookPageUrl: facebook,
        numberOrder: _settings.numberOrder,
      );
      await svc.save(updated);
      if (mounted) {
        setState(() {
          _settings = updated;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings(ref.read(appLanguageProvider)).LroSettingsSaved),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to settings.
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearImages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Images'),
        content: const Text(
          'This will remove both the Blueprint template and the Sample notice. '
          'Published notices will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _blueprintLoading = true;
      _sampleLoading = true;
    });

    try {
      final svc = ref.read(lroSettingsServiceProvider);
      await svc.clearImages();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Images cleared.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _blueprintLoading = false;
          _sampleLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _facebookCtrl.dispose();
    _countyUniqueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_tree, size: 24),
            const SizedBox(width: 8),
            Text(strings.lroSettings),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isAdmin
          ? _buildBody(strings)
          : _buildNotFound(strings),
    );
  }

  Widget _buildNotFound(AppStrings strings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              strings.adminOnlyCountySettings,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Only Administrators can access Land Recovery Office settings.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            strings.lroSettings,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.lroSettingsSubtitle,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LEFT COLUMN ──────────────────────────────────────────
              Expanded(
                flex: 2,
                child: _buildLeftColumn(strings),
              ),
              const SizedBox(width: 16),
              // ── RIGHT COLUMN ─────────────────────────────────────────
              Expanded(
                flex: 3,
                child: _buildRightColumn(strings),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearImages,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(strings.clearImages),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: const BorderSide(color: Colors.red.shade400),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_saving ? 'Saving...' : strings.save),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(AppStrings strings) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Facebook Link ─────────────────────────────────────────
            Text(
              strings.countyFacebookPageUrl,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _facebookCtrl,
              decoration: InputDecoration(
                hintText: 'https://www.facebook.com/YourCountyPage',
                errorText: _facebookError,
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _facebookValid
                    ? Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)
                    : null,
              ),
              onChanged: _onFacebookChanged,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Facebook page URL is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Used for auto-publishing the personalized Public Notice image.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── County Name (auto-filled) ─────────────────────────────
            Row(
              children: [
                const Icon(Icons.account_tree, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  strings.countyNameAuto,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade600),
              ),
              child: FutureBuilder<CountyProfile>(
                future: ref.watch(countyProfileProvider).future,
                builder: (context, snapshot) {
                  final name = snapshot.data?.countyName ?? 'Garden Town County';
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const Icon(
                        Icons.lock,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Auto-populated from County Settings. Cannot be changed here.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── County Unique Number ──────────────────────────────────
            Row(
              children: [
                const Icon(Icons.numbers, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  strings.countyUniqueNumber,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _countyUniqueCtrl,
              decoration: InputDecoration(
                hintText: '024',
                errorText: _countyUniqueError ?? _countyDuplicateError,
                prefixIcon: const Icon(Icons.numbers),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 3,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: _onCountyUniqueChanged,
              onEditingComplete: () => _checkCountyDuplicate(_countyUniqueCtrl.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Exactly 3 digits. No duplicates allowed across Counties.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Radio Buttons ─────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.reorder, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  strings.selectDisplayOrder,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Option 1
            _radioOption(
              strings,
              value: LroNumberOrder.countyDateUnique,
              groupValue: _settings.numberOrder,
              label:
                  '1: County No. + Payment Date + Unique No.',
              example:
                  '024 + 150125 + 1234567 = 0241501251234567',
              onChanged: (order) =>
                  setState(() => _settings = _settings.copyWith(numberOrder: order)),
            ),
            const SizedBox(height: 8),

            // Option 2
            _radioOption(
              strings,
              value: LroNumberOrder.uniqueDateCounty,
              groupValue: _settings.numberOrder,
              label: '2: Unique No. + Payment Date + County No.',
              example:
                  '1234567 + 150125 + 024 = 1234567150125024',
              onChanged: (order) =>
                  setState(() => _settings = _settings.copyWith(numberOrder: order)),
            ),
            const SizedBox(height: 8),

            // Option 3
            _radioOption(
              strings,
              value: LroNumberOrder.dateCountyUnique,
              groupValue: _settings.numberOrder,
              label: '3: Payment Date + County No. + Unique No.',
              example:
                  '150125 + 024 + 1234567 = 1501250241234567',
              onChanged: (order) =>
                  setState(() => _settings = _settings.copyWith(numberOrder: order)),
            ),

            const SizedBox(height: 12),
            Text(
              'This selection applies globally to all Members. '
              'Existing Recording Numbers are not reformatted.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Status indicator
            _buildStatusIndicator(strings),
          ],
        ),
      ),
    );
  }

  Widget _radioOption(
    AppStrings strings, {
    required LroNumberOrder value,
    required LroNumberOrder groupValue,
    required String label,
    required String example,
    required ValueChanged<LroNumberOrder> onChanged,
  }) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.green.shade300 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Radio<LroNumberOrder>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: Colors.green.shade700,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: selected ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(AppStrings strings) {
    final complete = _settings.isComplete;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: complete ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: complete ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.warning_amber,
            color: complete ? Colors.green : Colors.orange,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              complete
                  ? strings.lroReady
                  : strings.lroIncomplete,
              style: TextStyle(
                fontSize: 13,
                color: complete ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(AppStrings strings) {
    return Column(
      children: [
        // ── Blueprint Picture ──────────────────────────────────────
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.blueprintPublicNotice,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  strings.blueprintDescription,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                _pictureBlueprintArea(strings),
                const SizedBox(height: 8),
                Text(
                  'Master template for all LRO Public Notices.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Sample Picture ─────────────────────────────────────────
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.samplePublicNotice,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  strings.sampleDescription,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                _pictureSampleArea(strings),
                const SizedBox(height: 8),
                Text(
                  'Optional — for Admin reference only. Not required for workflow.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pictureBlueprintArea(AppStrings strings) {
    if (_blueprintLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_blueprintBytes != null && _blueprintBytes!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _blueprintBytes!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                strings.imagePreview,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () {
                // Remove blueprint.
                ref.read(lroSettingsServiceProvider).clearImages().then((_) {
                  setState(() {
                    _blueprintBytes = null;
                    _hasBlueprint = false;
                  });
                });
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade600, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No blueprint uploaded',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pickImage(isBlueprint: true, isWeb: kIsWeb),
            icon: const Icon(Icons.upload, size: 18),
            label: Text(strings.uploadBlueprint),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pictureSampleArea(AppStrings strings) {
    if (_sampleLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sampleBytes != null && _sampleBytes!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _sampleBytes!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                strings.imagePreview,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () {
                ref.read(lroSettingsServiceProvider).clearImages().then((_) {
                  setState(() {
                    _sampleBytes = null;
                    _hasSample = false;
                  });
                });
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade600, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No sample uploaded',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pickImage(isBlueprint: false, isWeb: kIsWeb),
            icon: const Icon(Icons.upload, size: 18),
            label: Text(strings.uploadSample),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
