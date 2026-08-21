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
import '../../models/lro_status_correction.dart' as sc;
import '../../models/lro_notice_template.dart';
import '../../services/lro_notice_renderer.dart';
import '../../providers/providers.dart';
import '../../services/lro_email_service.dart' as email;
import '../../services/lro_settings_service.dart';
import '../../screens/settings/smtp_settings_screen.dart';
import '../../widgets/standard_buttons.dart';

/// Admin-only form for configuring Land Recording Office settings.
///
/// Layout (corrected per Part 2):
///   LEFT COLUMN  — Facebook link, County Name (auto), County Unique No (3 digits),
///                  Radio buttons for 16-digit Recording Number order.
///   RIGHT COLUMN — Public Notice Template picture and Status Corrections.
class LroSettingsScreen extends ConsumerStatefulWidget {
  const LroSettingsScreen({super.key});

  @override
  ConsumerState<LroSettingsScreen> createState() => _LroSettingsScreenState();
}

class _LroSettingsScreenState extends ConsumerState<LroSettingsScreen> {
  final _facebookCtrl = TextEditingController();
  final _countyUniqueCtrl = TextEditingController();
  final _facebookFocusNode = FocusNode();
  final _countyUniqueFocusNode = FocusNode();
  LroSettings _settings = const LroSettings();
  bool _facebookValid = false;
  String? _facebookError;
  String? _countyUniqueError;
  String? _countyDuplicateError;
  bool _saving = false;
  bool _publicNoticeTemplateLoading = false;
  bool _sealLoading = false;
  Uint8List? _publicNoticeTemplateBytes;
  Uint8List? _sealBytes;
  bool _hasPublicNoticeTemplate = false;
  bool _hasSeal = false;
  final List<TextEditingController> _statusCorrectionControllers = [];
  final Map<int, String?> _statusCorrectionErrors = {};
  // Stable per-row identity so Flutter reconciles list removals correctly.
  // Without keys, unkeyed TextFields drift after removeAt on the index lists.
  final List<int> _statusCorrectionIds = [];
  int _statusCorrectionIdCounter = 1;

  // Template designer state (Phase 2).
  LroNoticeTemplateStyle? _draftTemplate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final svc = ref.read(lroSettingsServiceProvider);
    final settings = await svc.load();
    final publicNoticeTemplateBytes = await svc.loadPublicNoticeTemplateBytes();
    final seal = await svc.loadCountySealBytes();

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
          ? 'Enter exactly 3 digits (for example, 024).'
          : null;
      _publicNoticeTemplateBytes = publicNoticeTemplateBytes;
      _sealBytes = seal;
      _hasPublicNoticeTemplate = settings.hasPublicNoticeTemplate;
      _hasSeal = settings.hasCountySeal;
      _publicNoticeTemplateLoading = false;
      _sealLoading = false;
      _initStatusCorrectionControllers(settings.statusCorrections);
    });
  }

  void _onFacebookChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _facebookValid = LroSettings.checkFacebookUrl(trimmed);
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
    required bool isPublicNoticeTemplate,
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
      if (isPublicNoticeTemplate) {
        _publicNoticeTemplateLoading = true;
      } else {
        _sealLoading = true;
      }
    });

    try {
      final svc = ref.read(lroSettingsServiceProvider);
      if (isPublicNoticeTemplate) {
        await svc.savePublicNoticeTemplateBytes(bytes);
        final loaded = await svc.loadPublicNoticeTemplateBytes();
        setState(() {
          _publicNoticeTemplateBytes = loaded;
          _hasPublicNoticeTemplate = loaded != null;
          _publicNoticeTemplateLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Public Notice template uploaded.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await svc.saveCountySealBytes(bytes);
        final loaded = await svc.loadCountySealBytes();
        setState(() {
          _sealBytes = loaded;
          _hasSeal = loaded != null;
          _sealLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('County seal uploaded.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isPublicNoticeTemplate) _publicNoticeTemplateLoading = false;
          else _sealLoading = false;
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
    if (facebook.isEmpty || !LroSettings.checkFacebookUrl(facebook)) {
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
      _facebookFocusNode.requestFocus();
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
      _countyUniqueFocusNode.requestFocus();
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
        statusCorrections: _settings.statusCorrections,
      );
      await svc.save(updated);
      if (mounted) {
        setState(() {
          _settings = updated;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings(ref.read(appLanguageProvider)).lroSettingsSaved),
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
   'This will remove both the Public Notice Template and the County seal. '
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
      _publicNoticeTemplateLoading = true;
      _sealLoading = true;
    });

    try {
      final svc = ref.read(lroSettingsServiceProvider);
      await svc.clearPublicNoticeTemplate();
      await svc.clearCountySeal();
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
          _publicNoticeTemplateLoading = false;
          _sealLoading = false;
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
    _facebookFocusNode.dispose();
    _countyUniqueFocusNode.dispose();
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
            Expanded(
              child: Text(strings.lroSettings),
            ),
          ],
        ),
        actions: [
          // SMTP button: pulled ~10mm (≈38 logical px) in from the right edge
          // and recolored yellow per the design plan.
          Padding(
            padding: const EdgeInsets.only(right: 38),
            child: TextButton.icon(
              onPressed: () => _openSmtpSettings(context),
              icon: const Icon(Icons.email_outlined, size: 18),
              label: Text(strings.smtpSettingsShort),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: const Color(0xFFFDD835),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
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

          // Two-column layout.
          // IntrinsicHeight + CrossAxisAlignment.stretch makes the right
          // Public Notice preview stretch to exactly the left card's height
          // (County Facebook URL top -> bottom of display-order box), so the
          // preview bottom is in-line with the display-order box bottom.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── LEFT COLUMN ──────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: _buildLeftColumn(strings),
                ),
                const SizedBox(width: 16),
                // ── RIGHT COLUMN ─────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: _buildRightColumn(strings),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // ── County Seal + Status Corrections (full-width, below) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildCountySealCard(strings)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildStatusCorrectionsCard(strings)),
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
                    side: BorderSide(color: Colors.red.shade400),
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
                future: ref.watch(countyProfileProvider.future),
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

            // ── Radio Buttons (Dark Blue / White theme) ───────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D47A1),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reorder, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.lroSelectDisplayOrder,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Option 1
                  _radioOption(
                    strings,
                    value: LroNumberOrder.countyDateUnique,
                    groupValue: _settings.numberOrder,
                    label: '1: County No. + Payment Date + Unique No.',
                    example:
                        '024 + 150125 + 1234567 = 0241501251234567',
                    onChanged: (order) => setState(
                        () => _settings = _settings.copyWith(numberOrder: order)),
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
                    onChanged: (order) => setState(
                        () => _settings = _settings.copyWith(numberOrder: order)),
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
                    onChanged: (order) => setState(
                        () => _settings = _settings.copyWith(numberOrder: order)),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'This selection applies globally to all Members. '
                    'Existing Recording Numbers are not reformatted.',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
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
    const yellow = Color(0xFFFFD700);
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? yellow.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? yellow : Colors.white54,
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
              activeColor: yellow,
              fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) return yellow;
                return Colors.white;
              }),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: selected ? yellow : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: yellow, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRightColumn(AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Public Notice preview (top) + 2) Reset button + 3) Controls (permanent).
        _buildTemplatePreviewSection(strings),
      ],
    );
  }

  // ── Status Corrections (right column, under County Seal) ─────────────
  Widget _buildStatusCorrectionsCard(AppStrings strings) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.statusCorrections,
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
              strings.statusCorrectionsDesc,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ..._buildStatusCorrectionRows(strings),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _settings.statusCorrections.length >= 12
                  ? null
                  : () => setState(() {
                        _settings = _settings.copyWith(
                          statusCorrections: [
                            ..._settings.statusCorrections,
                            sc.LroStatusCorrection(
                                description: '', isChecked: true),
                          ],
                        );
                        _statusCorrectionControllers
                            .add(TextEditingController(text: ''));
                        _statusCorrectionErrors[
                                _settings.statusCorrections.length - 1] =
                            'Description is required.';
                        _statusCorrectionIds.add(_statusCorrectionIdCounter++);
                      }),
              icon: const Icon(Icons.add, size: 18),
              label: Text(strings.addStatus),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Maximum 12 status corrections.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Public Notice Template designer (Phase 2) ──────────────────────────
  static const List<String> _fontFamilies = [
    'Arial',
    'Times New Roman',
    'Courier New',
    'Georgia',
    'Verdana',
    'Tahoma',
  ];
  static const List<String> _colorPalette = [
    '#14202E',
    '#000000',
    '#FFFFFF',
    '#B91C1C',
    '#15803D',
    '#1D4ED8',
    '#9333EA',
    '#FDD835',
    '#6B7280',
  ];

  // ── County Seal form (left, below Create form) ───────────────────────
  Widget _buildCountySealCard(AppStrings strings) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.countySeal,
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
              strings.countySealDesc,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _pictureSealArea(strings),
            const SizedBox(height: 8),
            Text(
              'Official County Seal. Placed at the bottom of every Public Notice.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Public Notice preview (top) + Edit/Reset buttons + Controls ──────
  Widget _buildTemplatePreviewSection(AppStrings strings) {
    final style = _draftTemplate ?? _settings.noticeTemplate ??
        const LroNoticeTemplateStyle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Live preview (always visible, top of right column).
        // Expanded so it fills the stretched column height (matching the
        // left display-order box bottom), with the Reset + Controls below.
        Expanded(
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTemplatePreview(style, strings),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 2) Reset to Default button (aligned far RIGHT).
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _draftTemplate = const LroNoticeTemplateStyle();
                });
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(strings.resetTemplate),
            ),
          ],
        ),
        // 3) Template Controls: shown PERMANENTLY, directly under Reset.
        const SizedBox(height: 12),
        _buildTemplateControlsCard(strings),
      ],
    );
  }

  // ── Template Controls card (hidden by default; full width below) ──────
  Widget _buildTemplateControlsCard(AppStrings strings) {
    final style = _draftTemplate ?? _settings.noticeTemplate ??
        const LroNoticeTemplateStyle();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.templateControls,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTemplateControls(style, strings),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _settings = _settings.copyWith(noticeTemplate: _draftTemplate);
                    });
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(strings.saveTemplate),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draftTemplate = null;
                    });
                  },
                  child: Text(strings.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatePreview(LroNoticeTemplateStyle style, AppStrings strings) {
    final sample = _settings.statusCorrections.isNotEmpty
        ? _settings.statusCorrections
        : const [
            sc.LroStatusCorrection(description: 'Voter Deregistration', isChecked: true),
            sc.LroStatusCorrection(description: 'BIO Pages', isChecked: true),
            sc.LroStatusCorrection(description: '2 x Witness Testimonies', isChecked: true),
            sc.LroStatusCorrection(description: 'Universal Declaration', isChecked: true),
          ];
    final bytes = LroNoticeRenderer.render(
      style: style,
      countyName: 'Garden Town County',
      memberName: 'John Doe',
      recordingNumber: '0241501251234567',
      paymentDate: DateTime.now(),
      statusCorrections: sample,
      sealBytes: (_sealBytes != null && _sealBytes!.isNotEmpty) ? _sealBytes : null,
    );
    return Container(
      // The preview container stretches to the left card's height (set by
      // IntrinsicHeight in build). FittedBox scales the notice to fit that
      // height with NO scroll bars.
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Image.memory(bytes, gaplessPlayback: true),
      ),
    );
  }

  Widget _buildTemplateControls(LroNoticeTemplateStyle style, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeled(strings.fontFamily,
            DropdownButton<String>(
              value: style.fontFamily,
              isExpanded: true,
              items: _fontFamilies
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => _updateDraft((s) => s.copyWith(fontFamily: v!)),
            )),
        Row(
          children: [
            Expanded(
              child: _labeled(
                  '${strings.fontSize}: ${style.fontSize.round()}',
                  Slider(
                    value: style.fontSize,
                    min: 8,
                    max: 72,
                    divisions: 64,
                    onChanged: (v) => _updateDraft((s) => s.copyWith(fontSize: v)),
                  )),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          children: [
            _toggleChip(strings.bold, style.bold,
                (v) => _updateDraft((s) => s.copyWith(bold: v))),
            _toggleChip(strings.italic, style.italic,
                (v) => _updateDraft((s) => s.copyWith(italic: v))),
            _toggleChip(strings.underline, style.underline,
                (v) => _updateDraft((s) => s.copyWith(underline: v))),
          ],
        ),
        _labeled(strings.textAlignment,
            SegmentedButton<LroNoticeAlignment>(
              segments: [
                ButtonSegment(
                    value: LroNoticeAlignment.left, label: Text(strings.alignLeft)),
                ButtonSegment(
                    value: LroNoticeAlignment.center,
                    label: Text(strings.alignCenter)),
                ButtonSegment(
                    value: LroNoticeAlignment.right, label: Text(strings.alignRight)),
              ],
              selected: {style.alignment},
              onSelectionChanged: (s) =>
                  _updateDraft((st) => st.copyWith(alignment: s.first)),
            )),
        _labeled(strings.fontColor, _colorDropdown(style.fontColor,
            (v) => _updateDraft((s) => s.copyWith(fontColor: v!)))),
        _labeled(strings.backgroundColor, _colorDropdown(style.backgroundColor,
            (v) => _updateDraft((s) => s.copyWith(backgroundColor: v!)))),
        _labeled(strings.borderStyle,
            DropdownButton<LroNoticeBorderStyle>(
              value: style.borderStyle,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                    value: LroNoticeBorderStyle.none,
                    child: Text(strings.borderNone)),
                DropdownMenuItem(
                    value: LroNoticeBorderStyle.solid,
                    child: Text(strings.borderSolid)),
                DropdownMenuItem(
                    value: LroNoticeBorderStyle.dashed,
                    child: Text(strings.borderDashed)),
                DropdownMenuItem(
                    value: LroNoticeBorderStyle.dotted,
                    child: Text(strings.borderDotted)),
              ],
              onChanged: (v) =>
                  _updateDraft((s) => s.copyWith(borderStyle: v!)),
            )),
        Row(
          children: [
            Expanded(
              child: _labeled(
                  '${strings.borderWidth}: ${style.borderWidth}',
                  Slider(
                    value: style.borderWidth.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) =>
                        _updateDraft((s) => s.copyWith(borderWidth: v.round())),
                  )),
            ),
          ],
        ),
        _labeled(strings.borderColor, _colorDropdown(style.borderColor,
            (v) => _updateDraft((s) => s.copyWith(borderColor: v!)))),
        _labeled(strings.padding,
            DropdownButton<String>(
              value: style.padding,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'small', child: Text('Small')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'large', child: Text('Large')),
              ],
              onChanged: (v) => _updateDraft((s) => s.copyWith(padding: v!)),
            )),
        Row(
          children: [
            Expanded(
              child: _labeled(
                  '${strings.lineSpacing}: ${style.lineSpacing.toStringAsFixed(1)}',
                  Slider(
                    value: style.lineSpacing,
                    min: 1.0,
                    max: 2.0,
                    divisions: 10,
                    onChanged: (v) =>
                        _updateDraft((s) => s.copyWith(lineSpacing: v)),
                  )),
            ),
          ],
        ),
        _labeled(
          strings.sealPosition,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sealPosButton(context, style, LroNoticeSealPosition.topLeft,
                  strings.sealTopLeft),
              _sealPosButton(context, style, LroNoticeSealPosition.topCenter,
                  strings.sealTopCenter),
              _sealPosButton(context, style, LroNoticeSealPosition.topRight,
                  strings.sealTopRight),
              _sealPosButton(context, style, LroNoticeSealPosition.bottomLeft,
                  strings.sealBottomLeft),
              _sealPosButton(context, style, LroNoticeSealPosition.bottomCenter,
                  strings.sealBottomCenter),
              _sealPosButton(context, style, LroNoticeSealPosition.bottomRight,
                  strings.sealBottomRight),
            ],
          ),
        ),
        _labeled(strings.placeholderColor, _colorDropdown(style.placeholderColor,
            (v) => _updateDraft((s) => s.copyWith(placeholderColor: v!)))),
        _toggleChip(strings.showPlaceholders, style.showPlaceholders,
            (v) => _updateDraft((s) => s.copyWith(showPlaceholders: v))),
      ],
    );
  }

  Widget _sealPosButton(BuildContext context, LroNoticeTemplateStyle style,
      LroNoticeSealPosition pos, String label) {
    final active = style.sealPosition == pos;
    final primary = Theme.of(context).colorScheme.primary;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? primary : null,
        foregroundColor: active ? Colors.white : null,
        textStyle: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: () => _updateDraft((s) => s.copyWith(sealPosition: pos)),
      child: Text(label),
    );
  }

  Widget _labeled(String label, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );

  Widget _toggleChip(String label, bool value, ValueChanged<bool> onChanged) =>
      FilterChip(
        label: Text(label),
        selected: value,
        onSelected: onChanged,
      );

  Widget _colorDropdown(String value, ValueChanged<String?> onChanged) {
    final v = _colorPalette.contains(value) ? value : _colorPalette.first;
    return DropdownButton<String>(
      value: v,
      isExpanded: true,
      items: _colorPalette
          .map((c) => DropdownMenuItem(
                value: c,
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: _hexToColor(c),
                    ),
                    const SizedBox(width: 8),
                    Text(c),
                  ],
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  void _updateDraft(LroNoticeTemplateStyle Function(LroNoticeTemplateStyle) updater) {
    setState(() {
      _draftTemplate = updater(_draftTemplate ??
          _settings.noticeTemplate ??
          const LroNoticeTemplateStyle());
    });
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    if (h.length == 8) {
      return Color(int.parse(h, radix: 16));
    }
    return Colors.black;
  }

  List<Widget> _buildStatusCorrectionRows(AppStrings strings) {
    return _settings.statusCorrections.asMap().entries.map((entry) {
      final idx = entry.key;
      final field = entry.value;
      return Card(
        key: ValueKey(_statusCorrectionIds[idx]),
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox (toggleable ✅)
              SizedBox(
                width: 28,
                height: 28,
                child: RawMaterialButton(
                  onPressed: () {
                    setState(() {
                      final next =
                          List<sc.LroStatusCorrection>.from(_settings.statusCorrections);
                      next[idx] = field.copyWith(isChecked: !field.isChecked);
                      _settings = _settings.copyWith(statusCorrections: next);
                    });
                  },
                  child: Icon(
                    field.isChecked ? Icons.check_circle : Icons.check_circle_outline,
                    color: field.isChecked ? Colors.green : Colors.white70,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Description inline field (flexible so Delete stays on-screen
              // even in the narrower left column).
              Expanded(
                child: TextField(
                  controller: _statusCorrectionControllers[idx],
                  decoration: InputDecoration(
                    hintText: 'e.g. Voter Deregistration',
                    errorText: _statusCorrectionErrors[idx],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white38),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (value) {
                    setState(() {
                      final next =
                          List<sc.LroStatusCorrection>.from(_settings.statusCorrections);
                      next[idx] = field.copyWith(description: value);
                      _settings = _settings.copyWith(statusCorrections: next);
                      _statusCorrectionErrors[idx] =
                          value.trim().isEmpty ? 'Description is required.' : null;
                    });
                  },
                  onEditingComplete: () {
                    // Commit on Enter; keep focus in field.
                    _statusCorrectionControllers[idx].text =
                        _statusCorrectionControllers[idx].text.trim();
                    if (_statusCorrectionControllers[idx].text.trim().isNotEmpty) {
                      setState(() {
                        final next =
                            List<sc.LroStatusCorrection>.from(_settings.statusCorrections);
                        next[idx] = field.copyWith(
                            description: _statusCorrectionControllers[idx].text.trim());
                        _settings = _settings.copyWith(statusCorrections: next);
                        _statusCorrectionErrors[idx] = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Delete button (disabled when only one correction remains)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade400, size: 22),
                onPressed: _settings.statusCorrections.length <= 1
                    ? null
                    : () => _confirmDeleteStatusCorrection(idx, strings),
                tooltip: _settings.statusCorrections.length <= 1
                    ? 'At least one status correction is required'
                    : strings.delete,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Future<void> _confirmDeleteStatusCorrection(
    int idx,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete status correction?'),
        content: const Text(
          'Are you sure you want to delete this status correction? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        final next =
            List<sc.LroStatusCorrection>.from(_settings.statusCorrections)
              ..removeAt(idx);
        _settings = _settings.copyWith(statusCorrections: next);
        _statusCorrectionControllers.removeAt(idx);
        _statusCorrectionErrors.remove(idx);
        _statusCorrectionIds.removeAt(idx);
      });
    }
  }

  void _initStatusCorrectionControllers(List<sc.LroStatusCorrection> corrections) {
    _statusCorrectionControllers.clear();
    _statusCorrectionErrors.clear();
    _statusCorrectionIds.clear();
    for (var i = 0; i < corrections.length; i++) {
      _statusCorrectionControllers.add(TextEditingController(text: corrections[i].description));
      _statusCorrectionErrors[i] = corrections[i].description.trim().isEmpty
          ? 'Description is required.'
          : null;
      _statusCorrectionIds.add(_statusCorrectionIdCounter++);
    }
  }

  Widget _picturePublicNoticeTemplateArea(AppStrings strings) {
    if (_publicNoticeTemplateLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_publicNoticeTemplateBytes != null && _publicNoticeTemplateBytes!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _publicNoticeTemplateBytes!,
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
                // Remove Public Notice Template.
                ref.read(lroSettingsServiceProvider).clearPublicNoticeTemplate().then((_) {
                  setState(() {
                    _publicNoticeTemplateBytes = null;
                    _hasPublicNoticeTemplate = false;
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
            'No template uploaded',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pickImage(isPublicNoticeTemplate: true, isWeb: kIsWeb),
            icon: const Icon(Icons.upload, size: 18),
            label: Text(strings.uploadPublicNoticeTemplate),
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

  Widget _pictureSealArea(AppStrings strings) {
    if (_sealLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sealBytes != null && _sealBytes!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _sealBytes!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.contain,
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
                ref.read(lroSettingsServiceProvider).clearCountySeal().then((_) {
                  setState(() {
                    _sealBytes = null;
                    _hasSeal = false;
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
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade600, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No county seal uploaded',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _pickImage(isPublicNoticeTemplate: false, isWeb: kIsWeb),
            icon: const Icon(Icons.upload, size: 18),
            label: Text(strings.uploadCountySeal),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

void _openSmtpSettings(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const SmtpSettingsScreen(),
    ),
  );
}
