import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/reminder.dart';
import '../../providers/providers.dart';

/// Dropdown + Auto-Assign + Save row for reminder RS assignment.
///
/// // NEW ADDITION - Delete this file to revert Reminders RS assignment UI.
class ReminderRsAssignmentRow extends ConsumerStatefulWidget {
  const ReminderRsAssignmentRow({
    super.key,
    required this.reminder,
    this.onChanged,
  });

  final Reminder reminder;
  final VoidCallback? onChanged;

  @override
  ConsumerState<ReminderRsAssignmentRow> createState() =>
      _ReminderRsAssignmentRowState();
}

class _ReminderRsAssignmentRowState
    extends ConsumerState<ReminderRsAssignmentRow> {
  String? _selectedSecretaryId;
  List<AppUser> _secretaries = [];
  bool _isAutoAssigning = false;
  bool _saving = false;

  static const _noneSentinel = '__none__';

  @override
  void initState() {
    super.initState();
    _selectedSecretaryId = widget.reminder.assignedSecretaryId;
    _loadSecretaries();
  }

  @override
  void didUpdateWidget(covariant ReminderRsAssignmentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reminder.id != widget.reminder.id ||
        oldWidget.reminder.assignedSecretaryId !=
            widget.reminder.assignedSecretaryId) {
      _selectedSecretaryId = widget.reminder.assignedSecretaryId;
    }
  }

  Future<void> _loadSecretaries() async {
    final list = await ref
        .read(databaseServiceProvider)
        .getRecordingSecretaries(activeOnly: true);
    if (!mounted) return;
    setState(() => _secretaries = list);
  }

  Future<void> _autoAssign() async {
    setState(() => _isAutoAssigning = true);
    try {
      final best =
          await ref.read(autoAssignmentServiceProvider).autoAssignToReminder(
                widget.reminder.id,
              );
      if (!mounted) return;
      if (best == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active Recording Secretaries available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _selectedSecretaryId = best.id);
      ref.invalidate(activeOnboardingRemindersProvider);
      ref.invalidate(membersProvider);
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-assigned to ${best.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoAssigning = false);
    }
  }

  Future<void> _saveAssignment({String assignmentMethod = 'manual'}) async {
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseServiceProvider);
      await db.assignSecretaryToReminder(
        reminderId: widget.reminder.id,
        secretaryId: _selectedSecretaryId,
        assignmentMethod: assignmentMethod,
      );
      await db.assignSecretaryToMember(
        memberId: widget.reminder.memberId,
        secretaryId: _selectedSecretaryId,
        assignmentMethod: assignmentMethod,
      );
      ref.invalidate(activeOnboardingRemindersProvider);
      ref.invalidate(membersProvider);
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = _selectedSecretaryId ?? _noneSentinel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: dropdownValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned RS',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: _noneSentinel,
                    child: Text('None Assigned'),
                  ),
                  ..._secretaries.map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.displayName, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSecretaryId =
                        value == _noneSentinel ? null : value;
                  });
                },
              ),
            ),
            ElevatedButton(
              onPressed: _isAutoAssigning ? null : _autoAssign,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _isAutoAssigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Auto-Assign'),
            ),
            ElevatedButton(
              onPressed: _saving ? null : () => _saveAssignment(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        if (widget.reminder.assignedSecretaryId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${widget.reminder.assignedSecretaryName ?? '—'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
