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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Authorize this PC'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter a name for this authorized device (e.g., Office-PC-01):',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Device name',
                ),
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Authorized'),
          content: const Text(
            'This PC is now authorized for Local Backups. '
            'You can also back up to USB or network drives below.',
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _createBackup({required bool external}) async {
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
                ? 'Encrypted backup downloaded as a .gtb file.'
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
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gtb'],
      withData: kIsWeb,
      dialogTitle: 'Select Garden Town Backup (.gtb)',
    );
    if (pick == null || pick.files.isEmpty) return;

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
      final file = pick.files.single;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception('Could not read backup file bytes.');
        }
        await ref.read(backupServiceProvider).restoreFromBytes(
              bytes,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
      } else {
        final path = file.path;
        if (path == null) {
          throw Exception('Could not read backup file path.');
        }
        await ref.read(backupServiceProvider).restoreFromFile(
              path,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
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
            'Data restored and synced. The app will return to Home. '
            'Restart the app if anything looks stale.',
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
          final canRun = auth.authorized;
          final webHint = kIsWeb
              ? 'Web: backups download as .gtb files; restore by picking a .gtb.'
              : null;

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
              if (webHint != null) ...[
                const SizedBox(height: 8),
                Text(webHint),
              ],
              const SizedBox(height: 16),

              // 1) Local authorization
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
                              ? 'Authorize this browser once to unlock Backup & Restore.'
                              : 'Authorize this PC once. Then Local, USB, and network backups unlock.',
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
                    else
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _createBackup(external: false),
                        icon: Icon(
                          kIsWeb ? Icons.download : Icons.folder_special,
                        ),
                        label: Text(
                          kIsWeb
                              ? 'Download Local Backup (.gtb)'
                              : 'Backup to Local GardenTown folder',
                        ),
                      ),
                  ],
                ),
              ),

              // 2) External / network
              _sectionCard(
                icon: Icons.usb,
                title: strings.externalBackup,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      kIsWeb
                          ? 'Download an encrypted .gtb backup (same as local on web).'
                          : 'Save an encrypted .gtb backup to a USB stick, '
                              'external disk, or mapped network drive. '
                              'You choose the folder when you tap the button.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || !canRun
                          ? null
                          : () => _createBackup(external: !kIsWeb),
                      icon: const Icon(Icons.save_alt),
                      label: Text(
                        kIsWeb
                            ? 'Download Backup (.gtb)'
                            : strings.createBackup,
                      ),
                    ),
                    if (!auth.authorized)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Enable backup authorization above first.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),

              // 3) Restore
              _sectionCard(
                icon: Icons.restore,
                title: strings.restore,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pick a .gtb backup file and restore it. '
                      "Type 'CONFIRM' when prompted.",
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy || !canRun ? null : _restore,
                      icon: const Icon(Icons.restore),
                      label: Text(strings.restoreFromBackup),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brick,
                        side: const BorderSide(color: AppTheme.brick),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    if (!auth.authorized)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Enable backup authorization above first.',
                          style: Theme.of(context).textTheme.bodySmall,
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
            decoration: const InputDecoration(
              labelText: 'Type CONFIRM',
            ),
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
