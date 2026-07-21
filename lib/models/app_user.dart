import 'package:uuid/uuid.dart';

import 'user_role.dart';

class AppUser {
  final String id;
  final String username;
  final String displayName;
  final String passwordHash;
  /// Storage: Admin | Recording Secretary | Member
  final String role;
  /// Linked member profile id (optional).
  final String? memberId;
  /// Recording Secretary module rights (comma-separated AppPermission codes).
  final String permissionsRaw;
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
    this.memberId,
    this.permissionsRaw = '',
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
    this.active = true,
  });

  UserRole get userRole => UserRole.fromStorage(role);

  List<AppPermission> get permissions =>
      AppPermission.parseList(permissionsRaw);

  bool get isAdmin => userRole.isAdmin;

  bool get isSecretary => userRole.isSecretary;

  bool get isMemberRole => userRole.isMember;

  /// Stable System Administrator account (id demo-admin).
  bool get isSystemAdministrator => id == 'demo-admin';

  bool hasPermission(AppPermission permission) {
    if (isAdmin) return true;
    if (permission.isAdminOnly) return false;
    if (isMemberRole) {
      return permission == AppPermission.memberInfo;
    }
    return permissions.contains(permission);
  }

  factory AppUser.create({
    required String username,
    required String displayName,
    required String passwordHash,
    required String role,
    String? memberId,
    List<AppPermission> permissions = const [],
  }) {
    return AppUser(
      id: const Uuid().v4(),
      username: username.trim().toLowerCase(),
      displayName: displayName.trim(),
      passwordHash: passwordHash,
      role: role.trim(),
      memberId: memberId,
      permissionsRaw: AppPermission.encodeList(permissions),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? displayName,
    String? passwordHash,
    String? role,
    String? memberId,
    String? permissionsRaw,
    List<AppPermission>? permissions,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool? active,
    bool clearMemberId = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      permissionsRaw: permissions != null
          ? AppPermission.encodeList(permissions)
          : (permissionsRaw ?? this.permissionsRaw),
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
      'memberId': memberId,
      'permissions': permissionsRaw,
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
      'memberId': memberId,
      'permissions': permissionsRaw,
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
      role: map['role'] as String? ?? UserRole.member.storageName,
      memberId: map['memberId'] as String?,
      permissionsRaw: map['permissions'] as String? ?? '',
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
      role: map['role'] as String? ?? UserRole.member.storageName,
      memberId: map['memberId'] as String?,
      permissionsRaw: map['permissions'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
      active: map['active'] as bool? ?? true,
    );
  }
}
