import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/member.dart';
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
              '⚠️ 🔒 MEMBER LOCKED',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This member has completed all requirements and is locked.\n'
              'Only the System Administrator can make changes.',
            ),
            const SizedBox(height: 4),
            Text(
              'Locked on: $lockedOn by: ${lockedByName ?? member.lockedBy ?? '—'}',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
            const Text('Contact Admin if changes are needed.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (onEnterCode != null)
                  FilledButton.tonalIcon(
                    onPressed: onEnterCode,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Enter Access Code'),
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
  });

  final Member member;
  final String? lockedByName;
  final VoidCallback? onUnlock;
  final VoidCallback? onGrantAccess;
  final VoidCallback? onRevokeAccess;

  @override
  Widget build(BuildContext context) {
    final lockedOn = member.lockedDate == null
        ? '—'
        : DateFormat('yyyy-MM-dd').format(member.lockedDate!.toLocal());
    final temp = member.hasActiveTemporaryAccess
        ? 'Active (${member.temporaryAccessCode} — expires ${_dateFmt.format(member.temporaryAccessExpiry!.toLocal())})'
        : 'None';
    return Card(
      color: AppTheme.forestGreen.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔓 LOCKED MEMBER',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.forestGreen,
              ),
            ),
            const Text(
              'This member is locked. You have full edit access as Admin.',
            ),
            Text('Locked by: ${lockedByName ?? member.lockedBy ?? '—'} on $lockedOn'),
            Text('Temporary Access: $temp'),
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
          ],
        ),
      ),
    );
  }
}

/// Banner when temporary access is active for the current secretary.
class TemporaryAccessActiveBanner extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final expiry = member.temporaryAccessExpiry;
    final remaining = expiry == null
        ? '—'
        : _formatRemaining(expiry.difference(DateTime.now().toUtc()));
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ TEMPORARY ACCESS ACTIVE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              'You have temporary edit access until '
              '${expiry == null ? '—' : _dateFmt.format(expiry.toLocal())}.',
            ),
            Text('Time remaining: $remaining'),
            Text('Code: ${member.temporaryAccessCode ?? '—'}'),
            Text('Granted by: ${grantedByName ?? member.temporaryAccessGrantedBy ?? 'Admin'}'),
            if (onRevoke != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onRevoke,
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
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes} minutes';
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
  var duration = const Duration(hours: 1);
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
                  DropdownButtonFormField<Duration>(
                    initialValue: duration,
                    decoration: const InputDecoration(
                      labelText: 'Access Duration',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: Duration(hours: 1),
                        child: Text('1 Hour'),
                      ),
                      DropdownMenuItem(
                        value: Duration(hours: 24),
                        child: Text('24 Hours'),
                      ),
                      DropdownMenuItem(
                        value: Duration(days: 7),
                        child: Text('7 Days'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => duration = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Access',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ A 5-digit code will be generated. Provide it to the Secretary separately.',
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
                  try {
                    final result =
                        await ref.read(temporaryAccessServiceProvider).grant(
                              member: member,
                              admin: admin,
                              secretaryId: secretaryId!,
                              duration: duration,
                              reason: reasonCtrl.text.trim().isEmpty
                                  ? null
                                  : reasonCtrl.text.trim(),
                            );
                    final sec = secretaries
                        .firstWhere((s) => s.id == secretaryId);
                    if (ctx.mounted) {
                      Navigator.pop(ctx, (
                        code: result.code,
                        expiry: result.member.temporaryAccessExpiry!,
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
                child: const Text('Generate Code & Grant Access'),
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
}

Future<bool> showEnterTemporaryAccessCodeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Member member,
  required AuthUser secretary,
}) async {
  final codeCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('🔑 Temporary Access Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
              decoration: const InputDecoration(
                labelText: 'Enter 5-digit code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (member.temporaryAccessExpiry != null)
              Text(
                '⏰ Code expires: ${_dateFmt.format(member.temporaryAccessExpiry!.toLocal())}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(temporaryAccessServiceProvider).verify(
                      member: member,
                      secretary: secretary,
                      code: codeCtrl.text,
                    );
                if (ctx.mounted) Navigator.pop(ctx, true);
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
            child: const Text('Verify Code'),
          ),
        ],
      );
    },
  );
  codeCtrl.dispose();
  return ok == true;
}
