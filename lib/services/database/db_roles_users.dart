part of '../database_service.dart';

/// Roles and app-user (operator) persistence.
mixin _DbRolesUsers on _DatabaseServiceBase {
  // ── Roles ──────────────────────────────────────────────────────────────

  Future<List<RoleDefinition>> getRoles() async {
    if (_memoryMode) {
      final list = _roles.values.where((r) => !r.deleted).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }
    final rows = await db.query(
      'roles',
      where: 'deleted = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(RoleDefinition.fromMap).toList();
  }

  Future<RoleDefinition?> getRoleById(String id) async {
    if (_memoryMode) {
      final role = _roles[id];
      if (role == null || role.deleted) return null;
      return role;
    }
    final rows = await db.query(
      'roles',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RoleDefinition.fromMap(rows.first);
  }

  Future<RoleDefinition?> getRoleByName(String name) async {
    final key = name.trim().toLowerCase();
    if (_memoryMode) {
      for (final role in _roles.values) {
        if (!role.deleted && role.name.toLowerCase() == key) return role;
      }
      return null;
    }
    final rows = await db.query(
      'roles',
      where: 'LOWER(name) = ? AND deleted = 0',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RoleDefinition.fromMap(rows.first);
  }

  Future<void> upsertRole(RoleDefinition role) async {
    if (_memoryMode) {
      _roles[role.id] = role;
      return;
    }
    await db.insert(
      'roles',
      role.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteRole(String id) async {
    if (_memoryMode) {
      final role = _roles[id];
      if (role != null) {
        _roles[id] = role.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'roles',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RoleDefinition>> getPendingRoles() async {
    if (_memoryMode) {
      return _roles.values.where((r) => r.pendingSync).toList();
    }
    final rows = await db.query('roles', where: 'pendingSync = 1');
    return rows.map(RoleDefinition.fromMap).toList();
  }

  Future<void> markRoleSynced(String id) async {
    if (_memoryMode) {
      final role = _roles[id];
      if (role != null) _roles[id] = role.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'roles',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── App users (operators) ──────────────────────────────────────────────

  @override
  Future<List<AppUser>> getAppUsers() async {
    if (_memoryMode) {
      final list = _appUsers.values.where((u) => !u.deleted).toList()
        ..sort(
          (a, b) =>
              a.username.toLowerCase().compareTo(b.username.toLowerCase()),
        );
      return list;
    }
    final rows = await db.query(
      'app_users',
      where: 'deleted = 0',
      orderBy: 'username COLLATE NOCASE ASC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  Future<AppUser?> getAppUserById(String id) async {
    if (_memoryMode) {
      final user = _appUsers[id];
      if (user == null || user.deleted) return null;
      return user;
    }
    final rows = await db.query(
      'app_users',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getAppUserByUsername(String username) async {
    final key = username.trim().toLowerCase();
    if (_memoryMode) {
      for (final user in _appUsers.values) {
        if (!user.deleted && user.username == key) return user;
      }
      return null;
    }
    final rows = await db.query(
      'app_users',
      where: 'username = ? AND deleted = 0',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<void> upsertAppUser(AppUser user) async {
    if (_memoryMode) {
      _appUsers[user.id] = user;
      return;
    }
    await db.insert(
      'app_users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> softDeleteAppUser(String id) async {
    if (_memoryMode) {
      final user = _appUsers[id];
      if (user != null) {
        _appUsers[id] = user.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'app_users',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AppUser>> getPendingAppUsers() async {
    if (_memoryMode) {
      return _appUsers.values.where((u) => u.pendingSync).toList();
    }
    final rows = await db.query('app_users', where: 'pendingSync = 1');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<void> markAppUserSynced(String id) async {
    if (_memoryMode) {
      final user = _appUsers[id];
      if (user != null) {
        _appUsers[id] = user.copyWith(pendingSync: false);
      }
      return;
    }
    await db.update(
      'app_users',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
