import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';
import '../providers/providers.dart';
import '../services/cancellation_service.dart';

/// Admin confirmation dialog to soft-cancel a membership.
///
/// // NEW ADDITION - Delete this file to revert cancel dialog.
class CancelMembershipDialog extends ConsumerStatefulWidget {
  const CancelMembershipDialog({super.key, required this.member});

  final Member member;

  static Future<bool?> show(BuildContext context, Member member) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CancelMembershipDialog(member: member),
    );
  }

  @override
  ConsumerState<CancelMembershipDialog> createState() =>
      _CancelMembershipDialogState();
}

class _CancelMembershipDialogState
    extends ConsumerState<CancelMembershipDialog> {
  final _reasonController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final admin = ref.read(authUserProvider);
    if (admin == null || !admin.isAdmin) return;
    setState(() => _loading = true);
    try {
      final service = CancellationService(
        ref.read(databaseServiceProvider),
        ref.read(activityServiceProvider),
      );
      await service.cancelMembership(
        memberId: widget.member.id,
        admin: admin,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling membership: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Colors.red),
          SizedBox(width: 8),
          Text('Cancel Membership'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancel ${m.fullName}\'s membership?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Member data is kept. They move to Cancellations and can be reinstated later.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Keep Membership'),
        ),
        FilledButton(
          onPressed: _loading ? null : _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cancel Membership'),
        ),
      ],
    );
  }
}
