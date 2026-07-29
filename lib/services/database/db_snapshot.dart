part of '../database_service.dart';

/// Connection lifecycle and in-memory snapshot import/export for backups.
mixin _DbSnapshot on _DatabaseServiceBase {
  Future<void> close() async {
    if (_memoryMode) return;
    await _db?.close();
    _db = null;
    _initialized = false;
  }

  /// Re-open after restore replaced the SQLite file on disk.
  Future<void> reopenAfterRestore() async {
    if (_memoryMode) {
      _initialized = true;
      return;
    }
    final path = _dbPath;
    if (path == null) {
      throw StateError('Database path unknown.');
    }
    await _db?.close();
    _db = await openDatabase(
      path,
      version: 18,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _initialized = true;
  }

  /// Snapshot of in-memory tables for web/memory backups.
  Map<String, dynamic> exportMemorySnapshot() {
    return {
      'members': _members.values.map((m) => m.toMap()).toList(),
      'lookups': _lookups.values.map((l) => l.toMap()).toList(),
      'member_files': _files.values.map((f) => f.toMap()).toList(),
      'activities': _activities.values.map((a) => a.toMap()).toList(),
      'sos_presets': _presets.values.map((p) => p.toMap()).toList(),
      'app_users': _appUsers.values.map((u) => u.toMap()).toList(),
      'roles': _roles.values.map((r) => r.toMap()).toList(),
      'lro_cases': _lroCases.values.map((c) => c.toMap()).toList(),
      'lro_notices': _lroNotices.values.map((n) => n.toMap()).toList(),
      'lro_documents': _lroDocuments.values.map((d) => d.toMap()).toList(),
      'lro_history': _lroHistory.values.map((h) => h.toMap()).toList(),
      'reminders': _reminders.values.map((r) => r.toMap()).toList(),
      'temporary_access_logs':
          _tempAccessLogs.values.map((l) => l.toMap()).toList(),
      'remuneration_settings':
          _remunerationSettings.values.map((s) => s.toMap()).toList(),
      'secretary_remuneration':
          _secretaryRemunerations.values.map((r) => r.toMap()).toList(),
      'county_info': _countyInfo?.toMap(),
      'county_articles': _articles.values.map((a) => a.toMap()).toList(),
      'county_videos': _videos.values.map((v) => v.toMap()).toList(),
    };
  }

  Future<void> importMemorySnapshot(Map<String, dynamic> snapshot) async {
    _members
      ..clear()
      ..addEntries(
        ((snapshot['members'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, Member.fromMap(m))),
      );
    _lookups
      ..clear()
      ..addEntries(
        ((snapshot['lookups'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, LookupItem.fromMap(m))),
      );
    _files
      ..clear()
      ..addEntries(
        ((snapshot['member_files'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, MemberFile.fromMap(m))),
      );
    _activities
      ..clear()
      ..addEntries(
        ((snapshot['activities'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, ActivityLog.fromMap(m))),
      );
    _presets
      ..clear()
      ..addEntries(
        ((snapshot['sos_presets'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, SosPreset.fromMap(m))),
      );
    _appUsers
      ..clear()
      ..addEntries(
        ((snapshot['app_users'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, AppUser.fromMap(m))),
      );
    _roles
      ..clear()
      ..addEntries(
        ((snapshot['roles'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, RoleDefinition.fromMap(m))),
      );
    _lroCases
      ..clear()
      ..addEntries(
        ((snapshot['lro_cases'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, LroCase.fromMap(m))),
      );
    _lroNotices
      ..clear()
      ..addEntries(
        ((snapshot['lro_notices'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, LroNotice.fromMap(m))),
      );
    _lroDocuments
      ..clear()
      ..addEntries(
        ((snapshot['lro_documents'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, LroDocument.fromMap(m))),
      );
    _lroHistory
      ..clear()
      ..addEntries(
        ((snapshot['lro_history'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, LroHistory.fromMap(m))),
      );
    _reminders
      ..clear()
      ..addEntries(
        ((snapshot['reminders'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, Reminder.fromMap(m))),
      );
    _tempAccessLogs
      ..clear()
      ..addEntries(
        ((snapshot['temporary_access_logs'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(
              (m) => MapEntry(m['id'] as String, TemporaryAccessLog.fromMap(m)),
            ),
      );
    _remunerationSettings
      ..clear()
      ..addEntries(
        ((snapshot['remuneration_settings'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(
              (m) =>
                  MapEntry(m['id'] as String, RemunerationSettings.fromMap(m)),
            ),
      );
    _secretaryRemunerations
      ..clear()
      ..addEntries(
        ((snapshot['secretary_remuneration'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(
              (m) => MapEntry(
                m['id'] as String,
                SecretaryRemuneration.fromMap(m),
              ),
            ),
      );
    final countyRaw = snapshot['county_info'];
    if (countyRaw is Map<String, dynamic>) {
      _countyInfo = CountyInfo.fromMap(countyRaw);
    } else {
      _countyInfo = null;
    }
    _articles
      ..clear()
      ..addEntries(
        ((snapshot['county_articles'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, CountyArticle.fromMap(m))),
      );
    _videos
      ..clear()
      ..addEntries(
        ((snapshot['county_videos'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((m) => MapEntry(m['id'] as String, CountyVideo.fromMap(m))),
      );
  }

  /// Mark all non-deleted rows pending so restore can push to cloud.
  Future<void> markAllPendingSync() async {
    if (_memoryMode) {
      for (final id in _members.keys.toList()) {
        final m = _members[id];
        if (m != null) _members[id] = m.copyWith(pendingSync: true);
      }
      for (final id in _lookups.keys.toList()) {
        final l = _lookups[id];
        if (l != null) _lookups[id] = l.copyWith(pendingSync: true);
      }
      for (final id in _files.keys.toList()) {
        final f = _files[id];
        if (f != null) _files[id] = f.copyWith(pendingSync: true);
      }
      for (final id in _presets.keys.toList()) {
        final p = _presets[id];
        if (p != null) _presets[id] = p.copyWith(pendingSync: true);
      }
      for (final id in _appUsers.keys.toList()) {
        final u = _appUsers[id];
        if (u != null) _appUsers[id] = u.copyWith(pendingSync: true);
      }
      for (final id in _roles.keys.toList()) {
        final r = _roles[id];
        if (r != null) _roles[id] = r.copyWith(pendingSync: true);
      }
      for (final id in _lroCases.keys.toList()) {
        final c = _lroCases[id];
        if (c != null) _lroCases[id] = c.copyWith(pendingSync: true);
      }
      for (final id in _lroNotices.keys.toList()) {
        final n = _lroNotices[id];
        if (n != null) _lroNotices[id] = n.copyWith(pendingSync: true);
      }
      for (final id in _lroDocuments.keys.toList()) {
        final d = _lroDocuments[id];
        if (d != null) _lroDocuments[id] = d.copyWith(pendingSync: true);
      }
      for (final id in _lroHistory.keys.toList()) {
        final h = _lroHistory[id];
        if (h != null) _lroHistory[id] = h.copyWith(pendingSync: true);
      }
      for (final id in _reminders.keys.toList()) {
        final r = _reminders[id];
        if (r != null) _reminders[id] = r.copyWith(pendingSync: true);
      }
      for (final id in _tempAccessLogs.keys.toList()) {
        final l = _tempAccessLogs[id];
        if (l != null) _tempAccessLogs[id] = l.copyWith(pendingSync: true);
      }
      for (final id in _remunerationSettings.keys.toList()) {
        final s = _remunerationSettings[id];
        if (s != null) {
          _remunerationSettings[id] = s.copyWith(syncStatus: 'pending');
        }
      }
      for (final id in _secretaryRemunerations.keys.toList()) {
        final r = _secretaryRemunerations[id];
        if (r != null) {
          _secretaryRemunerations[id] = r.copyWith(syncStatus: 'pending');
        }
      }
      if (_countyInfo != null) {
        _countyInfo = _countyInfo!.copyWith(syncStatus: 'pending');
      }
      for (final id in _articles.keys.toList()) {
        final a = _articles[id];
        if (a != null) {
          _articles[id] = a.copyWith(syncStatus: 'pending');
        }
      }
      for (final id in _videos.keys.toList()) {
        final v = _videos[id];
        if (v != null) {
          _videos[id] = v.copyWith(syncStatus: 'pending');
        }
      }
      return;
    }
    await db.update('members', {'pendingSync': 1});
    await db.update('lookups', {'pendingSync': 1});
    await db.update('member_files', {'pendingSync': 1});
    await db.update('activities', {'pendingSync': 1});
    await db.update('sos_presets', {'pendingSync': 1});
    await db.update('app_users', {'pendingSync': 1});
    await db.update('roles', {'pendingSync': 1});
    await db.update('lro_cases', {'pendingSync': 1});
    await db.update('lro_notices', {'pendingSync': 1});
    await db.update('lro_documents', {'pendingSync': 1});
    await db.update('lro_history', {'pendingSync': 1});
    await db.update('reminders', {'pendingSync': 1});
    await db.update('temporary_access_logs', {'pendingSync': 1});
    await db.update('remuneration_settings', {'syncStatus': 'pending'});
    await db.update('secretary_remuneration', {'syncStatus': 'pending'});
    await db.update('county_info', {'syncStatus': 'pending'});
    await db.update('county_articles', {'syncStatus': 'pending'});
    await db.update('county_videos', {'syncStatus': 'pending'});
  }
}
