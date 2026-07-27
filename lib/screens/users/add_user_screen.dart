import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/member.dart';
import '../../models/user_role.dart';
import '../../providers/providers.dart';

/// Admin-only User Manager: Recording Secretary rights + RS list (black theme).
///
/// // MODIFIED - Assign Roles form removed; RS rights + list redesign.
class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  static const _bg = Color(0xFF0A0A0A);
  static const _panel = Color(0xFF141414);
  static const _selectedRed = Color(0xFFB71C1C);

  String _searchQuery = '';
  AppUser? _selectedSecretary;
  final Set<AppPermission> _draftPerms = {};
  bool _saving = false;
  bool _dirty = false;
  // Cache assigned-count future so rebuilds do not restart FutureBuilder.
  // NEW ADDITION - counts cache (Delete fields to revert)
  String? _countsKey;
  Future<Map<String, int>>? _countsFuture;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(authUserProvider);
    final usersAsync = ref.watch(appUsersProvider);
    final membersAsync = ref.watch(membersProvider);

    if (current == null || !current.isAdmin) {
      return const Center(
        child: Text(
          'Admin access required.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ColoredBox(
      color: _bg,
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
        data: (users) {
          final members = membersAsync.valueOrNull ?? const <Member>[];
          final secretaries =
              users.where((u) => !u.deleted && u.isSecretary).toList()
                ..sort(
                  (a, b) => a.displayName
                      .toLowerCase()
                      .compareTo(b.displayName.toLowerCase()),
                );

          final q = _searchQuery.trim().toLowerCase();
          final filtered = q.isEmpty
              ? secretaries
              : secretaries.where((u) {
                  final m = _memberOf(u, members);
                  final hay = [
                    u.displayName,
                    u.username,
                    m?.saId ?? '',
                    m?.memberName ?? '',
                    m?.surname ?? '',
                  ].join(' ').toLowerCase();
                  return hay.contains(q);
                }).toList();

          // Keep / initialize selection
          final selected = _resolveSelected(filtered);

          final admins = users.where((u) => !u.deleted && u.isAdmin).length;
          final memberUsers =
              users.where((u) => !u.deleted && u.isMemberRole).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerBar(
                total: users.where((u) => !u.deleted).length,
                admins: admins,
                secretaries: secretaries.length,
                members: memberUsers,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final rights = _buildRightsPanel(selected, members);
                    final list = _buildSecretaryList(filtered, members, selected);
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: rights),
                          Container(width: 1, color: Colors.grey.shade800),
                          Expanded(flex: 2, child: list),
                        ],
                      );
                    }
                    return ListView(
                      children: [
                        SizedBox(height: 420, child: rights),
                        Divider(color: Colors.grey.shade800, height: 1),
                        SizedBox(height: 360, child: list),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  AppUser? _resolveSelected(List<AppUser> filtered) {
    if (filtered.isEmpty) {
      if (_selectedSecretary != null || _draftPerms.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _selectedSecretary = null;
            _draftPerms.clear();
            _dirty = false;
          });
        });
      }
      return null;
    }

    // Keep current selection if still visible — never reset draft here.
    if (_selectedSecretary != null) {
      for (final u in filtered) {
        if (u.id == _selectedSecretary!.id) return u;
      }
    }

    final first = filtered.first;
    // Auto-select once. Do NOT wipe drafts if admin already toggled rights
    // before post-frame init (that was the Save-does-nothing bug).
    // MODIFIED - preserve dirty draft on auto-select (Delete block to revert)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedSecretary != null) {
        final stillVisible =
            filtered.any((u) => u.id == _selectedSecretary!.id);
        if (stillVisible) return;
        if (_dirty) {
          // Filtered out while dirty — keep draft, rebind to first without wipe.
          setState(() => _selectedSecretary = first);
          return;
        }
        _selectSecretary(first);
        return;
      }
      if (_dirty) {
        setState(() => _selectedSecretary = first);
        return;
      }
      _selectSecretary(first);
    });
    return _selectedSecretary?.id == first.id ? _selectedSecretary : first;
  }

  void _selectSecretary(AppUser user) {
    setState(() {
      _selectedSecretary = user;
      _draftPerms
        ..clear()
        ..addAll(AppPermission.mergeSecretaryPermissions(user.permissions));
      _dirty = false;
    });
  }

  Member? _memberOf(AppUser u, List<Member> members) {
    if (u.memberId != null) {
      for (final m in members) {
        if (m.id == u.memberId) return m;
      }
    }
    for (final m in members) {
      if (m.saId.toLowerCase() == u.username.toLowerCase()) return m;
    }
    return null;
  }

  Widget _headerBar({
    required int total,
    required int admins,
    required int secretaries,
    required int members,
  }) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'RECORDING SECRETARY RIGHTS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            'Total: $total  |  Admins: $admins  |  '
            'Secretaries: $secretaries  |  Members: $members',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Refresh',
            color: Colors.white,
            onPressed: () {
              ref.invalidate(appUsersProvider);
              ref.invalidate(membersProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildRightsPanel(AppUser? selected, List<Member> members) {
    final name = selected == null
        ? 'Select a Recording Secretary'
        : 'Editing: ${selected.displayName}';

    return Container(
      color: _panel,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECORDING SECRETARY RIGHTS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          if (selected == null)
            Expanded(
              child: Center(
                child: Text(
                  'Select a Recording Secretary from the list',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ),
            )
          else
            Expanded(child: _buildPermissionToggles()),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  // Always allow save when a secretary is selected (not only when dirty).
                  // MODIFIED - enable Save whenever selected (Delete to revert)
                  onPressed: _saving
                      ? null
                      : () => _savePermissions(selected),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save Permissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionToggles() {
    return ListView(
      children: AppPermission.managementOrder.map((permission) {
        final adminOnly = permission.isAdminOnly;
        final required = permission.isRequiredForSecretary;
        final checked = adminOnly
            ? false
            : (required || _draftPerms.contains(permission));
        final enabled = !adminOnly && !required;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: checked
                ? Colors.green.shade900.withValues(alpha: 0.35)
                : Colors.grey.shade900.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: checked ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  permission.label,
                  style: TextStyle(
                    color: adminOnly ? Colors.grey.shade500 : Colors.white,
                    fontWeight:
                        required ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (adminOnly)
                _badge('Admin Only', Colors.blue)
              else if (required)
                _badge('Required', Colors.red)
              else
                _badge('Optional', Colors.green),
              const SizedBox(width: 8),
              Switch(
                value: checked,
                onChanged: enabled
                    ? (value) {
                        setState(() {
                          if (value) {
                            _draftPerms.add(permission);
                          } else {
                            _draftPerms.remove(permission);
                          }
                          _dirty = true;
                        });
                      }
                    : null,
                activeThumbColor: Colors.green,
                activeTrackColor: Colors.green.shade700,
                inactiveTrackColor: Colors.grey.shade700,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _badge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color.shade200,
        ),
      ),
    );
  }

  Widget _buildSecretaryList(
    List<AppUser> filtered,
    List<Member> members,
    AppUser? selected,
  ) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search Recording Secretaries…',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 16),
          Text(
            'RECORDING SECRETARIES (${filtered.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No Recording Secretaries found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : FutureBuilder<Map<String, int>>(
                    future: _assignedCountsFuture(filtered),
                    builder: (context, snap) {
                      final counts = snap.data ?? const <String, int>{};
                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          final isSelected = selected?.id == user.id;
                          final m = _memberOf(user, members);
                          final saId = m?.saId ?? user.username;
                          final permCount = user.permissions.length;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _selectedRed
                                  : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.red.shade400
                                    : Colors.grey.shade700,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _selectSecretary(user),
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? Colors.red.shade400
                                    : Colors.grey.shade700,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.displayName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SA ID: $saId',
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Assigned: ${counts[user.id] ?? 0} members',
                                    style: TextStyle(
                                      color: Colors.green.shade300,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$permCount/11',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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

  Future<Map<String, int>> _assignedCountsFuture(List<AppUser> users) {
    final key = users.map((u) => u.id).join('|');
    if (_countsKey != key || _countsFuture == null) {
      _countsKey = key;
      _countsFuture = _loadAssignedCounts(users);
    }
    return _countsFuture!;
  }

  Future<Map<String, int>> _loadAssignedCounts(List<AppUser> users) async {
    final db = ref.read(databaseServiceProvider);
    final out = <String, int>{};
    for (final u in users) {
      out[u.id] = await db.countAssignedMembers(u.id);
    }
    return out;
  }

  Future<void> _savePermissions(AppUser secretary) async {
    setState(() => _saving = true);
    try {
      // Ensure draft includes required rights even if UI never toggled them.
      final perms = AppPermission.mergeSecretaryPermissions(_draftPerms);
      debugPrint(
        'Saving permissions for ${secretary.displayName}: '
        '${perms.map((p) => p.label).join(', ')}',
      );

      // Persist by AppUser id — works even when memberId is null.
      // MODIFIED - use updateSecretaryPermissions (Delete to revert)
      final saved =
          await ref.read(authServiceProvider).updateSecretaryPermissions(
                userId: secretary.id,
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
      if (!mounted) return;
      setState(() {
        _selectedSecretary = saved;
        _draftPerms
          ..clear()
          ..addAll(AppPermission.mergeSecretaryPermissions(saved.permissions));
        _dirty = false;
        _countsKey = null;
        _countsFuture = null;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '✅ Permissions updated for ${saved.displayName}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
    } catch (e) {
      debugPrint('Error saving permissions: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('❌ Error saving permissions: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
