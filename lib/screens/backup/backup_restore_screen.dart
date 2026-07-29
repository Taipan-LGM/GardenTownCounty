import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../providers/providers.dart';
import '../../widgets/cancel_button.dart';

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
  int _totalBackups = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBackupCount());
  }

  Future<void> _refreshBackupCount() async {
    if (kIsWeb) {
      if (mounted) setState(() => _totalBackups = 0);
      return;
    }
    try {
      final files = await ref.read(backupServiceProvider).listBackups();
      if (mounted) setState(() => _totalBackups = files.length);
    } catch (_) {
      if (mounted) setState(() => _totalBackups = 0);
    }
  }

  Future<void> _enableLocalBackup() async {
    final controller = TextEditingController(
      text: kIsWeb ? 'Web browser' : '',
    );
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<({String name, String password})>(
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
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Backup password (min 8 chars)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm backup password',
                ),
              ),
            ],
          ),
          actions: [
            CancelButton(
              onPressed: () => Navigator.pop(context),
              text: 'Cancel',
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                final password = passwordController.text.trim();
                final confirm = confirmController.text.trim();
                if (name.isEmpty) return;
                if (password.length < 8) return;
                if (password != confirm) return;
                Navigator.pop(context, (name: name, password: password));
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    passwordController.dispose();
    confirmController.dispose();
    if (result == null) return;

    try {
      await ref.read(backupAuthServiceProvider).enableLocalBackup(
            result.name,
            backupPassword: result.password,
          );
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

  Future<String?> _promptBackupPassword({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Backup password'),
                onSubmitted: (value) => Navigator.pop(context, value.trim()),
              ),
            ],
          ),
          actions: [
            CancelButton(
              onPressed: () => Navigator.pop(context),
              text: 'Cancel',
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (password == null || password.isEmpty) return null;
    return password;
  }

  Future<String?> _ensureBackupPassword({bool forRestore = false}) async {
    final auth = ref.read(backupAuthServiceProvider);
    final existing = await auth.loadBackupPassword();
    if (existing != null && existing.length >= 8 && !forRestore) {
      return existing;
    }
    final entered = await _promptBackupPassword(
      title: forRestore ? 'Restore password' : 'Backup password',
      message: forRestore
          ? 'Enter the password used when this backup was created.'
          : 'Enter a password to encrypt this backup (min 8 characters).',
    );
    if (entered == null) return null;
    if (!forRestore && entered.length >= 8) {
      await auth.saveBackupPassword(entered);
    }
    return entered;
  }

  /// Web auto-authorizes; desktop prompts if needed.
  Future<bool> _ensureAuthorized() async {
    final auth = await ref.read(backupAuthServiceProvider).checkAuthorization();
    if (auth.authorized) return true;

    if (kIsWeb) {
      final hasPw =
          await ref.read(backupAuthServiceProvider).hasBackupPassword();
      if (!hasPw) {
        await _enableLocalBackup();
      } else {
        await ref
            .read(backupAuthServiceProvider)
            .enableLocalBackup('Web browser');
      }
      ref.invalidate(backupAuthProvider);
      return (await ref.read(backupAuthServiceProvider).checkAuthorization())
          .authorized;
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

    final password = await _ensureBackupPassword();
    if (password == null) return;

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
            password: password,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      ref.invalidate(lastBackupAtProvider);
      await _refreshBackupCount();
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
    if (!mounted) return;

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
          CancelButton(
            onPressed: () => Navigator.pop(context, false),
            text: 'Cancel',
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || cloudOk != true) return;

    final restorePassword = await _ensureBackupPassword(forRestore: true);
    if (restorePassword == null) return;

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
              password: restorePassword,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
      } else if (file.path != null && !kIsWeb) {
        await ref.read(backupServiceProvider).restoreFromFile(
              file.path!,
              password: restorePassword,
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

  Future<void> _viewBackups() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'View Backups lists local .gtb files on desktop/mobile only. '
            'On web, use your Downloads folder.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final files = await ref.read(backupServiceProvider).listBackups();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'View Backups',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 480,
            child: files.isEmpty
                ? Text(
                    'No .gtb backup files found in the GardenTown Backups folders.',
                    style: TextStyle(color: Colors.grey.shade300),
                  )
                : SizedBox(
                    height: 360,
                    child: ListView.separated(
                      itemCount: files.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: Colors.grey.shade700),
                      itemBuilder: (context, i) {
                        final f = files[i];
                        final when = DateFormat('yyyy-MM-dd HH:mm')
                            .format(f.modifiedAt.toLocal());
                        final kb = (f.bytes / 1024).toStringAsFixed(1);
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.archive,
                            color: Colors.white70,
                          ),
                          title: Text(
                            f.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '$when · $kb KB',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not list backups: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDeleteAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ConfirmDeleteAllDialog(),
    );
    if (!mounted || confirmed != true) return;
    await _deleteAllData();
  }

  Future<void> _deleteAllData() async {
    setState(() {
      _busy = true;
      _statusMessage = 'Deleting all data…';
      _progress = 0;
    });
    try {
      await ref.read(databaseServiceProvider).deleteAllData();
      if (!kIsWeb) {
        await ref.read(backupServiceProvider).deleteAllBackupFiles();
      }

      final admin = ref.read(authUserProvider);
      if (admin != null) {
        await ref.read(activityServiceProvider).record(
              userName: admin.displayName,
              action: 'delete_all_data',
              captureGps: false,
            );
      }

      ref.invalidate(membersProvider);
      ref.invalidate(appUsersProvider);
      ref.invalidate(activitiesProvider);
      ref.invalidate(lastBackupAtProvider);
      ref.invalidate(countyProfileProvider);
      ref.read(appRefreshTickProvider.notifier).state++;
      await _refreshBackupCount();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('All Data Deleted'),
            ],
          ),
          content: const Text(
            'All operational data has been permanently deleted. '
            'Admin and County Information were kept. '
            'The system is ready for new data.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting data: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  color: AppTheme.bodyText,
                ),
              ),
              const SizedBox(height: 12),
              _statusCard(
                lastLabel: lastLabel,
                totalBackups: _totalBackups,
                authorized: auth.authorized,
                deviceName: auth.deviceName,
              ),
              const SizedBox(height: 16),
              _actionsCard(strings: strings, authorized: auth.authorized),
              const SizedBox(height: 16),
              _dangerZoneCard(),
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

  Widget _statusCard({
    required String lastLabel,
    required int totalBackups,
    required bool authorized,
    String? deviceName,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade300),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last backup: $lastLabel',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                Text(
                  kIsWeb
                      ? 'Total backups: n/a (web downloads)'
                      : 'Total backups: $totalBackups',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
                if (kIsWeb)
                  Text(
                    'Web: Download saves a .gtb file; Restore opens a .gtb file.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                if (authorized)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Backup Authorized'
                      '${deviceName == null || deviceName.isEmpty ? '' : ': $deviceName'}',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard({
    required AppStrings strings,
    required bool authorized,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Backup Actions',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.save,
            label: 'Create Backup',
            description: 'Create a new encrypted .gtb backup of all data',
            backgroundColor: Colors.blue.shade700,
            textColor: Colors.black,
            onPressed: _busy ? null : () => _createBackup(external: !kIsWeb),
          ),
          const SizedBox(height: 8),
          _actionButton(
            icon: Icons.restore,
            label: 'Restore Backup',
            description: 'Restore data from a .gtb backup file',
            backgroundColor: Colors.amber.shade600,
            textColor: Colors.black,
            onPressed: _busy ? null : _restore,
          ),
          const SizedBox(height: 8),
          _actionButton(
            icon: Icons.folder_open,
            label: authorized
                ? (kIsWeb
                    ? 'Local Backup Authorized'
                    : 'Local Backup Enabled')
                : strings.enableLocalBackup,
            description: authorized
                ? 'This device is authorized for backups'
                : 'Authorize this PC/browser for local backups',
            backgroundColor: Colors.green.shade700,
            textColor: Colors.white,
            onPressed: (_busy || authorized) ? null : _enableLocalBackup,
          ),
          const SizedBox(height: 8),
          _actionButton(
            icon: Icons.list_alt,
            label: 'View Backups',
            description: 'View existing .gtb backup files',
            backgroundColor: Colors.grey.shade700,
            textColor: Colors.white,
            onPressed: _busy ? null : _viewBackups,
          ),
        ],
      ),
    );
  }

  Widget _dangerZoneCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade300),
              const SizedBox(width: 8),
              Text(
                'DANGER ZONE',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This will permanently delete ALL operational data from the system.',
            style: TextStyle(color: Colors.red.shade200, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.delete_forever,
            label: 'DELETE ALL',
            description: 'Permanently delete ALL data (Admin kept)',
            backgroundColor: Colors.red.shade700,
            textColor: Colors.white,
            onPressed: _busy ? null : _showDeleteAllDialog,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String description,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor == Colors.black
                        ? Colors.white
                        : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              disabledBackgroundColor: Colors.grey.shade700,
              disabledForegroundColor: Colors.grey.shade400,
              side: AppTheme.buttonWhiteBand,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(label == 'DELETE ALL' ? 'Delete All' : 'Go'),
          ),
        ],
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
        CancelButton(
          onPressed: () => Navigator.pop(context, false),
          text: 'Cancel',
        ),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Restore'),
        ),
      ],
    );
  }
}

class _ConfirmDeleteAllDialog extends StatefulWidget {
  const _ConfirmDeleteAllDialog();

  @override
  State<_ConfirmDeleteAllDialog> createState() =>
      _ConfirmDeleteAllDialogState();
}

class _ConfirmDeleteAllDialogState extends State<_ConfirmDeleteAllDialog> {
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
      backgroundColor: Colors.grey.shade900,
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.red.shade400, size: 28),
          const SizedBox(width: 8),
          Text(
            'DELETE ALL DATA!',
            style: TextStyle(
              color: Colors.red.shade300,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are about to permanently delete ALL operational data.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently delete:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...[
                    'All Members',
                    'All Cases (528, 928, LRO)',
                    'All Files & Uploads',
                    'All Reminders',
                    'All Users (except Admin)',
                    'All Remuneration Records',
                    'All Activities / Audit Logs',
                    'All Articles & Videos',
                    'All local Backup Files',
                  ].map(
                    (line) => Text(
                      '• $line',
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action CANNOT be undone!',
              style: TextStyle(
                color: Colors.red.shade300,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Type "CONFIRM" to proceed:',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type CONFIRM',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                errorText: _controller.text.isNotEmpty && !ok
                    ? 'Must type "CONFIRM" exactly'
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        CancelButton(
          onPressed: () => Navigator.pop(context, false),
          text: 'Cancel',
        ),
        ElevatedButton(
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ok ? Colors.red : Colors.grey.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm Delete All'),
        ),
      ],
    );
  }
}
