import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import 'role_manager_dialog.dart';

class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  String? _role;
  AppUser? _editingUser;
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearForm() {
    _username.clear();
    _displayName.clear();
    _password.clear();
    _editingUser = null;
    _role = null;
    setState(() {});
  }

  void _loadForEdit(AppUser user) {
    setState(() {
      _editingUser = user;
      _username.text = user.username;
      _displayName.text = user.displayName;
      _password.clear();
      _role = user.role;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null || _role!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Rights / Role.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = ref.read(authServiceProvider);
      final admin = ref.read(authUserProvider);
      if (_editingUser == null) {
        final created = await auth.createOperator(
          username: _username.text,
          displayName: _displayName.text,
          password: _password.text,
          role: _role!,
        );
        if (admin != null) {
          await ref.read(activityServiceProvider).record(
                userName: admin.displayName,
                action:
                    'Added operator ${created.username} (${created.role})',
                captureGps: false,
              );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operator "${created.username}" created')),
          );
        }
      } else {
        final updated = await auth.updateOperator(
          id: _editingUser!.id,
          username: _username.text,
          displayName: _displayName.text,
          role: _role!,
          newPassword: _password.text.trim().isEmpty ? null : _password.text,
        );
        // Refresh session chip if SysAdmin updated own display name.
        final loggedIn = ref.read(authUserProvider);
        if (loggedIn != null && loggedIn.id == updated.id) {
          ref.read(authUserProvider.notifier).state = AuthUser(
            id: updated.id,
            displayName: updated.displayName,
            email: loggedIn.email,
            username: updated.username,
            role: updated.role,
          );
        }
        if (admin != null) {
          await ref.read(activityServiceProvider).record(
                userName: admin.displayName,
                action:
                    'Updated operator ${updated.username} (${updated.role})',
                captureGps: false,
              );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operator "${updated.username}" updated')),
          );
        }
      }
      await ref.read(syncEngineProvider).pushPending();
      _clearForm();
      ref.invalidate(appUsersProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(appUsersProvider);
    final rolesAsync = ref.watch(rolesProvider);
    final current = ref.watch(authUserProvider);

    if (current == null || !current.isAdmin) {
      return const Center(child: Text('Admin access required.'));
    }

    final editingSysAdmin = _editingUser?.isSystemAdministrator == true;
    final canEditSysAdminSecrets = current.isSystemAdministrator;
    final lockRole = editingSysAdmin;
    final lockPassword = editingSysAdmin && !canEditSysAdminSecrets;
    // SysAdmin may set their own login username; others may not.
    final lockUsername = _editingUser != null &&
        !(editingSysAdmin && canEditSysAdminSecrets);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingUser == null ? 'Add User' : 'Edit User',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            editingSysAdmin
                ? 'System Administrator: set Username and Display Name. '
                    'Role is locked. Password only by System Administrator.'
                : 'Username = login ID. Display Name = name shown in the app.',
          ),
          const Divider(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _username,
                            enabled: !lockUsername,
                            decoration: InputDecoration(
                              labelText: editingSysAdmin
                                  ? 'Username (login ID)'
                                  : 'Username',
                              helperText: editingSysAdmin
                                  ? 'System Administrator login name'
                                  : 'Login ID used to sign in',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _displayName,
                            decoration: InputDecoration(
                              labelText: editingSysAdmin
                                  ? 'Display Name (your name)'
                                  : 'Display Name',
                              helperText: editingSysAdmin
                                  ? 'Name shown in the app'
                                  : 'Friendly name shown in the app',
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                            validator: (v) {
                              if (editingSysAdmin &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Name required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _password,
                            enabled: !lockPassword,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: _editingUser == null
                                  ? 'Password'
                                  : lockPassword
                                      ? 'Password (locked)'
                                      : 'New Password (optional)',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: lockPassword
                                    ? null
                                    : () =>
                                        setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (lockPassword) return null;
                              if (_editingUser != null) {
                                if (v != null &&
                                    v.isNotEmpty &&
                                    v.length < 6) {
                                  return 'Min 6 characters';
                                }
                                return null;
                              }
                              if (v == null || v.length < 6) {
                                return 'Min 6 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: rolesAsync.when(
                            data: (roles) {
                              final names = roles.map((r) => r.name).toList();
                              final effective =
                                  _role != null && names.contains(_role)
                                      ? _role
                                      : null;
                              return Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey(
                                        'role-${_editingUser?.id ?? 'new'}-$effective-$lockRole',
                                      ),
                                      initialValue: effective,
                                      decoration: InputDecoration(
                                        labelText: lockRole
                                            ? 'Rights / Role (locked)'
                                            : 'Rights / Role',
                                      ),
                                      items: names
                                          .map(
                                            (n) => DropdownMenuItem(
                                              value: n,
                                              child: Text(n),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: lockRole
                                          ? null
                                          : (value) =>
                                              setState(() => _role = value),
                                      validator: (v) =>
                                          (v == null || v.isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Add / Edit / Delete roles',
                                    icon: const Icon(Icons.edit_note),
                                    onPressed: lockRole
                                        ? null
                                        : () async {
                                            await showRoleManagerDialog(
                                              context,
                                              ref,
                                            );
                                            ref.invalidate(rolesProvider);
                                          },
                                  ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Roles error: $e'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_editingUser != null)
                          TextButton(
                            onPressed: _saving ? null : _clearForm,
                            child: const Text('Cancel Edit'),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _editingUser == null
                                      ? Icons.person_add
                                      : Icons.save,
                                ),
                          label: Text(
                            _editingUser == null ? 'Add User' : 'Save Changes',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Operators',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No operators yet.'));
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final protected =
                        user.isAdmin || user.isSystemAdministrator;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.forestGreen,
                        child: Text(
                          user.role.isNotEmpty
                              ? user.role[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(
                        '${user.username} · ${user.role}'
                        '${user.active ? '' : ' · Inactive'}'
                        '${user.isSystemAdministrator ? ' · System Administrator' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _loadForEdit(user),
                          ),
                          IconButton(
                            tooltip: protected
                                ? 'Admin cannot be deactivated'
                                : (user.active ? 'Deactivate' : 'Activate'),
                            icon: Icon(
                              user.active
                                  ? Icons.toggle_on
                                  : Icons.toggle_off_outlined,
                              color: protected
                                  ? Colors.grey
                                  : (user.active
                                      ? AppTheme.forestGreen
                                      : Colors.grey),
                            ),
                            onPressed: protected
                                ? null
                                : () async {
                                    try {
                                      await ref
                                          .read(authServiceProvider)
                                          .setOperatorActive(
                                            user.id,
                                            !user.active,
                                          );
                                      await ref
                                          .read(syncEngineProvider)
                                          .pushPending();
                                      ref.invalidate(appUsersProvider);
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                          if (user.id != current.id)
                            IconButton(
                              tooltip: protected
                                  ? 'Admin cannot be deleted'
                                  : 'Delete',
                              icon: Icon(
                                Icons.delete_outline,
                                color: protected ? Colors.grey : Colors.red,
                              ),
                              onPressed: protected
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(authServiceProvider)
                                            .softDeleteOperator(user.id);
                                        await ref
                                            .read(syncEngineProvider)
                                            .pushPending();
                                        ref.invalidate(appUsersProvider);
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                error.toString().replaceFirst(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
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
