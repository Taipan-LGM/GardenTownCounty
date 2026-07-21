import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/member.dart';
import '../../models/temporary_access_log.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';

final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

/// Banner when a Recording Secretary views a locked member.
class LockedMemberBanner extends StatelessWidget {
  const LockedMemberBanner({
    super.key,
    required this.member,
    this.lockedByName,
    this.onRequestAccess,
    this.onEnterCode,
  });

  final Member member;
  final String? lockedByName;
  final VoidCallback? onRequestAccess;
  final VoidCallback? onEnterCode;

  @override
  Widget build(BuildContext context) {
    final lockedOn = member.lockedDate == null
        ? '—'
        : DateFormat('yyyy-MM-dd').format(member.lockedDate!.toLocal());
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔑 TEMPORARY ACCESS REQUIRED',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This member is locked. To make changes, please enter the '
              '5-digit code provided by the Administrator.',
            ),
            const SizedBox(height: 4),
            Text(
              'Locked on: $lockedOn by: ${lockedByName ?? member.lockedBy ?? '—'}',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (onEnterCode != null)
                  FilledButton.tonalIcon(
                    onPressed: onEnterCode,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Enter Temporary Access Code'),
                  ),
                if (onRequestAccess != null)
                  OutlinedButton(
                    onPressed: onRequestAccess,
                    child: const Text('Request Access from Admin'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin banner for locked members (still editable).
class AdminLockedBanner extends StatelessWidget {
  const AdminLockedBanner({
    super.key,
    required this.member,
    this.lockedByName,
    this.onUnlock,
    this.onGrantAccess,
    this.onRevokeAccess,
    this.recentLogs,
  });

  final Member member;
  final String? lockedByName;
  final VoidCallback? onUnlock;
  final VoidCallback? onGrantAccess;
  final VoidCallback? onRevokeAccess;
  final List<TemporaryAccessLog>? recentLogs;

  @override
  Widget build(BuildContext context) {
    final lockedOn = member.lockedDate == null
        ? '—'
        : DateFormat('yyyy-MM-dd').format(member.lockedDate!.toLocal());
    return Card(
      color: AppTheme.forestGreen.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔑 TEMPORARY ACCESS MANAGEMENT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.forestGreen,
              ),
            ),
            const Text(
              'This member is locked. You have full edit access as Admin.',
            ),
            Text('Locked by: ${lockedByName ?? member.lockedBy ?? '—'} on $lockedOn'),
            Text(
              'Current Status: ${member.hasActiveTemporaryAccess ? 'Active code ${member.temporaryAccessCode}' : 'No active temporary access'}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onUnlock != null)
                  FilledButton.icon(
                    onPressed: onUnlock,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock Member'),
                  ),
                if (onGrantAccess != null)
                  FilledButton.tonalIcon(
                    onPressed: onGrantAccess,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Grant Temporary Access'),
                  ),
                if (onRevokeAccess != null && member.hasActiveTemporaryAccess)
                  OutlinedButton.icon(
                    onPressed: onRevokeAccess,
                    icon: const Icon(Icons.block),
                    label: const Text('Revoke Access'),
                  ),
              ],
            ),
            if (recentLogs != null && recentLogs!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Recent Access History:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Divider(height: 12),
              ...recentLogs!.take(5).map((log) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_dateFmt.format(log.grantedAt.toLocal())}  '
                    'Code: ${log.accessCode}  '
                    'Granted to: ${log.secretaryName}  '
                    '(${log.computedStatus})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner when temporary access is active for the current secretary.
class TemporaryAccessActiveBanner extends StatefulWidget {
  const TemporaryAccessActiveBanner({
    super.key,
    required this.member,
    this.grantedByName,
    this.onRevoke,
  });

  final Member member;
  final String? grantedByName;
  final VoidCallback? onRevoke;

  @override
  State<TemporaryAccessActiveBanner> createState() =>
      _TemporaryAccessActiveBannerState();
}

class _TemporaryAccessActiveBannerState
    extends State<TemporaryAccessActiveBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final expiry = widget.member.temporaryAccessExpiry;
    if (!mounted) return;
    setState(() {
      _remaining = expiry == null
          ? Duration.zero
          : expiry.difference(DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiry = widget.member.temporaryAccessExpiry;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏰ TEMPORARY ACCESS ACTIVE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              'You have temporary edit access until '
              '${expiry == null ? '—' : _dateFmt.format(expiry.toLocal())}.',
            ),
            Text(
              'Time remaining: ${_formatRemaining(_remaining)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Code: ${widget.member.temporaryAccessCode ?? '—'}'),
            Text(
              'Granted by: ${widget.grantedByName ?? widget.member.temporaryAccessGrantedBy ?? 'Admin'}',
            ),
            if (widget.onRevoke != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onRevoke,
                child: const Text('Revoke Access'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatRemaining(Duration d) {
    if (d.isNegative) return 'Expired';
    if (d.inDays >= 1) {
      return '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m';
    }
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
    }
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}

Future<void> showGrantTemporaryAccessDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Member member,
}) async {
  final users = await ref.read(authServiceProvider).listOperators();
  final secretaries =
      users.where((u) => u.isSecretary && !u.deleted).toList();
  if (!context.mounted) return;
  if (secretaries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No Recording Secretaries available.')),
    );
    return;
  }

  String? secretaryId = secretaries.first.id;
  var durationLabel = '1h';
  final reasonCtrl = TextEditingController();

  final granted = await showDialog<({String code, DateTime expiry, AppUser sec})>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('🔑 Grant Temporary Access'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Member: ${member.fullName} (SA ID: ${member.saId})'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: secretaryId,
                    decoration: const InputDecoration(
                      labelText: 'Select Recording Secretary',
                      border: OutlineInputBorder(),
                    ),
                    items: secretaries
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => secretaryId = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Access Duration:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '1h', label: Text('1 Hour')),
                      ButtonSegment(value: '24h', label: Text('24 Hours')),
                      ButtonSegment(value: '7d', label: Text('7 Days')),
                    ],
                    selected: {durationLabel},
                    onSelectionChanged: (sel) =>
                        setLocal(() => durationLabel = sel.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Access *',
                      hintText: 'Why does the Secretary need access?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ A unique 5-digit code will be generated. Provide it to the Secretary separately.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final admin = ref.read(authUserProvider);
                  if (admin == null || secretaryId == null) return;
                  if (reasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Please provide a reason for access.'),
                      ),
                    );
                    return;
                  }
                  try {
                    final result =
                        await ref.read(temporaryAccessServiceProvider).grant(
                              member: member,
                              admin: admin,
                              secretaryId: secretaryId!,
                              duration: durationLabel,
                              reason: reasonCtrl.text.trim(),
                            );
                    final sec =
                        secretaries.firstWhere((s) => s.id == secretaryId);
                    if (ctx.mounted) {
                      Navigator.pop(ctx, (
                        code: result.code,
                        expiry: result.expiresAt,
                        sec: sec,
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('🔑 Generate Code & Grant Access'),
              ),
            ],
          );
        },
      );
    },
  );

  reasonCtrl.dispose();
  if (granted == null || !context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final spaced = granted.code.split('').join(' ');
      return AlertDialog(
        title: const Text('✅ Temporary Access Granted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code: $spaced',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text('Valid Until: ${_dateFmt.format(granted.expiry.toLocal())}'),
            Text(
              'Granted To: ${granted.sec.displayName} (Recording Secretary)',
            ),
            const SizedBox(height: 8),
            Text('📋 Please provide this code to ${granted.sec.displayName}.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: granted.code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
            child: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri(
                scheme: 'mailto',
                queryParameters: {
                  'subject': 'Garden Town County — Temporary Access Code',
                  'body':
                      'Temporary access code for ${member.fullName}: ${granted.code}\n'
                      'Valid until: ${_dateFmt.format(granted.expiry.toLocal())}',
                },
              );
              await launchUrl(uri);
            },
            child: const Text('Send via Email'),
          ),
          TextButton(
            onPressed: () async {
              final text = Uri.encodeComponent(
                'Garden Town County temporary access for ${member.fullName}: ${granted.code}',
              );
              await launchUrl(Uri.parse('https://wa.me/?text=$text'));
            },
            child: const Text('Send via WhatsApp'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
  ref.invalidate(membersProvider);
  ref.invalidate(lockedMembersProvider);
  ref.invalidate(temporaryAccessLogsProvider);
}

Future<bool> showEnterTemporaryAccessCodeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Member member,
  required AuthUser secretary,
}) async {
  final codeCtrl = TextEditingController();
  var attempts = 0;
  String? errorMessage;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('🔑 Temporary Access Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This member is locked. Enter the 5-digit temporary access '
                  'code provided by the Administrator.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  maxLength: 5,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Enter 5-digit code',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.vpn_key),
                    counterText: '',
                    errorText: errorMessage,
                  ),
                  onChanged: (_) => setLocal(() => errorMessage = null),
                ),
                if (attempts >= 3)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ Multiple failed attempts. Please contact the Administrator.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: attempts >= 3
                    ? null
                    : () async {
                        final result = await ref
                            .read(temporaryAccessServiceProvider)
                            .verify(
                              member: member,
                              secretary: secretary,
                              code: codeCtrl.text,
                            );
                        if (!ctx.mounted) return;
                        if (result.success) {
                          Navigator.pop(ctx, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        } else {
                          setLocal(() {
                            attempts++;
                            errorMessage = result.message;
                          });
                        }
                      },
                child: const Text('🔓 Verify Code'),
              ),
            ],
          );
        },
      );
    },
  );
  codeCtrl.dispose();
  return ok == true;
}
