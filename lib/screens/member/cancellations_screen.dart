import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../services/cancellation_service.dart';

/// Admin dashboard: soft-cancelled memberships + reinstate.
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    if (user == null || !user.isAdmin) {
      return const Center(child: Text('Admin access required.'));
    }

    final cancelledAsync = ref.watch(cancelledMembersProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: cancelledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
        data: (all) {
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
                    onPressed: () =>
                        ref.invalidate(cancelledMembersProvider),
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
                          return _CancelledCard(
                            member: m,
                            dateLabel: m.cancellationDate == null
                                ? '—'
                                : dateFmt.format(m.cancellationDate!.toLocal()),
                            onReinstate: () => _reinstate(m),
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
          'Reinstate ${member.fullName}? They return to active membership.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Reinstate'),
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
    required this.onReinstate,
    required this.onView,
  });

  final Member member;
  final String dateLabel;
  final VoidCallback onReinstate;
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
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onReinstate,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reinstate'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
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
