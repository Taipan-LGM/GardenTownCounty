import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import 'firebase_bootstrap.dart';

class AuthUser {
  final String id;
  final String displayName;
  final String? email;

  const AuthUser({
    required this.id,
    required this.displayName,
    this.email,
  });
}

class AuthService {
  AuthService();

  static const _prefsUserKey = 'gtc_logged_in_user';
  static const _prefsNameKey = 'gtc_display_name';

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsNameKey);
    final id = prefs.getString(_prefsUserKey);
    if (name != null && id != null) {
      _currentUser = AuthUser(id: id, displayName: name);
    }
  }

  Future<AuthUser> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    final trimmed = usernameOrEmail.trim();

    if (FirebaseBootstrap.ready) {
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: trimmed,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          throw Exception('Authentication failed.');
        }
        final displayName =
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (user.email ?? trimmed);
        final authUser = AuthUser(
          id: user.uid,
          displayName: displayName,
          email: user.email,
        );
        await _persist(authUser);
        return authUser;
      } on FirebaseAuthException catch (error) {
        debugPrint('FirebaseAuth error: ${error.code}');
        // Fall through to demo login for local development.
      }
    }

    if (trimmed.toLowerCase() == AppConstants.demoUsername &&
        password == AppConstants.demoPassword) {
      final authUser = const AuthUser(
        id: 'demo-admin',
        displayName: AppConstants.demoDisplayName,
        email: 'admin@gardentowncounty.local',
      );
      await _persist(authUser);
      return authUser;
    }

    throw Exception(
      'Invalid credentials. Use demo login '
      '${AppConstants.demoUsername} / ${AppConstants.demoPassword} '
      'or configure Firebase Auth.',
    );
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
    _currentUser = null;
  }

  Future<void> _persist(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserKey, user.id);
    await prefs.setString(_prefsNameKey, user.displayName);
    _currentUser = user;
  }
}
