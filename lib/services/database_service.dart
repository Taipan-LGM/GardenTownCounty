import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/activity_log.dart';
import '../models/lookup_item.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import '../models/sos_preset.dart';

/// Offline-first SQLite access layer for Garden Town County.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  bool _initialized = false;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService not initialized. Call init() first.');
    }
    return database;
  }

  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not supported on web. Run the desktop/mobile build.',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documents.path, 'garden_town_county.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _initialized = true;
  }

  Future<void> _onUpgrade(Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE members ADD COLUMN photoLocalPath TEXT',
      );
      await database.execute(
        'ALTER TABLE members ADD COLUMN photoUrl TEXT',
      );
    }
  }

  Future<void> _onCreate(Database database, int version) async {
    await database.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        saId TEXT NOT NULL UNIQUE,
        globalRecordNo TEXT NOT NULL UNIQUE,
        memberName TEXT NOT NULL,
        surname TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        suburb TEXT NOT NULL DEFAULT '',
        townCity TEXT NOT NULL DEFAULT '',
        postalCode TEXT NOT NULL DEFAULT '',
        contactNo1 TEXT NOT NULL DEFAULT '',
        contactNo2 TEXT NOT NULL DEFAULT '',
        emailAddress TEXT NOT NULL DEFAULT '',
        comment TEXT NOT NULL DEFAULT '',
        photoLocalPath TEXT,
        photoUrl TEXT,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE lookups (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        value TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(type, value)
      )
    ''');

    await database.execute('''
      CREATE TABLE member_files (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        fileName TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        uploadedBy TEXT NOT NULL,
        uploadedAt TEXT NOT NULL,
        storageUrl TEXT,
        localPath TEXT,
        contentType TEXT NOT NULL DEFAULT 'application/octet-stream',
        sizeBytes INTEGER NOT NULL DEFAULT 0,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(memberId) REFERENCES members(id)
      )
    ''');

    await database.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        userName TEXT NOT NULL,
        action TEXT NOT NULL,
        occurredAt TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        locationLabel TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await database.execute('''
      CREATE TABLE sos_presets (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_members_name ON members(surname, memberName)',
    );
    await database.execute(
      'CREATE INDEX idx_member_files_member ON member_files(memberId)',
    );
  }

  // ── Members ────────────────────────────────────────────────────────────

  Future<List<Member>> getAllMembers() async {
    final rows = await db.query(
      'members',
      where: 'deleted = 0',
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<Member?> getMemberById(String id) async {
    final rows = await db.query(
      'members',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<List<Member>> searchMembers(String query) async {
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'members',
      where: '''
        deleted = 0 AND (
          saId LIKE ? OR globalRecordNo LIKE ? OR memberName LIKE ? OR
          surname LIKE ? OR address LIKE ? OR suburb LIKE ? OR
          townCity LIKE ? OR postalCode LIKE ? OR contactNo1 LIKE ? OR
          contactNo2 LIKE ? OR emailAddress LIKE ? OR comment LIKE ?
        )
      ''',
      whereArgs: List<String>.filled(12, q),
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<void> upsertMember(Member member) async {
    await db.insert(
      'members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteMember(String id) async {
    await db.update(
      'members',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Member>> getPendingMembers() async {
    final rows = await db.query('members', where: 'pendingSync = 1');
    return rows.map(Member.fromMap).toList();
  }

  Future<void> markMemberSynced(String id) async {
    await db.update(
      'members',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMemberPhoto({
    required String id,
    String? photoLocalPath,
    String? photoUrl,
  }) async {
    await db.update(
      'members',
      {
        'photoLocalPath': photoLocalPath,
        'photoUrl': photoUrl,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Lookups ────────────────────────────────────────────────────────────

  Future<List<LookupItem>> getLookups(LookupType type) async {
    final rows = await db.query(
      'lookups',
      where: 'type = ? AND deleted = 0',
      whereArgs: [type.storageKey],
      orderBy: 'value COLLATE NOCASE ASC',
    );
    return rows.map(LookupItem.fromMap).toList();
  }

  Future<void> upsertLookup(LookupItem item) async {
    await db.insert(
      'lookups',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteLookup(String id) async {
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
    final rows = await db.query('lookups', where: 'pendingSync = 1');
    return rows.map(LookupItem.fromMap).toList();
  }

  Future<void> markLookupSynced(String id) async {
    await db.update(
      'lookups',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Member files ───────────────────────────────────────────────────────

  Future<List<MemberFile>> getFilesForMember(String memberId) async {
    final rows = await db.query(
      'member_files',
      where: 'memberId = ? AND deleted = 0',
      whereArgs: [memberId],
      orderBy: 'fileName COLLATE NOCASE ASC',
    );
    return rows.map(MemberFile.fromMap).toList();
  }

  Future<void> upsertMemberFile(MemberFile file) async {
    await db.insert(
      'member_files',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteMemberFile(String id) async {
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
    final rows = await db.query(
      'member_files',
      where: 'pendingSync = 1 AND deleted = 0',
    );
    return rows.map(MemberFile.fromMap).toList();
  }

  Future<void> markMemberFileSynced(String id, {String? storageUrl}) async {
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

  // ── Activities ─────────────────────────────────────────────────────────

  Future<List<ActivityLog>> getActivities() async {
    final rows = await db.query(
      'activities',
      orderBy: 'occurredAt DESC',
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<void> insertActivity(ActivityLog activity) async {
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActivityLog>> getPendingActivities() async {
    final rows = await db.query('activities', where: 'pendingSync = 1');
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<void> markActivitySynced(String id) async {
    await db.update(
      'activities',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── SOS presets ────────────────────────────────────────────────────────

  Future<List<SosPreset>> getSosPresets() async {
    final rows = await db.query(
      'sos_presets',
      where: 'deleted = 0',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(SosPreset.fromMap).toList();
  }

  Future<void> upsertSosPreset(SosPreset preset) async {
    await db.insert(
      'sos_presets',
      preset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteSosPreset(String id) async {
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
    final rows = await db.query('sos_presets', where: 'pendingSync = 1');
    return rows.map(SosPreset.fromMap).toList();
  }

  Future<void> markSosPresetSynced(String id) async {
    await db.update(
      'sos_presets',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
