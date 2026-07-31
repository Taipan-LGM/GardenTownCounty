import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/role_definition.dart';
import '../models/user_role.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';
import 'password_hasher.dart';

class AuthUser {
  final String id;
  final String displayName;
  final String? email;
  final String username;
  final String role;
  final String? memberId;
  final List<AppPermission> permissions;

  const AuthUser({
    required this.id,
    required this.displayName,
    this.email,
    required this.username,
    required this.role,
    this.memberId,
    this.permissions = const [],
  });

  UserRole get userRole => UserRole.fromStorage(role);

  bool get isAdmin => userRole.isAdmin;

  bool get isSecretary => userRole.isSecretary;

  bool get isMemberRole => userRole.isMember;

  bool get isSystemAdministrator => id == 'demo-admin';

  bool hasPermission(AppPermission permission) {
    if (isAdmin) return true;
    if (permission.isAdminOnly) return false;
    if (isMemberRole) {
      return permission == AppPermission.memberInfo;
    }
    return permissions.contains(permission);
  }

  factory AuthUser.fromAppUser(AppUser user, {String? email}) {
    return AuthUser(
      id: user.id,
      displayName: user.displayName,
      email: email,
      username: user.username,
      role: user.role,
      memberId: user.memberId,
      permissions: user.permissions,
    );
  }
}

class AuthService {
  AuthService(this._db);

  final DatabaseService _db;

  static const _prefsUserKey = 'gtc_logged_in_user';
  static const _prefsNameKey = 'gtc_display_name';
  static const _prefsRoleKey = 'gtc_role';
  static const _prefsUsernameKey = 'gtc_username';
  static const _prefsPermissionsKey = 'gtc_permissions';
  static const _prefsMemberIdKey = 'gtc_member_id';

  AuthUser? _currentUser;
  String? _currentCredentialHash;
  AuthUser? get currentUser => _currentUser;

  /// Restore a prior session only when the local user still exists and is active.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsUserKey);
    if (id == null || id.isEmpty) return;

    final local = await _db.getAppUserById(id);
    if (local == null || local.deleted || !local.active) {
      await signOut();
      return;
    }

    _currentUser = AuthUser.fromAppUser(
      local,
      email: prefs.getString(_prefsUsernameKey),
    );
    // Refresh prefs so permissions/role match SQLite.
    await _persist(_currentUser!);
  }

  /// Sign in.
  ///
  /// When Firebase is configured, authentication goes through Firebase Auth only
  /// (no silent fallback to local/demo credentials).
  /// When Firebase is offline/unconfigured, uses local SQLite operators
  /// (and the seeded admin account in debug builds).
  Future<AuthUser> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    final trimmed = usernameOrEmail.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required.');
    }

    final user = FirebaseBootstrap.ready
        ? await _signInWithFirebase(trimmed, password)
        : await _signInLocally(trimmed, password);
    _currentCredentialHash = PasswordHasher.hash(password);
    return user;
  }

  Future<AppUser> verifyPaymentAssistantCredentials({
    required String assistantId,
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw Exception('Username and password are required.');
    }

    final assistant = await _db.getAppUserById(assistantId);
    if (assistant == null ||
        assistant.deleted ||
        !assistant.active ||
        (!assistant.isSecretary && !assistant.isAdmin)) {
      throw Exception('The selected payment assistant account is unavailable.');
    }
    final usernameMatches =
      assistant.username.toLowerCase() == username.trim().toLowerCase();
    final sessionCredentialMatches = _currentUser?.id == assistant.id &&
      _currentCredentialHash != null &&
      PasswordHasher.verify(password, _currentCredentialHash!);
    final storedCredentialMatches =
      PasswordHasher.verify(password, assistant.passwordHash);
    if (!usernameMatches ||
      (!sessionCredentialMatches && !storedCredentialMatches)) {
      throw Exception('Invalid credentials for ${assistant.displayName}.');
    }

    if (storedCredentialMatches) {
      await _maybeUpgradePasswordHash(assistant, password);
    }
    return assistant;
  }

  Future<AuthUser> _signInWithFirebase(
    String usernameOrEmail,
    String password,
  ) async {
    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: usernameOrEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw Exception('Authentication failed.');
      }

      // Prefer local profile by email/username, then by Firebase uid.
      final emailKey = (user.email ?? usernameOrEmail).trim().toLowerCase();
      var local = await _db.getAppUserByUsername(emailKey);
      local ??= await _db.getAppUserById(user.uid);

      final displayName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (local?.displayName ?? user.email ?? usernameOrEmail);

      final authUser = local != null
          ? AuthUser.fromAppUser(local, email: user.email)
          : AuthUser(
              id: user.uid,
              displayName: displayName,
              email: user.email,
              username: emailKey,
              role: UserRole.member.storageName,
            );
      await _persist(authUser);
      return authUser;
    } on FirebaseAuthException catch (error) {
      debugPrint('FirebaseAuth error: ${error.code}');
      throw Exception(_friendlyFirebaseMessage(error.code));
    }
  }

  Future<AuthUser> _signInLocally(
    String usernameOrEmail,
    String password,
  ) async {
    final operator =
        await _db.getAppUserByUsername(usernameOrEmail.toLowerCase());
    if (operator != null &&
        operator.active &&
        !operator.deleted &&
        PasswordHasher.verify(password, operator.passwordHash)) {
      await _maybeUpgradePasswordHash(operator, password);
      final authUser = AuthUser.fromAppUser(operator);
      await _persist(authUser);
      return authUser;
    }

    // Explicit demo login is disabled outside a trusted development context.
    // The app should require a real operator account instead of silently
    // authenticating with the seeded admin credentials.
    if (kDebugMode &&
        usernameOrEmail.toLowerCase() == AppConstants.demoUsername &&
        password == AppConstants.demoPassword) {
      await _db.ensureSeedAdmin();
      final seeded =
          await _db.getAppUserByUsername(AppConstants.demoUsername);
      if (seeded != null &&
          PasswordHasher.verify(password, seeded.passwordHash)) {
        await _maybeUpgradePasswordHash(seeded, password);
        final authUser = AuthUser.fromAppUser(seeded);
        await _persist(authUser);
        return authUser;
      }
    }

    throw Exception(
      'Invalid credentials. Contact an Admin for an operator account.',
    );
  }

  Future<void> _maybeUpgradePasswordHash(AppUser user, String password) async {
    if (!PasswordHasher.needsRehash(user.passwordHash)) return;
    await _db.upsertAppUser(
      user.copyWith(
        passwordHash: PasswordHasher.hash(password),
        pendingSync: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  String _friendlyFirebaseMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed ($code).';
    }
  }

  String _normalizeRole(String role) =>
      UserRole.fromStorage(role).storageName;

  /// User Management: assign role/permissions to a Member (no password / login).
  Future<AppUser> assignMemberAccess({
    required String memberId,
    required String saId,
    required String memberName,
    required String surname,
    required String role,
    List<AppPermission> permissions = const [],
  }) async {
    _requireAdmin();
    final member = await _db.getMemberById(memberId);
    if (member == null) {
      throw Exception('Member not found.');
    }

    final adminUser = await _db.getAppUserById('demo-admin');
    if (adminUser?.memberId == memberId ||
        (adminUser != null &&
            adminUser.username == saId.trim().toLowerCase())) {
      throw Exception('⚠️ The System Administrator cannot be demoted.');
    }

    final roleName = _normalizeRole(role);
    if (roleName == UserRole.admin.storageName) {
      throw Exception(
        'Cannot create another Admin. Only one System Administrator exists.',
      );
    }

    final byMember = await _db.getAppUserByMemberId(memberId);
    final bySa = await _db.getAppUserByUsername(saId.trim().toLowerCase());
    final existing = byMember ?? bySa;

    final safePerms = roleName == UserRole.secretary.storageName
        ? AppPermission.mergeSecretaryPermissions(permissions)
        : const <AppPermission>[];

    final display =
        '$memberName $surname'.trim().isEmpty ? saId.trim() : '$memberName $surname'.trim();

    if (existing != null && !existing.deleted) {
      if (existing.isSystemAdministrator) {
        throw Exception('⚠️ The System Administrator cannot be demoted.');
      }
      final updated = existing.copyWith(
        username: saId.trim().toLowerCase(),
        displayName: display,
        role: roleName,
        memberId: memberId,
        permissions: safePerms,
        pendingSync: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _db.upsertAppUser(updated);
      await _linkMemberUserId(memberId, updated.id);
      return updated;
    }

    final user = AppUser.create(
      username: saId.trim().toLowerCase(),
      displayName: display,
      passwordHash: PasswordHasher.hash('__user_mgmt_no_login__'),
      role: roleName,
      memberId: memberId,
      permissions: safePerms,
    );
    await _db.upsertAppUser(user);
    await _linkMemberUserId(memberId, user.id);
    return user;
  }

  Future<void> _linkMemberUserId(String memberId, String appUserId) async {
    final member = await _db.getMemberById(memberId);
    if (member == null) return;
    await _db.upsertMember(
      member.copyWith(
        userId: appUserId,
        pendingSync: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Demote Recording Secretary to Member (clear rights) or soft-delete Member access.
  Future<void> removeMemberAccess(String appUserId) async {
    _requireAdmin();
    if (appUserId == _currentUser!.id) {
      throw Exception('You cannot delete your own account.');
    }
    final user = await _db.getAppUserById(appUserId);
    if (user == null) {
      throw Exception('User not found.');
    }
    if (user.isSystemAdministrator || user.isAdmin) {
      throw Exception(
        'The System Administrator cannot be deleted. This account is protected.',
      );
    }
    if (user.isSecretary) {
      await _db.upsertAppUser(
        user.copyWith(
          role: UserRole.member.storageName,
          permissions: const [],
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return;
    }
    if (user.memberId != null) {
      final member = await _db.getMemberById(user.memberId!);
      if (member != null) {
        await _db.upsertMember(
          member.copyWith(
            clearUserId: true,
            pendingSync: true,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
    await _db.softDeleteAppUser(appUserId);
  }

  Future<AppUser> createOperator({
    required String username,
    required String displayName,
    required String password,
    required String role,
    List<AppPermission> permissions = const [],
    String? memberId,
  }) async {
    _requireAdmin();
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final roleName = _normalizeRole(role);
    if (roleName == UserRole.admin.storageName) {
      throw Exception(
        'Cannot create another Admin. Only one System Administrator exists.',
      );
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
      memberId: memberId,
      permissions: roleName == UserRole.secretary.storageName
          ? permissions
          : const [],
    );
    await _db.upsertAppUser(user);
    return user;
  }

  Future<AppUser> updateSecretaryPermissions({
    required String userId,
    required List<AppPermission> permissions,
  }) async {
    _requireAdmin();
    final user = await _db.getAppUserById(userId);
    if (user == null || user.deleted) {
      throw Exception('Recording Secretary not found.');
    }
    if (!user.isSecretary) {
      throw Exception('Permissions can only be edited for Recording Secretaries.');
    }
    if (user.isSystemAdministrator) {
      throw Exception('⚠️ The System Administrator cannot be demoted.');
    }

    final safePerms = AppPermission.mergeSecretaryPermissions(permissions);
    final updated = user.copyWith(
      permissions: safePerms,
      pendingSync: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await _db.upsertAppUser(updated);

    final actor = _currentUser;
    if (actor != null && actor.id == updated.id) {
      await _persist(AuthUser.fromAppUser(updated, email: actor.email));
    }
    return updated;
  }

  Future<AppUser> updateOperator({
    required String id,
    required String displayName,
    required String role,
    String? newPassword,
    String? username,
    List<AppPermission>? permissions,
    String? memberId,
    bool clearMemberId = false,
  }) async {
    _requireAdmin();
    final user = await _db.getAppUserById(id);
    if (user == null) {
      throw Exception('User not found.');
    }

    final actor = _currentUser;
    final editingSysAdmin = user.isSystemAdministrator;
    final actorIsSysAdmin = actor?.isSystemAdministrator == true;

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

    var roleName = _normalizeRole(role);
    if (roleName.isEmpty) {
      throw Exception('Rights / Role is required.');
    }

    if (editingSysAdmin) {
      roleName = UserRole.admin.storageName;
    }

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

    final resolvedPermissions = roleName == UserRole.secretary.storageName
        ? (permissions ?? user.permissions)
        : const <AppPermission>[];

    var updated = user.copyWith(
      username: nextUsername,
      displayName: resolvedName.isEmpty ? nextUsername : resolvedName,
      role: roleName,
      memberId: memberId,
      clearMemberId: clearMemberId,
      permissions: resolvedPermissions,
      pendingSync: true,
      updatedAt: DateTime.now().toUtc(),
    );
    if (passwordHash != null) {
      updated = updated.copyWith(passwordHash: passwordHash);
    }
    await _db.upsertAppUser(updated);

    if (actor != null && actor.id == updated.id) {
      await _persist(AuthUser.fromAppUser(updated, email: actor.email));
      if (passwordHash != null) {
        _currentCredentialHash = PasswordHasher.hash(newPassword!.trim());
      }
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
    if (user != null && user.isSystemAdministrator) {
      throw Exception(
        'The System Administrator cannot be deleted. This account is protected.',
      );
    }
    if (user != null && user.isAdmin) {
      throw Exception(
        'Admin / System Administrator cannot be deleted.',
      );
    }
    await _db.softDeleteAppUser(id);
  }

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
    await prefs.remove(_prefsPermissionsKey);
    await prefs.remove(_prefsMemberIdKey);
    await prefs.remove('gtc_backup_password');
    _currentUser = null;
    _currentCredentialHash = null;
  }

  Future<void> _persist(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserKey, user.id);
    await prefs.setString(_prefsNameKey, user.displayName);
    await prefs.setString(_prefsRoleKey, user.role);
    await prefs.setString(_prefsUsernameKey, user.username);
    await prefs.setString(
      _prefsPermissionsKey,
      AppPermission.encodeList(user.permissions),
    );
    if (user.memberId != null) {
      await prefs.setString(_prefsMemberIdKey, user.memberId!);
    } else {
      await prefs.remove(_prefsMemberIdKey);
    }
    _currentUser = user;
  }
}
