import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/member.dart';
import '../../models/user_role.dart';
import '../../providers/providers.dart';

/// Admin-only: assign roles & permissions to Members (no login/password).
class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberName = TextEditingController();
  final _surname = TextEditingController();

  Member? _selectedMember;
  String _role = UserRole.secretary.storageName;
  final Set<AppPermission> _granted = {};
  AppUser? _editingUser;
  bool _saving = false;

  final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _memberName.dispose();
    _surname.dispose();
    super.dispose();
  }

  void _clearForm() {
    _selectedMember = null;
    _memberName.clear();
    _surname.clear();
    _role = UserRole.secretary.storageName;
    _granted.clear();
    _editingUser = null;
    setState(() {});
  }

  void _onMemberPicked(Member member) {
    final users = ref.read(appUsersProvider).valueOrNull ?? const [];
    final admin = users.where((u) => u.isSystemAdministrator);
    if (admin.isNotEmpty &&
        (admin.first.memberId == member.id ||
            admin.first.username == member.saId.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ The System Administrator cannot be demoted.'),
        ),
      );
      return;
    }
    final alreadySecretary = users.any(
      (u) =>
          !u.deleted &&
          u.isSecretary &&
          (u.memberId == member.id ||
              u.username == member.saId.toLowerCase()) &&
          u.id != _editingUser?.id,
    );
    if (alreadySecretary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ This Member is already a Recording Secretary.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedMember = member;
      _memberName.text = member.memberName;
      _surname.text = member.surname;
    });
  }

  void _loadForEdit(AppUser user, List<Member> members) {
    Member? member;
    if (user.memberId != null) {
      for (final m in members) {
        if (m.id == user.memberId) {
          member = m;
          break;
        }
      }
    }
    if (member == null) {
      for (final m in members) {
        if (m.saId.toLowerCase() == user.username.toLowerCase()) {
          member = m;
          break;
        }
      }
    }

    setState(() {
      _editingUser = user;
      _selectedMember = member;
      _memberName.text =
          member?.memberName ?? user.displayName.split(' ').first;
      _surname.text = member?.surname ??
          (user.displayName.contains(' ')
              ? user.displayName.split(' ').skip(1).join(' ')
              : '');
      _role = user.userRole.storageName;
      _granted
        ..clear()
        ..addAll(user.permissions.where((p) => !p.isAdminOnly));
    });
  }

  Future<void> _save() async {
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Member by SA ID.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = ref.read(authServiceProvider);
      final admin = ref.read(authUserProvider);
      final perms = _role == UserRole.secretary.storageName
          ? _granted.toList()
          : const <AppPermission>[];

      if (_role == UserRole.secretary.storageName && perms.isEmpty) {
        final cont = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No permissions'),
            content: const Text(
              'No permissions selected. User will have no rights. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (cont != true) return;
      }

      final saved = await auth.assignMemberAccess(
        memberId: _selectedMember!.id,
        saId: _selectedMember!.saId,
        memberName: _memberName.text.trim(),
        surname: _surname.text.trim(),
        role: _role,
        permissions: perms,
      );

      if (admin != null) {
        await ref.read(activityServiceProvider).record(
              userName: admin.displayName,
              action:
                  'User Management: ${saved.displayName} → ${saved.role}',
              captureGps: false,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingUser == null
                  ? 'Access assigned to ${saved.displayName}'
                  : 'Access updated for ${saved.displayName}',
            ),
          ),
        );
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

  Future<void> _delete(AppUser user) async {
    if (user.isSystemAdministrator || user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The System Administrator cannot be deleted. This account is protected.',
          ),
        ),
      );
      return;
    }

    final name = user.displayName;
    final msg = user.isSecretary
        ? '⚠️ This will remove all rights from $name. They will become a regular Member. Continue?'
        : '⚠️ This will permanently delete $name\'s account. Continue?';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(authServiceProvider).removeMemberAccess(user.id);
      ref.invalidate(appUsersProvider);
      if (_editingUser?.id == user.id) _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated access for $name')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _onToggle(AppPermission p, bool value) {
    if (p.isAdminOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 This permission is reserved for the System Administrator.',
          ),
        ),
      );
      return;
    }
    setState(() {
      if (value) {
        _granted.add(p);
      } else {
        _granted.remove(p);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(authUserProvider);
    final usersAsync = ref.watch(appUsersProvider);
    final membersAsync = ref.watch(membersProvider);

    if (current == null || !current.isAdmin) {
      return const Center(child: Text('Admin access required.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final form = _buildForm(membersAsync);
          final list = _buildUserList(usersAsync, membersAsync);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: form),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: list),
              ],
            );
          }
          return ListView(
            children: [
              form,
              const SizedBox(height: 24),
              SizedBox(height: 420, child: list),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<Member>> membersAsync) {
    final showRights = _role == UserRole.secretary.storageName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                _editingUser == null
                    ? 'User Management — Assign Roles & Permissions'
                    : 'Edit Access — ${_editingUser!.displayName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Roles & permissions only — login credentials are separate.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 16),
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Members error: $e'),
                data: (members) {
                  final users =
                      ref.watch(appUsersProvider).valueOrNull ?? const [];
                  final secretaryMemberIds = users
                      .where((u) => u.isSecretary && !u.deleted)
                      .map((u) => u.memberId)
                      .whereType<String>()
                      .toSet();
                  final admin = users.where((u) => u.isSystemAdministrator);
                  final adminMemberId =
                      admin.isEmpty ? null : admin.first.memberId;
                  final options = members.where((m) {
                    if (_editingUser?.memberId == m.id) return true;
                    if (adminMemberId == m.id) return false;
                    if (secretaryMemberIds.contains(m.id) &&
                        _editingUser?.memberId != m.id) {
                      return false;
                    }
                    return true;
                  }).toList();

                  return Autocomplete<Member>(
                    displayStringForOption: (m) =>
                        '${m.saId} — ${m.memberName} ${m.surname}',
                    optionsBuilder: (text) {
                      final q = text.text.trim().toLowerCase();
                      if (q.isEmpty) return options.take(30);
                      return options.where((m) {
                        return m.saId.toLowerCase().contains(q) ||
                            m.memberName.toLowerCase().contains(q) ||
                            m.surname.toLowerCase().contains(q);
                      }).take(30);
                    },
                    onSelected: _onMemberPicked,
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmit) {
                      if (_selectedMember != null &&
                          controller.text.isEmpty) {
                        controller.text = _selectedMember!.saId;
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: _editingUser == null,
                        decoration: const InputDecoration(
                          labelText: '1. SA ID No. *',
                          hintText: 'Search for Member by SA ID',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, opts) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 240,
                              maxWidth: 480,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: opts.length,
                              itemBuilder: (context, i) {
                                final m = opts.elementAt(i);
                                return ListTile(
                                  dense: true,
                                  title: Text(m.saId),
                                  subtitle:
                                      Text('${m.memberName} ${m.surname}'),
                                  onTap: () => onSelected(m),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memberName,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '2. Member Name',
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _surname,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '3. Surname',
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: '4. Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Recording Secretary',
                    child: Text('Recording Secretary'),
                  ),
                  DropdownMenuItem(
                    value: 'Member',
                    child: Text('Member'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _role = v;
                    if (v != UserRole.secretary.storageName) {
                      _granted.clear();
                    }
                  });
                },
              ),
              if (showRights) ...[
                const SizedBox(height: 20),
                const Text(
                  'Recording Secretary Rights',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.forestGreen,
                  ),
                ),
                const SizedBox(height: 8),
                ...AppPermission.managementOrder.map(_permissionTile),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_editingUser == null ? 'Save' : 'Update'),
                  ),
                  OutlinedButton(
                    onPressed: _saving ? null : _clearForm,
                    child: const Text('Cancel'),
                  ),
                  if (_editingUser != null)
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _delete(_editingUser!),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete User',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile(AppPermission p) {
    final locked = p.isAdminOnly;
    final on = locked ? false : _granted.contains(p);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.label),
      subtitle: locked
          ? const Text('Reserved for System Administrator')
          : null,
      value: on,
      onChanged: locked ? (_) => _onToggle(p, true) : (v) => _onToggle(p, v),
      secondary: locked
          ? const Icon(Icons.lock, color: Colors.grey)
          : null,
    );
  }

  Widget _buildUserList(
    AsyncValue<List<AppUser>> usersAsync,
    AsyncValue<List<Member>> membersAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (users) {
            final members = membersAsync.valueOrNull ?? const <Member>[];
            Member? memberOf(AppUser u) {
              if (u.memberId != null) {
                for (final m in members) {
                  if (m.id == u.memberId) return m;
                }
              }
              for (final m in members) {
                if (m.saId.toLowerCase() == u.username.toLowerCase()) {
                  return m;
                }
              }
              return null;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Users',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppTheme.forestGreen.withValues(alpha: 0.12),
                        ),
                        columns: const [
                          DataColumn(label: Text('SA ID No.')),
                          DataColumn(label: Text('Member Name')),
                          DataColumn(label: Text('Surname')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Permissions')),
                          DataColumn(label: Text('Created')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: users.map((u) {
                          final m = memberOf(u);
                          final protected =
                              u.isSystemAdministrator || u.isAdmin;
                          final permsLabel = protected
                              ? 'All'
                              : (u.permissions.isEmpty
                                  ? '—'
                                  : u.permissions
                                      .map((p) => p.label)
                                      .join(', '));
                          return DataRow(
                            color: protected
                                ? WidgetStateProperty.all(
                                    AppTheme.forestGreen
                                        .withValues(alpha: 0.18),
                                  )
                                : null,
                            cells: [
                              DataCell(Text(m?.saId ?? u.username)),
                              DataCell(Text(
                                m?.memberName ??
                                    u.displayName.split(' ').first,
                              )),
                              DataCell(Text(
                                m?.surname ??
                                    (u.displayName.contains(' ')
                                        ? u.displayName
                                            .split(' ')
                                            .skip(1)
                                            .join(' ')
                                        : '—'),
                              )),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(u.userRole.label),
                                    if (protected) ...[
                                      const SizedBox(width: 6),
                                      const Tooltip(
                                        message:
                                            '🔒 The System Administrator cannot be edited or deleted.',
                                        child: Chip(
                                          label: Text(
                                            '🔒 Protected',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          avatar: Icon(Icons.lock, size: 14),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    permsLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(_dateFmt.format(u.updatedAt.toLocal())),
                              ),
                              DataCell(
                                protected
                                    ? const Tooltip(
                                        message:
                                            '🔒 The System Administrator cannot be edited or deleted.',
                                        child: Icon(
                                          Icons.lock,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit',
                                            icon: const Icon(Icons.edit),
                                            onPressed: () =>
                                                _loadForEdit(u, members),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: () => _delete(u),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
