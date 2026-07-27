import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/user_role.dart'; // AppPermission
import '../providers/providers.dart';
import 'cancel_button.dart';

/// Admin dialog to edit Recording Secretary permissions.
///
/// // NEW ADDITION - Delete this file to revert permission editor dialog.
class PermissionEditorDialog extends ConsumerStatefulWidget {
  const PermissionEditorDialog({
    super.key,
    required this.user,
    this.assignedMembersCount = 0,
    this.saId,
  });

  final AppUser user;
  final int assignedMembersCount;
  final String? saId;

  static Future<AppUser?> show(
    BuildContext context, {
    required AppUser user,
    int assignedMembersCount = 0,
    String? saId,
  }) {
    return showDialog<AppUser>(
      context: context,
      builder: (_) => PermissionEditorDialog(
        user: user,
        assignedMembersCount: assignedMembersCount,
        saId: saId,
      ),
    );
  }

  @override
  ConsumerState<PermissionEditorDialog> createState() =>
      _PermissionEditorDialogState();
}

class _PermissionEditorDialogState
    extends ConsumerState<PermissionEditorDialog> {
  late final Set<AppPermission> _granted;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _granted = {
      ...AppPermission.mergeSecretaryPermissions(widget.user.permissions),
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.displayName;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit Permissions — $name',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('SA ID: ${widget.saId ?? widget.user.username}'),
                    const Text('Role: Recording Secretary'),
                    Text('Assigned Members: ${widget.assignedMembersCount}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Permissions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...AppPermission.assignable.map(
                (p) => _tile(
                  permission: p,
                  checked: _granted.contains(p),
                  enabled: true,
                  badge: p.isDefaultForSecretary ? 'Default' : 'Optional',
                  badgeColor:
                      p.isDefaultForSecretary ? Colors.green : Colors.orange,
                ),
              ),
              const Divider(),
              ...AppPermission.adminOnly.map(
                (p) => _tile(
                  permission: p,
                  checked: false,
                  enabled: false,
                  badge: 'Admin Only',
                  badgeColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Rules',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Default: Suggested on promote — Admin may turn on/off',
                      style: TextStyle(fontSize: 11),
                    ),
                    const Text(
                      'Optional: Extra rights Admin may grant',
                      style: TextStyle(fontSize: 11),
                    ),
                    const Text(
                      'Admin Only: Reserved for System Administrator',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        CancelButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          text: 'Cancel',
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Save Permissions'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required AppPermission permission,
    required bool checked,
    required bool enabled,
    required String badge,
    required MaterialColor badgeColor,
  }) {
    return CheckboxListTile(
      value: checked,
      onChanged: enabled
          ? (v) {
              setState(() {
                if (v == true) {
                  _granted.add(permission);
                } else {
                  _granted.remove(permission);
                }
              });
            }
          : null,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Expanded(child: Text(permission.label)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: badgeColor.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final perms = AppPermission.mergeSecretaryPermissions(_granted);
      // Persist by AppUser id — no Member link required.
      // MODIFIED - use updateSecretaryPermissions (Delete to revert)
      final saved =
          await ref.read(authServiceProvider).updateSecretaryPermissions(
                userId: widget.user.id,
                permissions: perms,
              );

      final admin = ref.read(authUserProvider);
      if (admin != null) {
        await ref.read(activityServiceProvider).record(
              userName: admin.displayName,
              action:
                  'update_permissions ${saved.displayName}: '
                  '${perms.map((p) => p.label).join(', ')}',
              captureGps: false,
            );
      }

      ref.invalidate(appUsersProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
