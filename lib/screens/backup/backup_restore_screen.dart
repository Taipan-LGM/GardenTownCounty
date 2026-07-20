import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
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
            '✅ This PC is now authorized for Local Backups. '
            'Please restart the app for changes to take effect.',
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

  Future<void> _createBackup() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _statusMessage = 'Creating backup…';
    });
    try {
      final result = await ref.read(backupServiceProvider).createBackup(
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
          content: Text(result.filePath),
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
      dialogTitle: 'Select Garden Town Backup (.gtb)',
    );
    if (pick == null || pick.files.isEmpty || pick.files.single.path == null) {
      return;
    }
    final path = pick.files.single.path!;

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
          '⚠️ This will overwrite ALL cloud data with this backup. Continue?',
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
      await ref.read(backupServiceProvider).restoreFromFile(
            path,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Backup & Restore Center',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                auth.authorized
                    ? 'Authorized device: ${auth.deviceName ?? 'This PC'}'
                    : 'This PC is not authorized for local backups yet.',
              ),
              const SizedBox(height: 16),
              if (!auth.authorized)
                FilledButton.icon(
                  onPressed: _busy ? null : _enableLocalBackup,
                  icon: const Icon(Icons.key),
                  label: const Text('Enable Local Backup on this PC'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.forestGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              if (auth.authorized) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Last Backup: $lastLabel'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busy ? null : _createBackup,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Create Backup Now'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _restore,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore from Backup'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                const SizedBox(height: 8),
                Text(_statusMessage ?? 'Working…'),
              ],
            ],
          );
        },
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
      title: const Text('⚠️ WARNING'),
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
              labelText: "Type CONFIRM",
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
