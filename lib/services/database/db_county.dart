part of '../database_service.dart';

/// County information, articles, videos and data reset operations.
mixin _DbCounty on _DatabaseServiceBase {
  // ── County Information (single row) ───────────────────────────────────
  // NEW ADDITION - Delete block to revert county_info CRUD + reset

  Future<CountyInfo?> getCountyInfo() async {
    if (_memoryMode) return _countyInfo;
    final rows = await db.query(
      'county_info',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [CountyInfo.documentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CountyInfo.fromMap(rows.first);
  }

  Future<void> upsertCountyInfo(CountyInfo info) async {
    final stamped = info.copyWith(id: CountyInfo.documentId);
    if (_memoryMode) {
      _countyInfo = stamped;
      return;
    }
    await db.insert(
      'county_info',
      stamped.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── County articles & videos ───────────────────────────────────────────

  Future<List<CountyArticle>> getPublishedArticles() async {
    final filterCounty = _activeCountyId;
    if (_memoryMode) {
      final list = _articles.values
          .where((a) => !a.isDeleted && a.isPublished)
          .where((a) => filterCounty.isEmpty || a.countyId == filterCounty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final whereBuf = StringBuffer('isDeleted = 0 AND isPublished = 1');
    final whereArgs = <dynamic>[];
    if (filterCounty.isNotEmpty) {
      whereBuf.write(' AND countyId = ?');
      whereArgs.add(filterCounty);
    }
    final rows = await db.query(
      'county_articles',
      where: whereBuf.toString(),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'createdAt DESC',
    );
    return rows.map(CountyArticle.fromMap).toList();
  }

  Future<List<CountyArticle>> getAllArticles() async {
    if (_memoryMode) {
      final list =
          _articles.values.where((a) => !a.isDeleted).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final rows = await db.query(
      'county_articles',
      where: 'isDeleted = 0',
      orderBy: 'createdAt DESC',
    );
    return rows.map(CountyArticle.fromMap).toList();
  }

  Future<void> upsertArticle(CountyArticle article) async {
    // Multi-county: stamp the active county if the article has none.
    final scoped = article.countyId.isEmpty && _activeCountyId.isNotEmpty
        ? article.copyWith(countyId: _activeCountyId)
        : article;
    if (_memoryMode) {
      _articles[scoped.id] = scoped;
      return;
    }
    await db.insert(
      'county_articles',
      scoped.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteArticle(String id) async {
    if (_memoryMode) {
      final article = _articles[id];
      if (article != null) {
        _articles[id] = article.copyWith(isDeleted: true);
      }
      return;
    }
    await db.update(
      'county_articles',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CountyVideo>> getActiveVideos() async {
    final filterCounty = _activeCountyId;
    if (_memoryMode) {
      final list = _videos.values
          .where((v) => !v.isDeleted && v.isActive)
          .where((v) => filterCounty.isEmpty || v.countyId == filterCounty)
          .toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return list;
    }
    final whereBuf = StringBuffer('isDeleted = 0 AND isActive = 1');
    final whereArgs = <dynamic>[];
    if (filterCounty.isNotEmpty) {
      whereBuf.write(' AND countyId = ?');
      whereArgs.add(filterCounty);
    }
    final rows = await db.query(
      'county_videos',
      where: whereBuf.toString(),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'uploadedAt DESC',
    );
    return rows.map(CountyVideo.fromMap).toList();
  }

  Future<List<CountyVideo>> getAllVideos() async {
    if (_memoryMode) {
      final list =
          _videos.values.where((v) => !v.isDeleted).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return list;
    }
    final rows = await db.query(
      'county_videos',
      where: 'isDeleted = 0',
      orderBy: 'uploadedAt DESC',
    );
    return rows.map(CountyVideo.fromMap).toList();
  }

  Future<void> upsertVideo(CountyVideo video) async {
    // Multi-county: stamp the active county if the video has none.
    final scoped = video.countyId.isEmpty && _activeCountyId.isNotEmpty
        ? video.copyWith(countyId: _activeCountyId)
        : video;
    if (_memoryMode) {
      _videos[scoped.id] = scoped;
      return;
    }
    await db.insert(
      'county_videos',
      scoped.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteVideo(String id) async {
    if (_memoryMode) {
      final video = _videos[id];
      if (video != null) {
        _videos[id] = video.copyWith(isDeleted: true);
      }
      return;
    }
    await db.update(
      'county_videos',
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Wipe operational data for a new county. Keeps Admin + system roles +
  /// remuneration settings config + county_info row + lookups/SOS presets.
  Future<void> resetCountyOperationalData() async {
    if (_memoryMode) {
      _members.clear();
      _files.clear();
      _activities.clear();
      _lroCases.clear();
      _lroNotices.clear();
      _lroDocuments.clear();
      _lroHistory.clear();
      _reminders.clear();
      _tempAccessLogs.clear();
      _secretaryRemunerations.clear();
      _appUsers.removeWhere(
        (id, u) => !u.isAdmin && !u.isSystemAdministrator,
      );
      return;
    }

    final batch = db.batch();
    batch.delete('members');
    batch.delete('member_files');
    batch.delete('reminders');
    batch.delete('lro_cases');
    batch.delete('lro_notices');
    batch.delete('lro_documents');
    batch.delete('lro_history');
    batch.delete('activities');
    batch.delete('temporary_access_logs');
    batch.delete('secretary_remuneration');
    await batch.commit(noResult: true);

    // Soft-delete non-admin app users (preserve demo-admin / Admin role).
    final users = await getAppUsers();
    for (final u in users) {
      if (u.isAdmin || u.isSystemAdministrator) continue;
      await softDeleteAppUser(u.id);
    }

    await ensureSeedAdmin();
  }

  /// Permanently delete all operational app data (Admin Delete All).
  /// Keeps: Admin user(s), county_info, system roles, lookups, SOS presets,
  /// remuneration settings templates.
  Future<void> deleteAllData() async {
    if (_memoryMode) {
      await resetCountyOperationalData();
      _articles.clear();
      _videos.clear();
      await ensureSeedAdmin();
      return;
    }

    await resetCountyOperationalData();

    final batch = db.batch();
    batch.delete('county_articles');
    batch.delete('county_videos');
    // Hard-remove non-admin users (incl. soft-deleted). Keep Admin.
    batch.delete(
      'app_users',
      where: "role NOT IN ('Admin', 'System Administrator')",
    );
    await batch.commit(noResult: true);

    _articles.clear();
    _videos.clear();
    _appUsers.removeWhere(
      (id, u) => !u.isAdmin && !u.isSystemAdministrator,
    );

    await ensureSeedAdmin();
  }
}
