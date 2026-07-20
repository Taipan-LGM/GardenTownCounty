import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';

class AppUser {
  final String id;
  final String username;
  final String displayName;
  final String passwordHash;
  /// Rights / Role name (e.g. Admin, Manager, Supervisor, User, or custom).
  final String role;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;
  final bool active;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.passwordHash,
    required this.role,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
    this.active = true,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  bool get isSystemAdministrator =>
      id == 'demo-admin' ||
      username.toLowerCase() == AppConstants.demoUsername;

  factory AppUser.create({
    required String username,
    required String displayName,
    required String passwordHash,
    required String role,
  }) {
    return AppUser(
      id: const Uuid().v4(),
      username: username.trim().toLowerCase(),
      displayName: displayName.trim(),
      passwordHash: passwordHash,
      role: role.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? displayName,
    String? passwordHash,
    String? role,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool? active,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'passwordHash': passwordHash,
      'role': role,
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
      'active': active ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'passwordHash': passwordHash,
      'role': role,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
      'active': active,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      passwordHash: map['passwordHash'] as String? ?? '',
      role: map['role'] as String? ?? 'User',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      active: (map['active'] as int? ?? 1) == 1,
    );
  }

  factory AppUser.fromFirestore(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      passwordHash: map['passwordHash'] as String? ?? '',
      role: map['role'] as String? ?? 'User',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
      active: map['active'] as bool? ?? true,
    );
  }
}
