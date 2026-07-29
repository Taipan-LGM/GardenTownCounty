part of '../database_service.dart';

/// Lookup list and member file attachment persistence.
mixin _DbLookupsFiles on _DatabaseServiceBase {
  // ── Lookups ────────────────────────────────────────────────────────────

  Future<List<LookupItem>> getLookups(LookupType type) async {
    if (_memoryMode) {
      final list = _lookups.values
          .where((l) => !l.deleted && l.type == type)
          .toList()
        ..sort(
          (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
        );
      return list;
    }
    final rows = await db.query(
      'lookups',
      where: 'type = ? AND deleted = 0',
      whereArgs: [type.storageKey],
      orderBy: 'value COLLATE NOCASE ASC',
    );
    return rows.map(LookupItem.fromMap).toList();
  }

  Future<void> upsertLookup(LookupItem item) async {
    if (_memoryMode) {
      _lookups[item.id] = item;
      return;
    }
    await db.insert(
      'lookups',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteLookup(String id) async {
    if (_memoryMode) {
      final item = _lookups[id];
      if (item != null) {
        _lookups[id] = item.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'lookups',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LookupItem>> getPendingLookups() async {
    if (_memoryMode) {
      return _lookups.values.where((l) => l.pendingSync).toList();
    }
    final rows = await db.query('lookups', where: 'pendingSync = 1');
    return rows.map(LookupItem.fromMap).toList();
  }

  Future<void> markLookupSynced(String id) async {
    if (_memoryMode) {
      final item = _lookups[id];
      if (item != null) _lookups[id] = item.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lookups',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Member files ───────────────────────────────────────────────────────

  Future<List<MemberFile>> getFilesForMember(String memberId) async {
    if (_memoryMode) {
      final list = _files.values
          .where((f) => !f.deleted && f.memberId == memberId)
          .toList()
        ..sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
      return list;
    }
    final rows = await db.query(
      'member_files',
      where: 'memberId = ? AND deleted = 0',
      whereArgs: [memberId],
      orderBy: 'fileName COLLATE NOCASE ASC',
    );
    return rows.map(MemberFile.fromMap).toList();
  }

  Future<void> upsertMemberFile(MemberFile file) async {
    if (_memoryMode) {
      _files[file.id] = file;
      return;
    }
    await db.insert(
      'member_files',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteMemberFile(String id) async {
    if (_memoryMode) {
      final file = _files[id];
      if (file != null) {
        _files[id] = file.copyWith(deleted: true, pendingSync: true);
      }
      return;
    }
    await db.update(
      'member_files',
      {
        'deleted': 1,
        'pendingSync': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MemberFile>> getPendingMemberFiles() async {
    if (_memoryMode) {
      return _files.values
          .where((f) => f.pendingSync && !f.deleted)
          .toList();
    }
    final rows = await db.query(
      'member_files',
      where: 'pendingSync = 1 AND deleted = 0',
    );
    return rows.map(MemberFile.fromMap).toList();
  }

  Future<void> markMemberFileSynced(String id, {String? storageUrl}) async {
    if (_memoryMode) {
      final file = _files[id];
      if (file != null) {
        _files[id] = file.copyWith(
          pendingSync: false,
          storageUrl: storageUrl,
        );
      }
      return;
    }
    final values = <String, Object?>{'pendingSync': 0};
    if (storageUrl != null) {
      values['storageUrl'] = storageUrl;
    }
    await db.update(
      'member_files',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
