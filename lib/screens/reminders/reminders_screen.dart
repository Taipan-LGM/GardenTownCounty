import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/reminder.dart';
import '../../providers/providers.dart';
import '../../widgets/form_dialog_title.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<void> _showAddDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var priority = 'Medium';
    var date = DateTime.now().add(const Duration(hours: 1));
    var time = TimeOfDay.fromDateTime(date);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const FormDialogTitle(title: 'New Reminder'),
            titlePadding: formDialogTitlePadding,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => priority = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Date: ${DateFormat.yMMMd().format(date)}'),
                    subtitle: Text('Time: ${time.format(context)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      if (!context.mounted) return;
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (pickedTime == null) return;
                      setDialogState(() {
                        date = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        time = pickedTime;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) {
      titleCtrl.dispose();
      descCtrl.dispose();
      return;
    }

    final auth = ref.read(authUserProvider);
    final reminder = Reminder.create(
      memberId: auth?.memberId ?? '',
      createdBy: auth?.displayName ?? 'Unknown',
      title: titleCtrl.text,
      description: descCtrl.text,
      reminderDateTime: date,
      priority: priority,
    );
    titleCtrl.dispose();
    descCtrl.dispose();

    await ref.read(databaseServiceProvider).upsertReminder(reminder);
    ref.invalidate(remindersProvider);
  }

  Future<void> _toggleComplete(Reminder reminder) async {
    final updated = reminder.copyWith(
      isCompleted: !reminder.isCompleted,
      pendingSync: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(databaseServiceProvider).upsertReminder(updated);
    ref.invalidate(remindersProvider);
  }

  Future<void> _delete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('Remove "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseServiceProvider).softDeleteReminder(reminder.id);
    ref.invalidate(remindersProvider);
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.blueGrey;
      default:
        return AppTheme.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Reminders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Reminder'),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: remindersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (reminders) {
                if (reminders.isEmpty) {
                  return const Center(
                    child: Text('No reminders yet. Tap Add Reminder.'),
                  );
                }
                return ListView.separated(
                  itemCount: reminders.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return ListTile(
                      leading: Icon(
                        reminder.isCompleted
                            ? Icons.check_circle
                            : Icons.notifications_outlined,
                        color: reminder.isCompleted
                            ? Colors.green
                            : _priorityColor(reminder.priority),
                      ),
                      title: Text(
                        reminder.title,
                        style: TextStyle(
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reminder.description.isNotEmpty)
                            Text(reminder.description),
                          Text(
                            '${_dateFormat.format(reminder.reminderDateTime.toLocal())} · ${reminder.priority}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'complete') {
                            _toggleComplete(reminder);
                          } else if (value == 'delete') {
                            _delete(reminder);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'complete',
                            child: Text(
                              reminder.isCompleted
                                  ? 'Mark incomplete'
                                  : 'Mark complete',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
