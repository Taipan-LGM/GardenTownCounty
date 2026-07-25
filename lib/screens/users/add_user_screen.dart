import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/member.dart';
import '../../models/user_role.dart';
import '../../providers/providers.dart';
import '../../widgets/permission_editor_dialog.dart';

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
  final Set<AppPermission> _granted = {...AppPermission.defaultSecretary};
  AppUser? _editingUser;
  bool _saving = false;
  String _searchQuery = '';
  String _roleFilter = 'All';

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
    _granted
      ..clear()
      ..addAll(AppPermission.defaultSecretary);
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
        ..addAll(AppPermission.mergeSecretaryPermissions(user.permissions));
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
          ? AppPermission.mergeSecretaryPermissions(_granted)
          : const <AppPermission>[];

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
            'This permission is reserved for the System Administrator.',
          ),
        ),
      );
      return;
    }
    if (p.isRequiredForSecretary && !value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.label} is required for Recording Secretaries.'),
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

  Future<void> _editSecretaryPermissions(
    AppUser user,
    List<Member> members,
  ) async {
    final count = await ref
        .read(databaseServiceProvider)
        .countAssignedMembers(user.id);
    Member? member;
    if (user.memberId != null) {
      for (final m in members) {
        if (m.id == user.memberId) {
          member = m;
          break;
        }
      }
    }
    if (!mounted) return;
    final result = await PermissionEditorDialog.show(
      context,
      user: user,
      assignedMembersCount: count,
      saId: member?.saId ?? user.username,
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(appUsersProvider);
    }
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
                  color: AppTheme.bodyText,
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
                    if (v == UserRole.secretary.storageName) {
                      _granted
                        ..clear()
                        ..addAll(AppPermission.defaultSecretary);
                    } else {
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
                    color: AppTheme.bodyText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required permissions cannot be removed. Optional can be toggled.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
    final adminOnly = p.isAdminOnly;
    final required = p.isRequiredForSecretary;
    final on = adminOnly ? false : (required || _granted.contains(p));
    final locked = adminOnly || required;
    String? subtitle;
    if (adminOnly) {
      subtitle = 'Admin Only — reserved for System Administrator';
    } else if (required) {
      subtitle = 'Required — cannot be removed';
    } else {
      subtitle = 'Optional';
    }
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.label),
      subtitle: Text(subtitle),
      value: on,
      onChanged: locked
          ? (_) => _onToggle(p, !on)
          : (v) => _onToggle(p, v),
      secondary: Icon(
        locked ? Icons.lock : Icons.toggle_on_outlined,
        color: locked ? Colors.grey : Colors.green,
      ),
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

            final admins =
                users.where((u) => !u.deleted && u.isAdmin).length;
            final secretaries =
                users.where((u) => !u.deleted && u.isSecretary).length;
            final memberUsers =
                users.where((u) => !u.deleted && u.isMemberRole).length;

            final q = _searchQuery.trim().toLowerCase();
            var filtered = users.where((u) => !u.deleted).toList();
            if (_roleFilter == 'Admin') {
              filtered = filtered.where((u) => u.isAdmin).toList();
            } else if (_roleFilter == 'Secretary') {
              filtered = filtered.where((u) => u.isSecretary).toList();
            } else if (_roleFilter == 'Member') {
              filtered = filtered.where((u) => u.isMemberRole).toList();
            }
            if (q.isNotEmpty) {
              filtered = filtered.where((u) {
                final m = memberOf(u);
                final hay = [
                  u.displayName,
                  u.username,
                  m?.saId ?? '',
                  m?.memberName ?? '',
                  m?.surname ?? '',
                ].join(' ').toLowerCase();
                return hay.contains(q);
              }).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'User Manager',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statChip('Total: ${users.where((u) => !u.deleted).length}'),
                    _statChip('Admins: $admins'),
                    _statChip('Secretaries: $secretaries'),
                    _statChip('Members: $memberUsers'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _roleFilter,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Roles')),
                        DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'Secretary',
                          child: Text('Secretary'),
                        ),
                        DropdownMenuItem(value: 'Member', child: Text('Member')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _roleFilter = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<Map<String, int>>(
                    future: _loadAssignedCounts(filtered),
                    builder: (context, snap) {
                      final counts = snap.data ?? const <String, int>{};
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppTheme.forestGreen.withValues(alpha: 0.12),
                            ),
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Assigned')),
                              DataColumn(label: Text('Permissions')),
                              DataColumn(label: Text('Updated')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: filtered.map((u) {
                              final m = memberOf(u);
                              final protected =
                                  u.isSystemAdministrator || u.isAdmin;
                              final permCount = protected
                                  ? AppPermission.managementOrder.length
                                  : u.permissions.length;
                              final permsLabel = protected
                                  ? 'All'
                                  : '$permCount/11';
                              final assigned = u.isSecretary
                                  ? '${counts[u.id] ?? 0}'
                                  : '—';
                              return DataRow(
                                color: protected
                                    ? WidgetStateProperty.all(
                                        AppTheme.forestGreen
                                            .withValues(alpha: 0.18),
                                      )
                                    : u.isSecretary
                                        ? WidgetStateProperty.all(
                                            Colors.green.shade50,
                                          )
                                        : null,
                                onSelectChanged: u.isSecretary && !protected
                                    ? (_) => _editSecretaryPermissions(
                                          u,
                                          members,
                                        )
                                    : null,
                                cells: [
                                  DataCell(
                                    Text(
                                      m == null
                                          ? u.displayName
                                          : '${m.memberName} ${m.surname}',
                                    ),
                                  ),
                                  DataCell(Text(u.userRole.label)),
                                  DataCell(Text(assigned)),
                                  DataCell(Text(permsLabel)),
                                  DataCell(
                                    Text(
                                      _dateFmt.format(u.updatedAt.toLocal()),
                                    ),
                                  ),
                                  DataCell(
                                    protected
                                        ? const Tooltip(
                                            message:
                                                'System Administrator cannot be edited or deleted.',
                                            child: Icon(
                                              Icons.lock,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: u.isSecretary
                                                    ? 'Edit Permissions'
                                                    : 'Edit',
                                                icon: const Icon(Icons.edit),
                                                onPressed: () {
                                                  if (u.isSecretary) {
                                                    _editSecretaryPermissions(
                                                      u,
                                                      members,
                                                    );
                                                  } else {
                                                    _loadForEdit(u, members);
                                                  }
                                                },
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
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<Map<String, int>> _loadAssignedCounts(List<AppUser> users) async {
    final db = ref.read(databaseServiceProvider);
    final out = <String, int>{};
    for (final u in users.where((u) => u.isSecretary)) {
      out[u.id] = await db.countAssignedMembers(u.id);
    }
    return out;
  }
}
