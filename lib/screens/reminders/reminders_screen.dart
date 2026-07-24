import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/reminder.dart';
import '../../providers/providers.dart';
import '../../widgets/form_dialog_title.dart';
import '../../widgets/reminders/reminder_rs_assignment_row.dart';

/// Onboarding reminder dashboard (steps 1–4 + 24h expiry).
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  int? _filterStep;

  Future<void> _reload() async {
    await ref.read(reminderServiceProvider).autoExpireReminders();
    ref.invalidate(activeOnboardingRemindersProvider);
    ref.invalidate(reminderStatsProvider);
    ref.invalidate(activeReminderCountProvider);
  }

  void _openMember(String memberId) {
    ref.read(selectedMemberIdProvider.notifier).state = memberId;
    ref.read(appSectionProvider.notifier).state = AppSection.memberInfo;
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return 'Expired';
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
    return 'Expiring soon';
  }

  Future<void> _showOptions(Reminder reminder) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Member'),
              onTap: () {
                Navigator.pop(ctx);
                _openMember(reminder.memberId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Mark as Completed'),
              onTap: () async {
                Navigator.pop(ctx);
                final user = ref.read(authUserProvider);
                await ref.read(reminderServiceProvider).completeReminder(
                      reminderId: reminder.id,
                      completedBy: user?.id ?? 'user',
                    );
                await _reload();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Reminder marked as completed'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Dismiss Reminder'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const FormDialogTitle(title: 'Dismiss Reminder?'),
                    titlePadding: formDialogTitlePadding,
                    content: Text(
                      'Dismiss reminder for ${reminder.displayName}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                final user = ref.read(authUserProvider);
                await ref.read(reminderServiceProvider).dismissReminder(
                      reminderId: reminder.id,
                      dismissedBy: user?.id ?? 'user',
                    );
                await _reload();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder dismissed'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(activeOnboardingRemindersProvider);
    final statsAsync = ref.watch(reminderStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppTheme.forestGreen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '⏰ Reminders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.labelText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  color: AppTheme.labelText,
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        statsAsync.when(
          loading: () => const SizedBox(height: 72),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Stats error: $e'),
          ),
          data: _buildStatsCards,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              _filterChip('All', null),
              _filterChip('Step 1', 1),
              _filterChip('Step 2', 2),
              _filterChip('Step 3', 3),
              _filterChip('Step 4', 4),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: remindersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (reminders) {
              final filtered = _filterStep == null
                  ? reminders
                  : reminders
                      .where((r) => r.stepNumber == _filterStep)
                      .toList();
              if (filtered.isEmpty) return _buildEmptyState();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _buildReminderCard(filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(ReminderStats stats) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _statCard('Total', stats.total, Colors.grey.shade700),
          const SizedBox(width: 8),
          _statCard('Step 1', stats.step1, ReminderStep.getColor(1)),
          const SizedBox(width: 8),
          _statCard('Step 2', stats.step2, ReminderStep.getColor(2)),
          const SizedBox(width: 8),
          _statCard('Step 3', stats.step3, ReminderStep.getColor(3)),
          const SizedBox(width: 8),
          _statCard('Step 4', stats.step4, ReminderStep.getColor(4)),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int? step) {
    final selected = _filterStep == step;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filterStep = step),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final step = reminder.stepNumber ?? 0;
    final color = ReminderStep.getColor(step);
    final icon = ReminderStep.getIcon(step);
    final remaining =
        reminder.timeRemaining ?? const Duration(hours: 24);
    final urgent = reminder.isUrgent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: urgent ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: urgent
              ? Border.all(color: Colors.red.shade300, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              onTap: () => _openMember(reminder.memberId),
              onLongPress: () => _showOptions(reminder),
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 18),
                    Text(
                      '${ReminderStep.getEmoji(step)} $step',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                reminder.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step $step: ${reminder.stepDescription ?? ReminderStep.getDescription(step)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'SA ID: ${reminder.saId ?? '—'} · '
                    '${_dateFormat.format(reminder.createdAt.toLocal())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          urgent ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTimeRemaining(remaining),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: urgent
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                  if (urgent) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ EXPIRING SOON',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // NEW ADDITION - RS assignment row (Delete block to revert)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ReminderRsAssignmentRow(
                reminder: reminder,
                onChanged: _reload,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'All Caught Up!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStep == null
                ? 'No active onboarding reminders.'
                : 'No reminders for Step $_filterStep.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
