import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/member.dart';
import '../../models/user_role.dart';
import '../../providers/providers.dart';
import '../../screens/settings/remuneration_dashboard_screen.dart';

/// Admin-only: promote this Member to Recording Secretary (or demote).
///
/// Replaces RS *assignment* radios on Member Info. Assignment of secretaries
/// to other members remains on Reminders.
///
/// // NEW ADDITION - Delete this file to revert promote-to-RS UI.
class PromoteToRecordingSecretaryWidget extends ConsumerStatefulWidget {
  const PromoteToRecordingSecretaryWidget({
    super.key,
    required this.member,
    required this.isAdmin,
    this.onChanged,
  });

  final Member member;
  final bool isAdmin;
  final VoidCallback? onChanged;

  @override
  ConsumerState<PromoteToRecordingSecretaryWidget> createState() =>
      _PromoteToRecordingSecretaryWidgetState();
}

class _PromoteToRecordingSecretaryWidgetState
    extends ConsumerState<PromoteToRecordingSecretaryWidget> {
  bool _wantPromote = false;
  bool _isSecretary = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshRole();
  }

  @override
  void didUpdateWidget(covariant PromoteToRecordingSecretaryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.id != widget.member.id) {
      _wantPromote = false;
      _refreshRole();
    }
  }

  Future<void> _refreshRole() async {
    setState(() => _loading = true);
    try {
      final isSec = await ref
          .read(promotionServiceProvider)
          .isRecordingSecretary(widget.member);
      if (!mounted) return;
      setState(() {
        _isSecretary = isSec;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _promote() async {
    final admin = ref.read(authUserProvider);
    if (admin == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote to Recording Secretary?'),
        content: Text(
          'Promote ${widget.member.fullName} to Recording Secretary?\n\n'
          'They will appear in RS assignment dropdowns and can earn remuneration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Promote'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(promotionServiceProvider).promoteToRecordingSecretary(
            member: widget.member,
            admin: admin,
            permissions: AppPermission.assignable,
          );
      ref.invalidate(appUsersProvider);
      await _refreshRole();
      widget.onChanged?.call();
      if (mounted) {
        setState(() => _wantPromote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.member.fullName} is now a Recording Secretary'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demote() async {
    final admin = ref.read(authUserProvider);
    if (admin == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demote to Member?'),
        content: Text(
          'Demote ${widget.member.fullName} to Regular Member?\n\n'
          'Recording Secretary privileges will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Demote'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(promotionServiceProvider).demoteToMember(
            member: widget.member,
            admin: admin,
          );
      ref.invalidate(appUsersProvider);
      await _refreshRole();
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.member.fullName} is now a Regular Member'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isSecretary
                            ? Icons.admin_panel_settings
                            : Icons.person_add,
                        color: _isSecretary ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isSecretary
                              ? 'Recording Secretary'
                              : 'Promote to Recording Secretary (Admin Only)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_isSecretary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSecretary
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSecretary
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      _isSecretary
                          ? '${widget.member.fullName} is currently a Recording Secretary.'
                          : '${widget.member.fullName} is currently a Regular Member.',
                    ),
                  ),
                  if (!_isSecretary) ...[
                    const SizedBox(height: 12),
                    RadioListTile<bool>(
                      title: const Text('Keep as Regular Member'),
                      value: false,
                      groupValue: _wantPromote,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _wantPromote = v ?? false),
                    ),
                    RadioListTile<bool>(
                      title: const Text('Promote to Recording Secretary'),
                      value: true,
                      groupValue: _wantPromote,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _wantPromote = v ?? false),
                    ),
                    if (_wantPromote) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'If promoted, this member will:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text('• Appear in RS assignment dropdowns'),
                            Text('• Manage onboarding / reminders (with permissions)'),
                            Text('• Earn remuneration for completed steps 2–4'),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!_isSecretary && _wantPromote)
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _promote,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified),
                          label: const Text('Save Role Change'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (_isSecretary) ...[
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _demote,
                          icon: const Icon(Icons.person_remove),
                          label: const Text('Demote to Member'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const RemunerationDashboardScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dashboard),
                          label: const Text('View All Recording Secretaries'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
