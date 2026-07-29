import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../services/cancellation_service.dart';
import '../../widgets/standard_buttons.dart';
import 'member_files_dialog.dart';

/// Admin dashboard: soft-cancelled memberships + reinstate + files.
///
/// // NEW ADDITION - replaces Locked Members drawer entry for cancellations.
class CancellationsScreen extends ConsumerStatefulWidget {
  const CancellationsScreen({super.key});

  @override
  ConsumerState<CancellationsScreen> createState() =>
      _CancellationsScreenState();
}

class _CancellationsScreenState extends ConsumerState<CancellationsScreen> {
  String _query = '';
  final Map<String, int> _fileCounts = {};

  Future<void> _loadFileCounts(List<Member> members) async {
    final db = ref.read(databaseServiceProvider);
    final next = <String, int>{};
    for (final m in members) {
      final files = await db.getFilesForMember(m.id);
      next[m.id] = files.length;
    }
    if (!mounted) return;
    setState(() {
      _fileCounts
        ..clear()
        ..addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    if (user == null || !user.isAdmin) {
      final strings = ref.watch(appStringsProvider);
      return Center(child: Text(strings.adminAccessRequired));
    }

    final cancelledAsync = ref.watch(cancelledMembersProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: cancelledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
        data: (all) {
          // Kick file-count load when list identity changes.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final ids = all.map((m) => m.id).join('|');
            final known = _fileCounts.keys.join('|');
            if (ids != known) {
              _loadFileCounts(all);
            }
          });

          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all.where((m) {
                  final hay =
                      '${m.memberName} ${m.surname} ${m.saId}'.toLowerCase();
                  return hay.contains(q);
                }).toList();

          final now = DateTime.now();
          final thisMonth = all.where((m) {
            final d = m.cancellationDate;
            return d != null && d.year == now.year && d.month == now.month;
          }).length;
          final lastMonthDate = DateTime(now.year, now.month - 1, 1);
          final lastMonth = all.where((m) {
            final d = m.cancellationDate;
            return d != null &&
                d.year == lastMonthDate.year &&
                d.month == lastMonthDate.month;
          }).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cancellations',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.bodyText,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.invalidate(cancelledMembersProvider);
                      setState(() => _fileCounts.clear());
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    label: 'Total Cancelled',
                    value: '${all.length}',
                    color: Colors.red,
                  ),
                  _StatCard(
                    label: 'This Month',
                    value: '$thisMonth',
                    color: Colors.orange,
                  ),
                  _StatCard(
                    label: 'Last Month',
                    value: '$lastMonth',
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search Cancelled Members…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty
                              ? 'No Cancelled Members'
                              : 'No matches',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          final fileCount = _fileCounts[m.id] ?? 0;
                          return _CancelledCard(
                            member: m,
                            dateLabel: m.cancellationDate == null
                                ? '—'
                                : dateFmt.format(m.cancellationDate!.toLocal()),
                            fileCount: fileCount,
                            onReinstate: () => _reinstate(m),
                            onViewFiles: () =>
                                showMemberFilesDialog(context, ref, m),
                            onView: () {
                              ref
                                  .read(selectedMemberIdProvider.notifier)
                                  .state = m.id;
                              ref
                                  .read(appSectionProvider.notifier)
                                  .state = AppSection.memberInfo;
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _reinstate(Member member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reinstate Member?'),
        content: Text(
          'Reinstate ${member.fullName}? All data and files remain available.',
        ),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(ctx, false),
            text: 'Cancel',
          ),
          ActionButton(
            onPressed: () => Navigator.pop(ctx, true),
            text: 'Yes, Reinstate',
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final admin = ref.read(authUserProvider);
    if (admin == null) return;
    try {
      await CancellationService(
        ref.read(databaseServiceProvider),
        ref.read(activityServiceProvider),
      ).reinstateMembership(memberId: member.id, admin: admin);
      ref.invalidate(cancelledMembersProvider);
      ref.invalidate(membersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.fullName} reinstated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({
    required this.member,
    required this.dateLabel,
    required this.fileCount,
    required this.onReinstate,
    required this.onViewFiles,
    required this.onView,
  });

  final Member member;
  final String dateLabel;
  final int fileCount;
  final VoidCallback onReinstate;
  final VoidCallback onViewFiles;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('SA ID: ${member.saId}'),
                  Text(
                    'Cancelled: $dateLabel',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                  if ((member.cancellationReason ?? '').isNotEmpty)
                    Text(
                      'Reason: ${member.cancellationReason}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    '$fileCount file${fileCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ActionButton(
              onPressed: onReinstate,
              text: 'Reinstate',
              icon: Icons.refresh,
              height: 40,
            ),
            IconButton(
              tooltip: 'View Files ($fileCount)',
              onPressed: onViewFiles,
              icon: const Icon(Icons.attach_file, color: Colors.amber),
            ),
            IconButton(
              tooltip: 'View Member',
              onPressed: onView,
              icon: const Icon(Icons.visibility),
            ),
          ],
        ),
      ),
    );
  }
}
