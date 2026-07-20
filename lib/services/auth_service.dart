import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/role_definition.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';
import 'password_hasher.dart';

class AuthUser {
  final String id;
  final String displayName;
  final String? email;
  final String username;
  final String role;

  const AuthUser({
    required this.id,
    required this.displayName,
    this.email,
    required this.username,
    required this.role,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  bool get isSystemAdministrator => id == 'demo-admin';
}

class AuthService {
  AuthService(this._db);

  final DatabaseService _db;

  static const _prefsUserKey = 'gtc_logged_in_user';
  static const _prefsNameKey = 'gtc_display_name';
  static const _prefsRoleKey = 'gtc_role';
  static const _prefsUsernameKey = 'gtc_username';

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsNameKey);
    final id = prefs.getString(_prefsUserKey);
    final role = prefs.getString(_prefsRoleKey);
    final username = prefs.getString(_prefsUsernameKey);
    if (name != null && id != null) {
      _currentUser = AuthUser(
        id: id,
        displayName: name,
        username: username ?? name,
        role: role ?? 'User',
      );
    }
  }

  Future<AuthUser> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    final trimmed = usernameOrEmail.trim();

    if (FirebaseBootstrap.ready) {
      try {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: trimmed,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          throw Exception('Authentication failed.');
        }
        final local = await _db.getAppUserByUsername(trimmed.toLowerCase());
        final displayName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (local?.displayName ?? user.email ?? trimmed);
        final authUser = AuthUser(
          id: user.uid,
          displayName: displayName,
          email: user.email,
          username: local?.username ?? trimmed.toLowerCase(),
          role: local?.role ?? 'User',
        );
        await _persist(authUser);
        return authUser;
      } on FirebaseAuthException catch (error) {
        debugPrint('FirebaseAuth error: ${error.code}');
      }
    }

    final operator = await _db.getAppUserByUsername(trimmed.toLowerCase());
    if (operator != null &&
        operator.active &&
        !operator.deleted &&
        PasswordHasher.verify(password, operator.passwordHash)) {
      final authUser = AuthUser(
        id: operator.id,
        displayName: operator.displayName,
        email: null,
        username: operator.username,
        role: operator.role,
      );
      await _persist(authUser);
      return authUser;
    }

    if (trimmed.toLowerCase() == AppConstants.demoUsername &&
        password == AppConstants.demoPassword) {
      await _db.ensureSeedAdmin();
      final seeded = await _db.getAppUserByUsername(AppConstants.demoUsername);
      if (seeded != null) {
        final authUser = AuthUser(
          id: seeded.id,
          displayName: seeded.displayName,
          username: seeded.username,
          role: seeded.role,
        );
        await _persist(authUser);
        return authUser;
      }
    }

    throw Exception(
      'Invalid credentials. Contact an Admin for an operator account.',
    );
  }

  Future<AppUser> createOperator({
    required String username,
    required String displayName,
    required String password,
    required String role,
  }) async {
    _requireAdmin();
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final roleName = role.trim();
    if (roleName.isEmpty) {
      throw Exception('Rights / Role is required.');
    }

    final existing = await _db.getAppUserByUsername(normalized);
    if (existing != null && !existing.deleted) {
      throw Exception('Username "$normalized" already exists.');
    }

    final user = AppUser.create(
      username: normalized,
      displayName: displayName.trim().isEmpty ? normalized : displayName.trim(),
      passwordHash: PasswordHasher.hash(password),
      role: roleName,
    );
    await _db.upsertAppUser(user);
    return user;
  }

  Future<AppUser> updateOperator({
    required String id,
    required String displayName,
    required String role,
    String? newPassword,
    String? username,
  }) async {
    _requireAdmin();
    final user = await _db.getAppUserById(id);
    if (user == null) {
      throw Exception('User not found.');
    }

    final actor = _currentUser;
    final editingSysAdmin = user.isSystemAdministrator;
    final actorIsSysAdmin = actor?.isSystemAdministrator == true;

    // Other users may not change System Administrator role or password.
    if (editingSysAdmin && !actorIsSysAdmin) {
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        throw Exception(
          'Only the System Administrator can change that password.',
        );
      }
      if (role.trim().toLowerCase() != 'admin') {
        throw Exception(
          'System Administrator role cannot be changed by other users.',
        );
      }
      if (username != null &&
          username.trim().toLowerCase() != user.username) {
        throw Exception(
          'Only the System Administrator can change that username.',
        );
      }
    }

    var roleName = role.trim();
    if (roleName.isEmpty) {
      throw Exception('Rights / Role is required.');
    }

    // System Administrator must remain Admin.
    if (editingSysAdmin) {
      roleName = 'Admin';
    }

    // Password change on System Administrator: only the SysAdmin themselves.
    String? passwordHash;
    if (newPassword != null && newPassword.trim().isNotEmpty) {
      if (editingSysAdmin && !actorIsSysAdmin) {
        throw Exception(
          'Only the System Administrator can change that password.',
        );
      }
      if (newPassword.trim().length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }
      passwordHash = PasswordHasher.hash(newPassword.trim());
    }

    var nextUsername = user.username;
    if (username != null && username.trim().isNotEmpty) {
      final normalized = username.trim().toLowerCase();
      if (normalized != user.username) {
        if (editingSysAdmin && !actorIsSysAdmin) {
          throw Exception(
            'Only the System Administrator can change that username.',
          );
        }
        final clash = await _db.getAppUserByUsername(normalized);
        if (clash != null && clash.id != id && !clash.deleted) {
          throw Exception('Username "$normalized" already exists.');
        }
        nextUsername = normalized;
      }
    }

    final resolvedName = displayName.trim().isEmpty
        ? (user.displayName.isEmpty ? nextUsername : user.displayName)
        : displayName.trim();

    var updated = user.copyWith(
      username: nextUsername,
      displayName: resolvedName.isEmpty ? nextUsername : resolvedName,
      role: roleName,
      pendingSync: true,
      updatedAt: DateTime.now().toUtc(),
    );
    if (passwordHash != null) {
      updated = updated.copyWith(passwordHash: passwordHash);
    }
    await _db.upsertAppUser(updated);

    // Keep live session in sync when editing self.
    if (actor != null && actor.id == updated.id) {
      await _persist(
        AuthUser(
          id: updated.id,
          displayName: updated.displayName,
          email: actor.email,
          username: updated.username,
          role: updated.role,
        ),
      );
    }

    return updated;
  }

  Future<List<AppUser>> listOperators() => _db.getAppUsers();

  Future<void> setOperatorActive(String id, bool active) async {
    _requireAdmin();
    final user = await _db.getAppUserById(id);
    if (user == null) return;

    if (!active && (user.isAdmin || user.isSystemAdministrator)) {
      throw Exception(
        'Admin / System Administrator cannot be deactivated.',
      );
    }

    await _db.upsertAppUser(
      user.copyWith(
        active: active,
        pendingSync: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> softDeleteOperator(String id) async {
    _requireAdmin();
    if (id == _currentUser!.id) {
      throw Exception('You cannot delete your own account.');
    }
    final user = await _db.getAppUserById(id);
    if (user != null && (user.isAdmin || user.isSystemAdministrator)) {
      throw Exception(
        'Admin / System Administrator cannot be deleted.',
      );
    }
    await _db.softDeleteAppUser(id);
  }

  // ── Rights / Role CRUD ─────────────────────────────────────────────────

  Future<List<RoleDefinition>> listRoles() => _db.getRoles();

  Future<RoleDefinition> addRole(String name) async {
    _requireAdmin();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Role name is required.');
    }
    final existing = await _db.getRoleByName(trimmed);
    if (existing != null && !existing.deleted) {
      throw Exception('Role "$trimmed" already exists.');
    }
    final role = RoleDefinition.create(
      name: trimmed,
      grantsAdmin: trimmed.toLowerCase() == 'admin',
    );
    await _db.upsertRole(role);
    return role;
  }

  Future<RoleDefinition> editRole({
    required String id,
    required String name,
  }) async {
    _requireAdmin();
    final role = await _db.getRoleById(id);
    if (role == null) {
      throw Exception('Role not found.');
    }
    if (role.isSystem && role.isAdminRole) {
      throw Exception('The Admin system role cannot be renamed.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Role name is required.');
    }
    final clash = await _db.getRoleByName(trimmed);
    if (clash != null && clash.id != id && !clash.deleted) {
      throw Exception('Role "$trimmed" already exists.');
    }

    final oldName = role.name;
    final updated = role.copyWith(
      name: trimmed,
      pendingSync: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await _db.upsertRole(updated);

    // Rename role on operators that used the old name.
    final users = await _db.getAppUsers();
    for (final user in users) {
      if (user.role == oldName) {
        await _db.upsertAppUser(
          user.copyWith(
            role: trimmed,
            pendingSync: true,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
    return updated;
  }

  Future<void> deleteRole(String id) async {
    _requireAdmin();
    final role = await _db.getRoleById(id);
    if (role == null) return;
    if (role.isSystem || role.isAdminRole) {
      throw Exception('System / Admin role cannot be deleted.');
    }

    final users = await _db.getAppUsers();
    final inUse = users.any((u) => u.role == role.name);
    if (inUse) {
      throw Exception(
        'Role "${role.name}" is assigned to users. Reassign them first.',
      );
    }
    await _db.softDeleteRole(id);
  }

  void _requireAdmin() {
    if (_currentUser == null || !_currentUser!.isAdmin) {
      throw Exception('Only Admin can manage users and roles.');
    }
  }

  Future<void> signOut() async {
    if (FirebaseBootstrap.ready) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUserKey);
    await prefs.remove(_prefsNameKey);
    await prefs.remove(_prefsRoleKey);
    await prefs.remove(_prefsUsernameKey);
    _currentUser = null;
  }

  Future<void> _persist(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserKey, user.id);
    await prefs.setString(_prefsNameKey, user.displayName);
    await prefs.setString(_prefsRoleKey, user.role);
    await prefs.setString(_prefsUsernameKey, user.username);
    _currentUser = user;
  }
}
