import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/role_definition.dart';
import '../../providers/providers.dart';
import '../../widgets/form_dialog_title.dart';

Future<void> showRoleManagerDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => const RoleManagerDialog(),
  );
}

class RoleManagerDialog extends ConsumerStatefulWidget {
  const RoleManagerDialog({super.key});

  @override
  ConsumerState<RoleManagerDialog> createState() => _RoleManagerDialogState();
}

class _RoleManagerDialogState extends ConsumerState<RoleManagerDialog> {
  final _controller = TextEditingController();
  RoleDefinition? _editing;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    try {
      if (_editing != null) {
        await ref.read(authServiceProvider).editRole(
              id: _editing!.id,
              name: value,
            );
      } else {
        await ref.read(authServiceProvider).addRole(value);
      }
      await ref.read(syncEngineProvider).pushPending();
      _controller.clear();
      _editing = null;
      ref.invalidate(rolesProvider);
      ref.invalidate(appUsersProvider);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _delete(RoleDefinition role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text('Remove "${role.name}"?'),
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
    try {
      await ref.read(authServiceProvider).deleteRole(role.id);
      await ref.read(syncEngineProvider).pushPending();
      ref.invalidate(rolesProvider);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRoles = ref.watch(rolesProvider);

    return AlertDialog(
      title: const FormDialogTitle(title: 'Manage Rights / Role'),
      titlePadding: formDialogTitlePadding,
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText:
                          _editing == null ? 'Add new role' : 'Edit role name',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(_editing == null ? 'Add' : 'Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncRoles.when(
                data: (roles) => ListView.builder(
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    return ListTile(
                      title: Text(role.name),
                      subtitle: Text(
                        [
                          if (role.isSystem) 'System',
                          if (role.grantsAdmin) 'Admin rights',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: role.isSystem && role.isAdminRole
                                ? null
                                : () {
                                    setState(() {
                                      _editing = role;
                                      _controller.text = role.name;
                                    });
                                  },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: role.isSystem || role.isAdminRole
                                ? null
                                : () => _delete(role),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
