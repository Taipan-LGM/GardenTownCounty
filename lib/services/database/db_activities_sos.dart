part of '../database_service.dart';

/// Activity log and SOS preset persistence.
mixin _DbActivitiesSos on _DatabaseServiceBase {
  // ── Activities ─────────────────────────────────────────────────────────

  Future<List<ActivityLog>> getActivities() async {
    if (_memoryMode) {
      final list = _activities.values.toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return list;
    }
    final rows = await db.query(
      'activities',
      orderBy: 'occurredAt DESC',
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<void> insertActivity(ActivityLog activity) async {
    if (_memoryMode) {
      _activities[activity.id] = activity;
      return;
    }
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActivityLog>> getPendingActivities() async {
    if (_memoryMode) {
      return _activities.values.where((a) => a.pendingSync).toList();
    }
    final rows = await db.query('activities', where: 'pendingSync = 1');
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<void> markActivitySynced(String id) async {
    if (_memoryMode) {
      final a = _activities[id];
      if (a != null) {
        _activities[id] = ActivityLog(
          id: a.id,
          userName: a.userName,
          action: a.action,
          occurredAt: a.occurredAt,
          latitude: a.latitude,
          longitude: a.longitude,
          locationLabel: a.locationLabel,
          pendingSync: false,
        );
      }
      return;
    }
    await db.update(
      'activities',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── SOS presets ────────────────────────────────────────────────────────

  Future<List<SosPreset>> getSosPresets() async {
    if (_memoryMode) {
      final list = _presets.values.where((p) => !p.deleted).toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      return list;
    }
    final rows = await db.query(
      'sos_presets',
      where: 'deleted = 0',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(SosPreset.fromMap).toList();
  }

  Future<void> upsertSosPreset(SosPreset preset) async {
    if (_memoryMode) {
      _presets[preset.id] = preset;
      return;
    }
    await db.insert(
      'sos_presets',
      preset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteSosPreset(String id) async {
    if (_memoryMode) {
      final preset = _presets[id];
      if (preset != null) {
        _presets[id] = preset.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'sos_presets',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SosPreset>> getPendingSosPresets() async {
    if (_memoryMode) {
      return _presets.values.where((p) => p.pendingSync).toList();
    }
    final rows = await db.query('sos_presets', where: 'pendingSync = 1');
    return rows.map(SosPreset.fromMap).toList();
  }

  Future<void> markSosPresetSynced(String id) async {
    if (_memoryMode) {
      final preset = _presets[id];
      if (preset != null) {
        _presets[id] = preset.copyWith(pendingSync: false);
      }
      return;
    }
    await db.update(
      'sos_presets',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
