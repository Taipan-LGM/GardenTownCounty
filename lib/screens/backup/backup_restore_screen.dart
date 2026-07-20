import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../providers/providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;
  double _progress = 0;
  String? _statusMessage;

  Future<void> _enableLocalBackup() async {
    final controller = TextEditingController(
      text: kIsWeb ? 'Web browser' : '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(kIsWeb ? 'Authorize this browser' : 'Authorize this PC'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kIsWeb
                    ? 'Name this browser session for backups:'
                    : 'Enter a name for this authorized device (e.g., Office-PC-01):',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Device name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      await ref.read(backupAuthServiceProvider).enableLocalBackup(name);
      ref.invalidate(backupAuthProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup authorized.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  /// Web auto-authorizes; desktop prompts if needed.
  Future<bool> _ensureAuthorized() async {
    final auth = await ref.read(backupAuthServiceProvider).checkAuthorization();
    if (auth.authorized) return true;

    if (kIsWeb) {
      await ref
          .read(backupAuthServiceProvider)
          .enableLocalBackup('Web browser');
      ref.invalidate(backupAuthProvider);
      return true;
    }

    await _enableLocalBackup();
    final after = await ref.read(backupAuthServiceProvider).checkAuthorization();
    return after.authorized;
  }

  Future<void> _createBackup({required bool external}) async {
    final ok = await _ensureAuthorized();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup authorization required.')),
        );
      }
      return;
    }

    String? selectedDir;
    if (!kIsWeb && external) {
      selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select USB / network / external folder for backup',
      );
      if (selectedDir == null) return;
    }

    setState(() {
      _busy = true;
      _progress = 0;
      _statusMessage = kIsWeb ? 'Preparing download…' : 'Creating backup…';
    });
    try {
      final result = await ref.read(backupServiceProvider).createBackup(
            targetDirectoryPath: selectedDir,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      ref.invalidate(lastBackupAtProvider);
      if (!mounted) return;
      setState(() => _statusMessage = 'Backup saved');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup complete'),
          content: Text(
            kIsWeb
                ? 'Encrypted backup saved / downloaded as a .gtb file.'
                : result.filePath,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _restore() async {
    final ok = await _ensureAuthorized();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup authorization required.')),
        );
      }
      return;
    }

    final pick = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      dialogTitle: 'Select Garden Town Backup (.gtb)',
    );
    if (pick == null || pick.files.isEmpty) return;

    final file = pick.files.single;
    if (!file.name.toLowerCase().endsWith('.gtb')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a .gtb backup file.')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ConfirmRestoreDialog(),
    );
    if (!mounted || confirmed != true) return;

    final cloudOk = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overwrite cloud?'),
        content: const Text(
          'This will overwrite ALL cloud data with this backup. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || cloudOk != true) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _statusMessage = 'Restoring…';
    });
    try {
      final bytes = file.bytes;
      if (bytes != null) {
        await ref.read(backupServiceProvider).restoreFromBytes(
              bytes,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
      } else if (file.path != null && !kIsWeb) {
        await ref.read(backupServiceProvider).restoreFromFile(
              file.path!,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
      } else {
        throw Exception('Could not read backup file.');
      }

      setState(() => _statusMessage = 'Pushing restored data to cloud…');
      await ref.read(syncEngineProvider).forcePushAllAfterRestore();
      ref.invalidate(membersProvider);
      ref.invalidate(activitiesProvider);
      ref.invalidate(appUsersProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Restore Complete'),
          content: const Text(
            'Data restored and synced. The app will return to Home.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      ref.read(appSectionProvider.notifier).state = AppSection.home;
      ref.read(appRefreshTickProvider.notifier).state++;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(backupAuthProvider);
    final lastAsync = ref.watch(lastBackupAtProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final strings = AppStrings(ref.watch(appLanguageProvider));

    if (!isAdmin) {
      return const Center(child: Text('Admin access required.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: authAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (auth) {
          final lastLabel = lastAsync.maybeWhen(
            data: (dt) => dt == null
                ? 'Never'
                : DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal()),
            orElse: () => '…',
          );

          return ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Text(
                strings.backupCenter,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text('Last Backup: $lastLabel'),
              if (kIsWeb) ...[
                const SizedBox(height: 8),
                const Text(
                  'Web: Download saves a .gtb file; Restore opens a .gtb file.',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    _busy ? null : () => _createBackup(external: !kIsWeb),
                icon: const Icon(Icons.download),
                label: const Text('Download Backup (.gtb)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.computer,
                title: strings.localBackup,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      auth.authorized
                          ? 'Authorized: ${auth.deviceName ?? (kIsWeb ? 'This browser' : 'This PC')}'
                          : kIsWeb
                              ? 'Optional: name this browser, or tap Download (auto-authorizes).'
                              : 'Authorize this PC once, then backup / restore unlock.',
                    ),
                    const SizedBox(height: 12),
                    if (!auth.authorized)
                      FilledButton.icon(
                        onPressed: _busy ? null : _enableLocalBackup,
                        icon: const Icon(Icons.key),
                        label: Text(
                          kIsWeb
                              ? 'Enable Backup in this browser'
                              : strings.enableLocalBackup,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.forestGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      )
                    else if (!kIsWeb)
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _createBackup(external: false),
                        icon: const Icon(Icons.folder_special),
                        label: const Text(
                          'Backup to Local GardenTown folder',
                        ),
                      ),
                  ],
                ),
              ),
              _sectionCard(
                icon: Icons.usb,
                title: strings.externalBackup,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      kIsWeb
                          ? 'Download an encrypted .gtb backup to your device.'
                          : 'Save an encrypted .gtb to USB / network / external disk.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _createBackup(external: !kIsWeb),
                      icon: const Icon(Icons.save_alt),
                      label: Text(
                        kIsWeb
                            ? 'Download Backup (.gtb)'
                            : strings.createBackup,
                      ),
                    ),
                  ],
                ),
              ),
              _sectionCard(
                icon: Icons.restore,
                title: strings.restore,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pick a .gtb backup file and restore it. '
                      "Type CONFIRM when prompted.",
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.restore),
                      label: Text(strings.restoreFromBackup),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brick,
                        side: const BorderSide(color: AppTheme.brick),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                ),
                const SizedBox(height: 8),
                Text(_statusMessage ?? 'Working…'),
              ],
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.forestGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ConfirmRestoreDialog extends StatefulWidget {
  const _ConfirmRestoreDialog();

  @override
  State<_ConfirmRestoreDialog> createState() => _ConfirmRestoreDialogState();
}

class _ConfirmRestoreDialogState extends State<_ConfirmRestoreDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _controller.text.trim() == 'CONFIRM';
    return AlertDialog(
      title: const Text('WARNING'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This will DELETE all current data and replace it with the backup. '
            "Type 'CONFIRM' to proceed.",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Type CONFIRM'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Restore'),
        ),
      ],
    );
  }
}
