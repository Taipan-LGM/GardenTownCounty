part of '../database_service.dart';

/// Multi-county platform tier. Each County owns its members, payments, LRO
/// publications and settings. The original Garden Town County data is migrated
/// into the first seeded County so nothing is lost.
// NEW ADDITION - Delete this file + its wiring to revert multi-county.
mixin _DbCounties on _DatabaseServiceBase {
  // In-memory mirror (used on web / tests).
  final Map<String, County> _counties = {};

  // ── Schema ───────────────────────────────────────────────────────────
  Future<void> _createCountiesTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS counties (
        id TEXT PRIMARY KEY,
        countyName TEXT NOT NULL,
        countyAddress TEXT NOT NULL DEFAULT '',
        countyContactNo TEXT NOT NULL DEFAULT '',
        countyEmail TEXT NOT NULL DEFAULT '',
        countyRegistrationNo TEXT NOT NULL DEFAULT '',
        facebookUrl TEXT NOT NULL DEFAULT '',
        uniqueNumber TEXT NOT NULL DEFAULT '',
        logoPath TEXT,
        secondaryLogoPath TEXT,
        sealPath TEXT,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(uniqueNumber)
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_counties_unique ON counties(uniqueNumber)',
    );
  }

  // ── Seeding (migrate existing single-county data) ──────────────────────
  /// Id of the seeded default county. Stable across runs.
  static const String seededCountyId = 'county-garden-town';

  Future<void> ensureSeedCounty() async {
    final existing = await getCountyById(seededCountyId);
    if (existing != null) return;

    // Pull current branding from the existing single-row county_info table.
    CountyInfo? info;
    if (_memoryMode) {
      info = _countyInfo;
    } else {
      try {
        final rows = await db.query(
          'county_info',
          where: 'id = ? AND isDeleted = 0',
          whereArgs: [CountyInfo.documentId],
          limit: 1,
        );
        if (rows.isNotEmpty) info = CountyInfo.fromMap(rows.first);
      } catch (_) {
        info = null;
      }
    }
    final now = DateTime.now().toUtc();
    final seeded = County(
      id: seededCountyId,
      countyName: info?.countyName.isNotEmpty == true
          ? info!.countyName
          : 'Garden Town County',
      countyAddress: info?.countyAddress ?? '123 Main Street, Sandton, Johannesburg',
      countyContactNo: info?.countyContactNo ?? '011 123 4567',
      countyEmail: '',
      countyRegistrationNo: info?.countyRegistrationNo ?? 'CT2026-001',
      facebookUrl: '',
      uniqueNumber: '024',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );
    await upsertCounty(seeded);

    // Tag every existing member + app user with the seeded county so they are
    // preserved (no account recreation, no data loss).
    await _tagExistingRowsWithCounty(seededCountyId);
  }

  Future<void> _tagExistingRowsWithCounty(String countyId) async {
    // Web / in-memory mode starts from an empty database, so there is nothing
    // to migrate. (The Member/AppUser models don't yet carry countyId; tagging
    // is done via raw SQL on the desktop/SQLite path below.)
    if (_memoryMode) return;
    await db.execute(
      'UPDATE members SET countyId = ? WHERE countyId IS NULL OR countyId = ?',
      [countyId, ''],
    );
    await db.execute(
      'UPDATE app_users SET countyId = ? WHERE countyId IS NULL OR countyId = ?',
      [countyId, ''],
    );
  }

  // ── CRUD ──────────────────────────────────────────────────────────────
  /// Quick per-county metrics for the dashboard.
  Future<({int memberCount, double revenue})> getCountyStats(
    String countyId,
  ) async {
    int memberCount = 0;
    double revenue = 0;
    if (_memoryMode) {
      // Web / in-memory mode starts empty; member countyId isn't modelled yet.
      return (memberCount: 0, revenue: 0.0);
    }
    final mRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM members WHERE countyId = ? AND deleted = 0 AND (isCancelled IS NULL OR isCancelled = 0)',
      [countyId],
    );
    memberCount = (mRows.first['c'] as int?) ?? 0;
    // Revenue = approved/paid secretary remuneration for this county's members.
    final rRows = await db.rawQuery('''
      SELECT COALESCE(SUM(s.amount), 0) AS total
      FROM secretary_remuneration s
      JOIN members m ON m.id = s.memberId
      WHERE m.countyId = ? AND s.isDeleted = 0
    ''', [countyId]);
    revenue = (rRows.first['total'] as num?)?.toDouble() ?? 0;
    return (memberCount: memberCount, revenue: revenue);
  }

  Future<List<County>> getCounties() async {
    if (_memoryMode) {
      return _counties.values
          .where((c) => !c.isDeleted)
          .toList()
        ..sort((a, b) => a.countyName.toLowerCase().compareTo(b.countyName.toLowerCase()));
    }
    final rows = await db.query(
      'counties',
      where: 'isDeleted = 0',
      orderBy: 'countyName COLLATE NOCASE ASC',
    );
    return rows.map(County.fromMap).toList();
  }

  Future<County?> getCountyById(String id) async {
    if (_memoryMode) {
      final c = _counties[id];
      return (c != null && !c.isDeleted) ? c : null;
    }
    final rows = await db.query(
      'counties',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return County.fromMap(rows.first);
  }

  Future<County?> getCountyByUniqueNumber(String uniqueNumber) async {
    final key = uniqueNumber.trim();
    if (key.isEmpty) return null;
    if (_memoryMode) {
      for (final c in _counties.values) {
        if (!c.isDeleted && c.uniqueNumber == key) return c;
      }
      return null;
    }
    final rows = await db.query(
      'counties',
      where: 'uniqueNumber = ? AND isDeleted = 0',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return County.fromMap(rows.first);
  }

  /// Throws [DuplicateException] if the 3-digit code is already taken.
  Future<void> _assertUniqueNumberAvailable(String uniqueNumber, {String? excludeId}) async {
    final key = uniqueNumber.trim();
    if (key.isEmpty) return;
    final clash = await getCountyByUniqueNumber(key);
    if (clash != null && clash.id != excludeId) {
      throw DuplicateException(
        'County Unique Number already exists',
        field: 'County Unique Number',
        value: key,
      );
    }
  }

  Future<County> createCounty(County county) async {
    await _assertUniqueNumberAvailable(county.uniqueNumber);
    await upsertCounty(county);
    return county;
  }

  Future<void> upsertCounty(County county) async {
    if (_memoryMode) {
      _counties[county.id] = county;
      return;
    }
    await db.insert(
      'counties',
      county.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCounty(County county) async {
    await _assertUniqueNumberAvailable(county.uniqueNumber, excludeId: county.id);
    await upsertCounty(county);
  }

  /// Delete a county and all of its operational data. The admin account is
  /// preserved (it is platform-wide). Use with confirmation in the UI.
  Future<void> deleteCounty(String countyId) async {
    if (_memoryMode) {
      final c = _counties[countyId];
      if (c != null) _counties[countyId] = c.copyWith(isDeleted: true);
      // In-memory models don't carry countyId yet; web is ephemeral so we
      // leave member/user maps intact (the county is simply hidden).
      return;
    }

    final batch = db.batch();
    batch.delete('members', where: 'countyId = ?', whereArgs: [countyId]);
    batch.delete('member_files', where: 'memberId IN (SELECT id FROM members WHERE countyId = ?)', whereArgs: [countyId]);
    batch.update('app_users', {'isDeleted': 1}, where: "countyId = ? AND role NOT IN ('Admin', 'System Administrator')", whereArgs: [countyId]);
    await batch.commit(noResult: true);

    await db.update(
      'counties',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [countyId],
    );
  }
}
