import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';
import 'password_hasher.dart';

class AuthUser {
  final String id;
  final String displayName;
  final String? email;
  final String username;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.displayName,
    this.email,
    required this.username,
    required this.role,
  });

  bool get isAdmin => role.isAdmin;
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
        role: UserRoleX.fromStorage(role),
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
          role: local?.role ?? UserRole.user,
        );
        await _persist(authUser);
        return authUser;
      } on FirebaseAuthException catch (error) {
        debugPrint('FirebaseAuth error: ${error.code}');
        // Fall through to local operator login.
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

    // Bootstrap fallback if seed somehow missing.
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
    required UserRole role,
  }) async {
    final current = _currentUser;
    if (current == null || !current.isAdmin) {
      throw Exception('Only Admin can add users.');
    }

    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Username is required.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final existing = await _db.getAppUserByUsername(normalized);
    if (existing != null && !existing.deleted) {
      throw Exception('Username "$normalized" already exists.');
    }

    final user = AppUser.create(
      username: normalized,
      displayName: displayName.trim().isEmpty ? normalized : displayName.trim(),
      passwordHash: PasswordHasher.hash(password),
      role: role,
    );
    await _db.upsertAppUser(user);
    return user;
  }

  Future<List<AppUser>> listOperators() => _db.getAppUsers();

  Future<void> setOperatorActive(String id, bool active) async {
    if (_currentUser == null || !_currentUser!.isAdmin) {
      throw Exception('Only Admin can manage users.');
    }
    final user = await _db.getAppUserById(id);
    if (user == null) return;
    await _db.upsertAppUser(
      user.copyWith(
        active: active,
        pendingSync: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> softDeleteOperator(String id) async {
    if (_currentUser == null || !_currentUser!.isAdmin) {
      throw Exception('Only Admin can manage users.');
    }
    if (id == _currentUser!.id) {
      throw Exception('You cannot delete your own account.');
    }
    await _db.softDeleteAppUser(id);
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
    await prefs.setString(_prefsRoleKey, user.role.storageKey);
    await prefs.setString(_prefsUsernameKey, user.username);
    _currentUser = user;
  }
}
