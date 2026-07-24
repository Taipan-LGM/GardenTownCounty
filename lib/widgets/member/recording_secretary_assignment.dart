import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';

/// Admin-only radio list to assign a Recording Secretary to a member.
///
/// // NEW ADDITION - Delete this file to revert Member Info RS assignment UI.
class RecordingSecretaryAssignment extends ConsumerStatefulWidget {
  const RecordingSecretaryAssignment({
    super.key,
    required this.member,
    required this.isAdmin,
    this.onAssigned,
  });

  final Member member;
  final bool isAdmin;
  final VoidCallback? onAssigned;

  @override
  ConsumerState<RecordingSecretaryAssignment> createState() =>
      _RecordingSecretaryAssignmentState();
}

class _RecordingSecretaryAssignmentState
    extends ConsumerState<RecordingSecretaryAssignment> {
  String? _selectedSecretaryId;
  List<({AppUser user, int count})> _secretaries = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSecretaryId = widget.member.assignedSecretaryId;
    _loadSecretaries();
  }

  @override
  void didUpdateWidget(covariant RecordingSecretaryAssignment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.id != widget.member.id ||
        oldWidget.member.assignedSecretaryId !=
            widget.member.assignedSecretaryId) {
      _selectedSecretaryId = widget.member.assignedSecretaryId;
      _loadSecretaries();
    }
  }

  Future<void> _loadSecretaries() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final list = await db.getRecordingSecretaries(activeOnly: true);
      final withCounts = <({AppUser user, int count})>[];
      for (final s in list) {
        final count = await db.countAssignedMembers(s.id);
        withCounts.add((user: s, count: count));
      }
      if (!mounted) return;
      setState(() {
        _secretaries = withCounts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAssignment() async {
    setState(() => _saving = true);
    try {
      final admin = ref.read(authUserProvider);
      await ref.read(databaseServiceProvider).assignSecretaryToMember(
            memberId: widget.member.id,
            secretaryId: _selectedSecretaryId,
            assignedBy: admin?.id,
            assignmentMethod: 'manual',
          );
      ref.invalidate(membersProvider);
      await _loadSecretaries();
      widget.onAssigned?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording Secretary assignment saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _currentName() {
    final id = widget.member.assignedSecretaryId;
    if (id == null) return 'None';
    if (widget.member.assignedSecretaryName != null &&
        widget.member.assignedSecretaryName!.isNotEmpty) {
      return widget.member.assignedSecretaryName!;
    }
    for (final s in _secretaries) {
      if (s.user.id == id) return s.user.displayName;
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) return const SizedBox.shrink();

    final dateFmt = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assigned Recording Secretary (Admin Only)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Select Recording Secretary:'),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ..._secretaries.map((entry) {
                final secretary = entry.user;
                final count = entry.count;
                return RadioListTile<String>(
                  title: Text(
                    '${secretary.displayName} (Active - $count members assigned)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    secretary.username,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  value: secretary.id,
                  groupValue: _selectedSecretaryId,
                  onChanged: (value) {
                    setState(() => _selectedSecretaryId = value);
                  },
                  secondary: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '$count',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                );
              }),
              RadioListTile<String?>(
                title: const Text('None Assigned'),
                value: null,
                groupValue: _selectedSecretaryId,
                onChanged: (value) {
                  setState(() => _selectedSecretaryId = null);
                },
              ),
            ],
            const SizedBox(height: 8),
            if (widget.member.assignedSecretaryId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Current Assignment: ${_currentName()}'
                  '${widget.member.assignedDate != null ? ' (Assigned: ${dateFmt.format(widget.member.assignedDate!.toLocal())})' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveAssignment,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Assignment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
