import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../widgets/member_lock_banners.dart';

/// Admin dashboard: locked members + lock statistics.
class LockedMembersScreen extends ConsumerWidget {
  const LockedMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    if (user == null || !user.isAdmin) {
      return const Center(child: Text('Admin access required.'));
    }

    final membersAsync = ref.watch(membersProvider);
    final lockedAsync = ref.watch(lockedMembersProvider);
    final usersAsync = ref.watch(appUsersProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
        data: (all) {
          final locked = lockedAsync.valueOrNull ??
              all.where((m) => m.isLocked).toList();
          final unlocked = all.where((m) => !m.isLocked).length;
          final tempActive =
              locked.where((m) => m.hasActiveTemporaryAccess).length;
          final nameOf = <String, String>{};
          for (final u in usersAsync.valueOrNull ?? const []) {
            nameOf[u.id] = u.displayName;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Locked Members',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bodyText,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: 'Total Members', value: '${all.length}'),
                  _StatCard(label: 'Locked', value: '${locked.length}'),
                  _StatCard(label: 'Unlocked', value: '$unlocked'),
                  _StatCard(label: 'Temp Access', value: '$tempActive'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 3,
                child: Card(
                  child: locked.isEmpty
                      ? const Center(child: Text('No locked members yet.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AppTheme.forestGreen.withValues(alpha: 0.12),
                              ),
                              columns: const [
                                DataColumn(label: Text('#')),
                                DataColumn(label: Text('Member Name')),
                                DataColumn(label: Text('SA ID')),
                                DataColumn(label: Text('Locked By')),
                                DataColumn(label: Text('Locked Date')),
                                DataColumn(label: Text('Temporary Access')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: [
                                for (var i = 0; i < locked.length; i++)
                                  _row(
                                    context,
                                    ref,
                                    index: i + 1,
                                    member: locked[i],
                                    lockedByName:
                                        nameOf[locked[i].lockedBy ?? ''] ??
                                            locked[i].lockedBy ??
                                            '—',
                                    dateFmt: dateFmt,
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Temporary Access Management',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bodyText,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: _TempAccessPanel(members: all),
              ),
            ],
          );
        },
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required Member member,
    required String lockedByName,
    required DateFormat dateFmt,
  }) {
    final temp = member.hasActiveTemporaryAccess
        ? '🟢 Active (${member.temporaryAccessCode})'
        : '🔴 None';
    return DataRow(
      cells: [
        DataCell(Text('$index')),
        DataCell(Text(member.fullName)),
        DataCell(Text(member.saId)),
        DataCell(Text(lockedByName)),
        DataCell(
          Text(
            member.lockedDate == null
                ? '—'
                : dateFmt.format(member.lockedDate!.toLocal()),
          ),
        ),
        DataCell(Text(temp)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'View Member',
                icon: const Icon(Icons.visibility),
                onPressed: () {
                  ref.read(selectedMemberIdProvider.notifier).state =
                      member.id;
                  ref.read(appSectionProvider.notifier).state =
                      AppSection.memberInfo;
                },
              ),
              IconButton(
                tooltip: 'Unlock Member',
                icon: const Icon(Icons.lock_open),
                onPressed: () async {
                  final admin = ref.read(authUserProvider);
                  if (admin == null) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Unlock Member'),
                      content: Text(
                        'Unlock ${member.fullName}? Recording Secretaries will be able to edit again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Unlock'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await ref.read(memberLockServiceProvider).unlock(
                        member: member,
                        actor: admin,
                      );
                  ref.invalidate(membersProvider);
                  ref.invalidate(lockedMembersProvider);
                },
              ),
              IconButton(
                tooltip: 'Grant Temporary Access',
                icon: const Icon(Icons.vpn_key),
                onPressed: () async {
                  await showGrantTemporaryAccessDialog(
                    context: context,
                    ref: ref,
                    member: member,
                  );
                  ref.invalidate(lockedMembersProvider);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        color: AppTheme.forestGreen.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bodyText,
                ),
              ),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _TempAccessPanel extends ConsumerWidget {
  const _TempAccessPanel({required this.members});

  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(temporaryAccessLogsProvider);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final memberName = {
      for (final m in members) m.id: m.fullName,
    };

    return Card(
      child: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
        data: (logs) {
          final active = logs.where((l) => l.computedStatus == 'active').length;
          final used = logs.where((l) => l.computedStatus == 'used').length;
          final expired =
              logs.where((l) => l.computedStatus == 'expired').length;
          final revoked =
              logs.where((l) => l.computedStatus == 'revoked').length;
          final recent = logs.take(40).toList();

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat('Active', active, Colors.green),
                    _MiniStat('Used', used, Colors.blue),
                    _MiniStat('Expired', expired, Colors.orange),
                    _MiniStat('Revoked', revoked, Colors.red),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(temporaryAccessLogsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: recent.isEmpty
                      ? const Center(
                          child: Text('No temporary access codes yet.'),
                        )
                      : ListView.builder(
                          itemCount: recent.length,
                          itemBuilder: (context, i) {
                            final log = recent[i];
                            final status = log.computedStatus;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                status == 'active'
                                    ? Icons.vpn_key
                                    : status == 'used'
                                        ? Icons.check_circle
                                        : status == 'revoked'
                                            ? Icons.block
                                            : Icons.timer_off,
                              ),
                              title: Text(
                                memberName[log.memberId] ?? log.memberId,
                              ),
                              subtitle: Text(
                                '${log.secretaryName} · Code ${log.accessCode} · '
                                '${log.duration} · Expires '
                                '${dateFmt.format(log.expiresAt.toLocal())} · '
                                '$status',
                              ),
                              trailing: status == 'active'
                                  ? TextButton(
                                      onPressed: () async {
                                        final member = members
                                            .where((m) => m.id == log.memberId)
                                            .cast<Member?>()
                                            .firstWhere(
                                              (m) => m != null,
                                              orElse: () => null,
                                            );
                                        final admin =
                                            ref.read(authUserProvider);
                                        if (member == null || admin == null) {
                                          return;
                                        }
                                        await ref
                                            .read(
                                              temporaryAccessServiceProvider,
                                            )
                                            .revoke(
                                              member: member,
                                              actor: admin,
                                              reason:
                                                  'Revoked from Locked Members dashboard',
                                            );
                                        ref.invalidate(
                                          temporaryAccessLogsProvider,
                                        );
                                        ref.invalidate(membersProvider);
                                        ref.invalidate(lockedMembersProvider);
                                      },
                                      child: const Text(
                                        'Revoke',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Text(
          '$count',
          style: TextStyle(color: color, fontSize: 11),
        ),
      ),
      label: Text(label),
    );
  }
}
