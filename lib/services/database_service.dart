import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants/app_constants.dart';
import '../core/exceptions/duplicate_exception.dart';
import '../models/activity_log.dart';
import '../models/app_user.dart';
import '../models/lookup_item.dart';
import '../models/lro_case.dart';
import '../models/lro_document.dart';
import '../models/lro_history.dart';
import '../models/lro_notice.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import '../models/reminder.dart';
import '../models/role_definition.dart';
import '../models/sos_preset.dart';
import '../models/temporary_access_log.dart';
import 'password_hasher.dart';

/// Offline-first SQLite access layer for Garden Town County.
/// On web, uses an in-memory store (SQLite is unavailable in browsers).
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  bool _initialized = false;
  bool _memoryMode = false;
  String? _dbPath;

  String? get databasePath => _dbPath;
  bool get isMemoryMode => _memoryMode;

  final Map<String, Member> _members = {};
  final Map<String, LookupItem> _lookups = {};
  final Map<String, MemberFile> _files = {};
  final Map<String, ActivityLog> _activities = {};
  final Map<String, SosPreset> _presets = {};
  final Map<String, AppUser> _appUsers = {};
  final Map<String, RoleDefinition> _roles = {};
  final Map<String, LroCase> _lroCases = {};
  final Map<String, LroNotice> _lroNotices = {};
  final Map<String, LroDocument> _lroDocuments = {};
  final Map<String, LroHistory> _lroHistory = {};
  final Map<String, Reminder> _reminders = {};
  final Map<String, TemporaryAccessLog> _tempAccessLogs = {};

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService not initialized. Call init() first.');
    }
    return database;
  }

  /// Force in-memory mode for unit tests (no SQLite file).
  Future<void> initForTests() async {
    _memoryMode = true;
    _initialized = true;
    _db = null;
    await clearAllForTests();
  }

  Future<void> clearAllForTests() async {
    _members.clear();
    _lookups.clear();
    _files.clear();
    _activities.clear();
    _presets.clear();
    _appUsers.clear();
    _roles.clear();
    _lroCases.clear();
    _lroNotices.clear();
    _lroDocuments.clear();
    _lroHistory.clear();
    _reminders.clear();
    _tempAccessLogs.clear();
  }

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _memoryMode = true;
      _initialized = true;
      await ensureSeedAdmin();
      return;
    }

    // Desktop FFI (avoid dart:io import so web can compile).
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documents = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documents.path, 'garden_town_county.db');
    _dbPath = dbPath;
    _db = await openDatabase(
      dbPath,
      version: 11,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _initialized = true;
    await ensureSeedAdmin();
  }

  Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE members ADD COLUMN photoLocalPath TEXT',
      );
      await database.execute(
        'ALTER TABLE members ADD COLUMN photoUrl TEXT',
      );
    }
    if (oldVersion < 3) {
      await _createAppUsersTable(database);
    }
    if (oldVersion < 4) {
      await _createRolesTable(database);
    }
    if (oldVersion < 5) {
      await _createLroTables(database);
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(database, 'app_users', 'permissions', 'TEXT');
      await _addColumnIfMissing(database, 'app_users', 'memberId', 'TEXT');
      await _createRemindersTable(database);
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(database, 'members', 'userId', 'TEXT');
    }
    if (oldVersion < 8) {
      await _addColumnIfMissing(
        database,
        'members',
        'registrationStatus',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'isEmailVerified',
        'INTEGER',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'emailVerifiedDate',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'registrationDate',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step1MemberInfoComplete',
        'INTEGER',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step2Global528Complete',
        'INTEGER',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step3Global928Complete',
        'INTEGER',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step4LROComplete',
        'INTEGER',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step1CompletionDate',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step2CompletionDate',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step3CompletionDate',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step4CompletionDate',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'members', 'step1ApprovedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'step2ApprovedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'step3ApprovedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'step4ApprovedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'isLocked', 'INTEGER');
      await _addColumnIfMissing(database, 'members', 'lockedDate', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'lockedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'lockedReason', 'TEXT');
      await _addColumnIfMissing(
        database,
        'members',
        'temporaryAccessCode',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'temporaryAccessExpiry',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'temporaryAccessGrantedBy',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'temporaryAccessGrantedTo',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'temporaryAccessReason',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'members', 'createdBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'lastModifiedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'createdAt', 'TEXT');
      await _createTemporaryAccessLogsTable(database);
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(database, 'members', 'completedBy', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'completedDate', 'TEXT');
      await _addColumnIfMissing(
        database,
        'temporary_access_logs',
        'adminName',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'temporary_access_logs',
        'secretaryName',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'temporary_access_logs',
        'duration',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'temporary_access_logs',
        'status',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'temporary_access_logs',
        'revokedBy',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'temporary_access_logs',
        'revokedReason',
        'TEXT',
      );
    }
    if (oldVersion < 10) {
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_members_saId ON members(saId)',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_members_globalRecordNo '
        'ON members(globalRecordNo)',
      );
    }
    if (oldVersion < 11) {
      await _addColumnIfMissing(database, 'reminders', 'kind', "TEXT DEFAULT 'manual'");
      await _addColumnIfMissing(database, 'reminders', 'stepNumber', 'INTEGER');
      await _addColumnIfMissing(database, 'reminders', 'stepDescription', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'memberName', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'surname', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'saId', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'expiryDate', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'status', "TEXT DEFAULT 'active'");
      await _addColumnIfMissing(database, 'reminders', 'completedDate', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'completedBy', 'TEXT');
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders(status)',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_member '
        'ON reminders(memberId)',
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Database database,
    String table,
    String column,
    String type,
  ) async {
    final info = await database.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await database.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _createRemindersTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        memberId TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        reminderDateTime TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'Medium',
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        kind TEXT NOT NULL DEFAULT 'manual',
        stepNumber INTEGER,
        stepDescription TEXT,
        memberName TEXT,
        surname TEXT,
        saId TEXT,
        expiryDate TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        completedDate TEXT,
        completedBy TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders(status)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_member ON reminders(memberId)',
    );
  }

  Future<void> _createTemporaryAccessLogsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS temporary_access_logs (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        memberId TEXT NOT NULL,
        adminId TEXT NOT NULL,
        adminName TEXT NOT NULL DEFAULT '',
        secretaryId TEXT NOT NULL,
        secretaryName TEXT NOT NULL DEFAULT '',
        accessCode TEXT NOT NULL,
        grantedAt TEXT NOT NULL,
        expiresAt TEXT NOT NULL,
        duration TEXT NOT NULL DEFAULT '1h',
        isUsed INTEGER NOT NULL DEFAULT 0,
        usedAt TEXT,
        reason TEXT,
        revoked INTEGER NOT NULL DEFAULT 0,
        revokedAt TEXT,
        revokedBy TEXT,
        revokedReason TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createAppUsersTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS app_users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        displayName TEXT NOT NULL,
        passwordHash TEXT NOT NULL,
        role TEXT NOT NULL,
        memberId TEXT,
        permissions TEXT,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createRolesTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        isSystem INTEGER NOT NULL DEFAULT 0,
        grantsAdmin INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createLroTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS lro_cases (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        memberId TEXT NOT NULL,
        caseType TEXT NOT NULL,
        caseNumber TEXT NOT NULL,
        recordingNumber TEXT,
        subjectName TEXT NOT NULL DEFAULT '',
        propertyAddress TEXT NOT NULL DEFAULT '',
        propertySize TEXT NOT NULL DEFAULT '',
        zoningType TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        submissionDate TEXT,
        approvalDate TEXT,
        publishedDate TEXT,
        assignedOfficer TEXT NOT NULL DEFAULT '',
        feeAmount REAL,
        notes TEXT NOT NULL DEFAULT '',
        rejectionReason TEXT NOT NULL DEFAULT '',
        createdBy TEXT NOT NULL DEFAULT '',
        updatedBy TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS lro_notices (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        publicationDate TEXT,
        expiryDate TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        memberId TEXT,
        relatedCaseId TEXT,
        createdBy TEXT NOT NULL DEFAULT '',
        updatedBy TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS lro_documents (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        parentType TEXT NOT NULL,
        parentId TEXT NOT NULL,
        docType TEXT NOT NULL DEFAULT 'other',
        fileName TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        uploadedBy TEXT NOT NULL,
        uploadedAt TEXT NOT NULL,
        storageUrl TEXT,
        localPath TEXT,
        contentType TEXT NOT NULL DEFAULT 'application/octet-stream',
        sizeBytes INTEGER NOT NULL DEFAULT 0,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS lro_history (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action TEXT NOT NULL,
        fromStatus TEXT,
        toStatus TEXT,
        changedBy TEXT NOT NULL DEFAULT '',
        detail TEXT NOT NULL DEFAULT '',
        changedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_cases_type ON lro_cases(caseType)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_notices_status ON lro_notices(status)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_documents_parent ON lro_documents(parentType, parentId)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_history_entity ON lro_history(entityType, entityId)',
    );
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
        userId TEXT,
        registrationStatus TEXT,
        isEmailVerified INTEGER,
        emailVerifiedDate TEXT,
        registrationDate TEXT,
        step1MemberInfoComplete INTEGER,
        step2Global528Complete INTEGER,
        step3Global928Complete INTEGER,
        step4LROComplete INTEGER,
        step1CompletionDate TEXT,
        step2CompletionDate TEXT,
        step3CompletionDate TEXT,
        step4CompletionDate TEXT,
        step1ApprovedBy TEXT,
        step2ApprovedBy TEXT,
        step3ApprovedBy TEXT,
        step4ApprovedBy TEXT,
        isLocked INTEGER,
        lockedDate TEXT,
        lockedBy TEXT,
        lockedReason TEXT,
        completedBy TEXT,
        completedDate TEXT,
        temporaryAccessCode TEXT,
        temporaryAccessExpiry TEXT,
        temporaryAccessGrantedBy TEXT,
        temporaryAccessGrantedTo TEXT,
        temporaryAccessReason TEXT,
        createdBy TEXT,
        lastModifiedBy TEXT,
        createdAt TEXT,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_saId ON members(saId)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_globalRecordNo '
      'ON members(globalRecordNo)',
    );

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
    await _createAppUsersTable(database);
    await _createRolesTable(database);
    await _createLroTables(database);
    await _createRemindersTable(database);
    await _createTemporaryAccessLogsTable(database);
  }

  Future<void> ensureSeedAdmin() async {
    await ensureSeedRoles();
    final existing =
        await getAppUserByUsername(AppConstants.demoUsername);
    if (existing != null) return;

    final admin = AppUser(
      id: 'demo-admin',
      username: AppConstants.demoUsername,
      displayName: AppConstants.demoDisplayName,
      passwordHash: PasswordHasher.hash(AppConstants.demoPassword),
      role: 'Admin',
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await upsertAppUser(admin);
  }

  Future<void> ensureSeedRoles() async {
    const seeds = <({String name, bool admin, bool system})>[
      (name: 'Admin', admin: true, system: true),
      (name: 'Recording Secretary', admin: false, system: true),
      (name: 'Member', admin: false, system: true),
    ];
    for (final seed in seeds) {
      final existing = await getRoleByName(seed.name);
      if (existing != null) continue;
      await upsertRole(
        RoleDefinition(
          id: 'role-${seed.name.toLowerCase().replaceAll(' ', '-')}',
          name: seed.name,
          isSystem: seed.system,
          grantsAdmin: seed.admin,
          updatedAt: DateTime.now().toUtc(),
          pendingSync: true,
        ),
      );
    }
  }

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

  // ── Reminders ──────────────────────────────────────────────────────────

  Future<List<Reminder>> getReminders({bool includeCompleted = true}) async {
    if (_memoryMode) {
      final list = _reminders.values
          .where((r) => !r.deleted && (includeCompleted || !r.isCompleted))
          .toList()
        ..sort(
          (a, b) => a.reminderDateTime.compareTo(b.reminderDateTime),
        );
      return list;
    }
    final where = includeCompleted
        ? 'deleted = 0'
        : 'deleted = 0 AND isCompleted = 0';
    final rows = await db.query(
      'reminders',
      where: where,
      orderBy: 'reminderDateTime ASC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  Future<List<Reminder>> getActiveOnboardingReminders() async {
    final all = await getReminders(includeCompleted: false);
    final list = all
        .where(
          (r) =>
              r.isOnboarding &&
              r.status == 'active' &&
              !r.isCompleted &&
              !r.deleted,
        )
        .toList()
      ..sort((a, b) {
        final sa = a.stepNumber ?? 99;
        final sb = b.stepNumber ?? 99;
        if (sa != sb) return sa.compareTo(sb);
        final ea = a.expiryDate ?? a.reminderDateTime;
        final eb = b.expiryDate ?? b.reminderDateTime;
        return ea.compareTo(eb);
      });
    return list;
  }

  Future<List<Reminder>> getActiveRemindersByMember(String memberId) async {
    final all = await getActiveOnboardingReminders();
    return all.where((r) => r.memberId == memberId).toList();
  }

  Future<List<Reminder>> getRemindersByStep(int stepNumber) async {
    final all = await getActiveOnboardingReminders();
    return all.where((r) => r.stepNumber == stepNumber).toList();
  }

  Future<List<Reminder>> getExpiredReminders(DateTime now) async {
    final all = await getActiveOnboardingReminders();
    final clock = now.toUtc();
    return all
        .where((r) => r.expiryDate != null && r.expiryDate!.isBefore(clock))
        .toList();
  }

  Future<int> getActiveOnboardingReminderCount() async {
    final list = await getActiveOnboardingReminders();
    return list.length;
  }

  Future<Reminder?> getReminderById(String id) async {
    if (_memoryMode) {
      final reminder = _reminders[id];
      if (reminder == null || reminder.deleted) return null;
      return reminder;
    }
    final rows = await db.query(
      'reminders',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Reminder.fromMap(rows.first);
  }

  Future<List<Reminder>> getPendingReminders() async {
    if (_memoryMode) {
      return _reminders.values.where((r) => r.pendingSync).toList();
    }
    final rows = await db.query('reminders', where: 'pendingSync = 1');
    return rows.map(Reminder.fromMap).toList();
  }

  Future<void> upsertReminder(Reminder reminder) async {
    if (_memoryMode) {
      _reminders[reminder.id] = reminder;
      return;
    }
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteReminder(String id) async {
    if (_memoryMode) {
      final reminder = _reminders[id];
      if (reminder != null) {
        _reminders[id] = reminder.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'reminders',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markReminderSynced(String id) async {
    if (_memoryMode) {
      final reminder = _reminders[id];
      if (reminder != null) {
        _reminders[id] = reminder.copyWith(pendingSync: false);
      }
      return;
    }
    await db.update(
      'reminders',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Members ────────────────────────────────────────────────────────────

  Future<List<Member>> getAllMembers() async {
    if (_memoryMode) {
      final list = _members.values.where((m) => !m.deleted).toList()
        ..sort((a, b) {
          final s = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
          if (s != 0) return s;
          return a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
        });
      return list;
    }
    final rows = await db.query(
      'members',
      where: 'deleted = 0',
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<Member?> getMemberById(String id) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m == null || m.deleted) return null;
      return m;
    }
    final rows = await db.query(
      'members',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<Member?> getMemberBySaId(String saId) async {
    return findMemberBySaId(saId);
  }

  /// Find active member by SA ID, optionally excluding one member (edit mode).
  Future<Member?> findMemberBySaId(
    String saId, {
    String? excludeMemberId,
  }) async {
    final key = saId.trim();
    if (key.isEmpty) return null;
    if (_memoryMode) {
      for (final m in _members.values) {
        if (m.deleted) continue;
        if (excludeMemberId != null && m.id == excludeMemberId) continue;
        if (m.saId == key) return m;
      }
      return null;
    }
    final rows = await db.query(
      'members',
      where: excludeMemberId == null
          ? 'saId = ? AND deleted = 0'
          : 'saId = ? AND deleted = 0 AND id != ?',
      whereArgs: excludeMemberId == null ? [key] : [key, excludeMemberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<Member?> getMemberByGlobalRecordNo(String globalRecordNo) async {
    return findMemberByGlobalRecordNo(globalRecordNo);
  }

  /// Find active member by Global Record No., optionally excluding one member.
  Future<Member?> findMemberByGlobalRecordNo(
    String globalRecordNo, {
    String? excludeMemberId,
  }) async {
    final key = globalRecordNo.trim();
    if (key.isEmpty) return null;
    if (_memoryMode) {
      for (final m in _members.values) {
        if (m.deleted) continue;
        if (excludeMemberId != null && m.id == excludeMemberId) continue;
        if (m.globalRecordNo == key) return m;
      }
      return null;
    }
    final rows = await db.query(
      'members',
      where: excludeMemberId == null
          ? 'globalRecordNo = ? AND deleted = 0'
          : 'globalRecordNo = ? AND deleted = 0 AND id != ?',
      whereArgs: excludeMemberId == null ? [key] : [key, excludeMemberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<bool> checkSaIdExists(
    String saId, {
    String? excludeMemberId,
  }) async {
    final found = await findMemberBySaId(saId, excludeMemberId: excludeMemberId);
    return found != null;
  }

  Future<bool> checkGlobalRecordExists(
    String globalRecordNo, {
    String? excludeMemberId,
  }) async {
    final found = await findMemberByGlobalRecordNo(
      globalRecordNo,
      excludeMemberId: excludeMemberId,
    );
    return found != null;
  }

  /// Groups of members sharing the same SA ID or Global Record (data repair).
  Future<List<({String field, String value, List<Member> members})>>
      findDuplicateMemberGroups() async {
    final all = await getAllMembers();
    final bySa = <String, List<Member>>{};
    final byGr = <String, List<Member>>{};
    for (final m in all) {
      bySa.putIfAbsent(m.saId, () => []).add(m);
      byGr.putIfAbsent(m.globalRecordNo, () => []).add(m);
    }
    final groups = <({String field, String value, List<Member> members})>[];
    for (final e in bySa.entries) {
      if (e.key.isEmpty || e.value.length < 2) continue;
      groups.add((field: 'SA ID', value: e.key, members: e.value));
    }
    for (final e in byGr.entries) {
      if (e.key.isEmpty || e.value.length < 2) continue;
      groups.add((field: 'Global Record No.', value: e.key, members: e.value));
    }
    return groups;
  }

  Future<AppUser?> getAppUserByMemberId(String memberId) async {
    if (_memoryMode) {
      for (final u in _appUsers.values) {
        if (!u.deleted && u.memberId == memberId) return u;
      }
      return null;
    }
    final rows = await db.query(
      'app_users',
      where: 'memberId = ? AND deleted = 0',
      whereArgs: [memberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<Member>> searchMembers(String query) async {
    if (_memoryMode) {
      final q = query.trim().toLowerCase();
      return (await getAllMembers()).where((m) {
        final hay = [
          m.saId,
          m.globalRecordNo,
          m.memberName,
          m.surname,
          m.address,
          m.suburb,
          m.townCity,
          m.postalCode,
          m.contactNo1,
          m.contactNo2,
          m.emailAddress,
          m.comment,
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    }
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
    // Pre-check uniqueness (memory + SQLite) so ConflictAlgorithm.replace
    // cannot silently delete another member on saId/globalRecord clash.
    final saClash = await findMemberBySaId(
      member.saId,
      excludeMemberId: member.id,
    );
    if (saClash != null) {
      throw DuplicateException(
        'SA ID already exists',
        field: 'SA ID',
        value: member.saId,
        existingMemberId: saClash.id,
      );
    }
    final grClash = await findMemberByGlobalRecordNo(
      member.globalRecordNo,
      excludeMemberId: member.id,
    );
    if (grClash != null) {
      throw DuplicateException(
        'Global Record No. already exists',
        field: 'Global Record No.',
        value: member.globalRecordNo,
        existingMemberId: grClash.id,
      );
    }

    if (_memoryMode) {
      _members[member.id] = member;
      return;
    }

    final existing = await getMemberById(member.id);
    if (existing == null) {
      await db.insert(
        'members',
        member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } else {
      await db.update(
        'members',
        member.toMap(),
        where: 'id = ?',
        whereArgs: [member.id],
      );
    }
  }

  Future<void> softDeleteMember(String id) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m != null) {
        _members[id] = m.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
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
    if (_memoryMode) {
      return _members.values.where((m) => m.pendingSync).toList();
    }
    final rows = await db.query('members', where: 'pendingSync = 1');
    return rows.map(Member.fromMap).toList();
  }

  Future<void> markMemberSynced(String id) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m != null) _members[id] = m.copyWith(pendingSync: false);
      return;
    }
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
    if (_memoryMode) {
      final m = _members[id];
      if (m != null) {
        _members[id] = m.copyWith(
          photoLocalPath: photoLocalPath,
          photoUrl: photoUrl,
          clearPhotoLocalPath: photoLocalPath == null,
          clearPhotoUrl: photoUrl == null,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
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

  Future<List<Member>> getLockedMembers() async {
    if (_memoryMode) {
      return _members.values
          .where((m) => !m.deleted && m.isLocked)
          .toList()
        ..sort((a, b) {
          final s = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
          if (s != 0) return s;
          return a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
        });
    }
    final rows = await db.query(
      'members',
      where: 'deleted = 0 AND isLocked = 1',
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<List<Member>> getMembersWithTempAccess() async {
    final all = await getAllMembers();
    return all
        .where(
          (m) =>
              m.temporaryAccessCode != null &&
              m.temporaryAccessCode!.isNotEmpty,
        )
        .toList();
  }

  Future<List<TemporaryAccessLog>> getAllTemporaryAccessLogs() async {
    if (_memoryMode) {
      return _tempAccessLogs.values.where((l) => !l.deleted).toList()
        ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'deleted = 0',
      orderBy: 'grantedAt DESC',
    );
    return rows.map(TemporaryAccessLog.fromMap).toList();
  }

  // ── Temporary Access Logs ──────────────────────────────────────────────

  Future<void> upsertTemporaryAccessLog(TemporaryAccessLog log) async {
    if (_memoryMode) {
      _tempAccessLogs[log.id] = log;
      return;
    }
    await db.insert(
      'temporary_access_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TemporaryAccessLog>> getTemporaryAccessLogsForMember(
    String memberId,
  ) async {
    if (_memoryMode) {
      return _tempAccessLogs.values
          .where((l) => !l.deleted && l.memberId == memberId)
          .toList()
        ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'memberId = ? AND deleted = 0',
      whereArgs: [memberId],
      orderBy: 'grantedAt DESC',
    );
    return rows.map(TemporaryAccessLog.fromMap).toList();
  }

  Future<List<TemporaryAccessLog>> getPendingTemporaryAccessLogs() async {
    if (_memoryMode) {
      return _tempAccessLogs.values.where((l) => l.pendingSync).toList();
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'pendingSync = 1',
    );
    return rows.map(TemporaryAccessLog.fromMap).toList();
  }

  Future<void> markTemporaryAccessLogSynced(String id) async {
    if (_memoryMode) {
      final log = _tempAccessLogs[id];
      if (log != null) {
        _tempAccessLogs[id] = log.copyWith(pendingSync: false);
      }
      return;
    }
    await db.update(
      'temporary_access_logs',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> temporaryAccessCodeExists(String code) async {
    if (_memoryMode) {
      return _tempAccessLogs.values.any(
        (l) => !l.deleted && !l.isRevoked && l.accessCode == code,
      );
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'accessCode = ? AND deleted = 0 AND revoked = 0',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

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

  // ── LRO cases ──────────────────────────────────────────────────────────

  Future<void> upsertLroCase(LroCase lroCase) async {
    if (_memoryMode) {
      _lroCases[lroCase.id] = lroCase;
      return;
    }
    await db.insert(
      'lro_cases',
      lroCase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroCase>> getLroCases({String? caseType}) async {
    if (_memoryMode) {
      final list = _lroCases.values
          .where((c) => !c.deleted && (caseType == null || c.caseType == caseType))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final where = StringBuffer('deleted = 0');
    final args = <Object?>[];
    if (caseType != null) {
      where.write(' AND caseType = ?');
      args.add(caseType);
    }
    final rows = await db.query(
      'lro_cases',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(LroCase.fromMap).toList();
  }

  Future<LroCase?> getLroCaseById(String id) async {
    if (_memoryMode) {
      final c = _lroCases[id];
      if (c == null || c.deleted) return null;
      return c;
    }
    final rows = await db.query(
      'lro_cases',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LroCase.fromMap(rows.first);
  }

  Future<void> softDeleteLroCase(String id) async {
    if (_memoryMode) {
      final c = _lroCases[id];
      if (c != null) {
        _lroCases[id] = c.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'lro_cases',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroCase>> getPendingLroCases() async {
    if (_memoryMode) {
      return _lroCases.values.where((c) => c.pendingSync).toList();
    }
    final rows = await db.query('lro_cases', where: 'pendingSync = 1');
    return rows.map(LroCase.fromMap).toList();
  }

  Future<void> markLroCaseSynced(String id) async {
    if (_memoryMode) {
      final c = _lroCases[id];
      if (c != null) _lroCases[id] = c.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_cases',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── LRO notices ────────────────────────────────────────────────────────

  Future<void> upsertLroNotice(LroNotice notice) async {
    if (_memoryMode) {
      _lroNotices[notice.id] = notice;
      return;
    }
    await db.insert(
      'lro_notices',
      notice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroNotice>> getLroNotices({String? status}) async {
    if (_memoryMode) {
      final list = _lroNotices.values
          .where((n) => !n.deleted && (status == null || n.status == status))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final where = StringBuffer('deleted = 0');
    final args = <Object?>[];
    if (status != null) {
      where.write(' AND status = ?');
      args.add(status);
    }
    final rows = await db.query(
      'lro_notices',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(LroNotice.fromMap).toList();
  }

  Future<List<LroNotice>> getPublishedNoticesForFeed() async {
    if (_memoryMode) {
      final list = _lroNotices.values
          .where((n) => !n.deleted && n.status == 'published')
          .toList()
        ..sort((a, b) {
          final aKey = a.publicationDate ?? a.updatedAt;
          final bKey = b.publicationDate ?? b.updatedAt;
          return bKey.compareTo(aKey);
        });
      return list;
    }
    final rows = await db.query(
      'lro_notices',
      where: "deleted = 0 AND status = 'published'",
      orderBy: 'COALESCE(publicationDate, updatedAt) DESC',
    );
    return rows.map(LroNotice.fromMap).toList();
  }

  Future<LroNotice?> getLroNoticeById(String id) async {
    if (_memoryMode) {
      final n = _lroNotices[id];
      if (n == null || n.deleted) return null;
      return n;
    }
    final rows = await db.query(
      'lro_notices',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LroNotice.fromMap(rows.first);
  }

  Future<void> softDeleteLroNotice(String id) async {
    if (_memoryMode) {
      final n = _lroNotices[id];
      if (n != null) {
        _lroNotices[id] = n.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'lro_notices',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroNotice>> getPendingLroNotices() async {
    if (_memoryMode) {
      return _lroNotices.values.where((n) => n.pendingSync).toList();
    }
    final rows = await db.query('lro_notices', where: 'pendingSync = 1');
    return rows.map(LroNotice.fromMap).toList();
  }

  Future<void> markLroNoticeSynced(String id) async {
    if (_memoryMode) {
      final n = _lroNotices[id];
      if (n != null) _lroNotices[id] = n.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_notices',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── LRO documents ──────────────────────────────────────────────────────

  Future<void> upsertLroDocument(LroDocument document) async {
    if (_memoryMode) {
      _lroDocuments[document.id] = document;
      return;
    }
    await db.insert(
      'lro_documents',
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroDocument>> getLroDocumentsForParent(
    String parentType,
    String parentId,
  ) async {
    if (_memoryMode) {
      final list = _lroDocuments.values
          .where((d) =>
              !d.deleted && d.parentType == parentType && d.parentId == parentId)
          .toList()
        ..sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
      return list;
    }
    final rows = await db.query(
      'lro_documents',
      where: 'parentType = ? AND parentId = ? AND deleted = 0',
      whereArgs: [parentType, parentId],
      orderBy: 'fileName COLLATE NOCASE ASC',
    );
    return rows.map(LroDocument.fromMap).toList();
  }

  Future<void> softDeleteLroDocument(String id) async {
    if (_memoryMode) {
      final d = _lroDocuments[id];
      if (d != null) {
        _lroDocuments[id] = d.copyWith(deleted: true, pendingSync: true);
      }
      return;
    }
    await db.update(
      'lro_documents',
      {
        'deleted': 1,
        'pendingSync': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroDocument>> getPendingLroDocuments() async {
    if (_memoryMode) {
      return _lroDocuments.values
          .where((d) => d.pendingSync && !d.deleted)
          .toList();
    }
    final rows = await db.query(
      'lro_documents',
      where: 'pendingSync = 1 AND deleted = 0',
    );
    return rows.map(LroDocument.fromMap).toList();
  }

  Future<void> markLroDocumentSynced(String id, {String? storageUrl}) async {
    if (_memoryMode) {
      final d = _lroDocuments[id];
      if (d != null) {
        _lroDocuments[id] = d.copyWith(
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
      'lro_documents',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── LRO history ────────────────────────────────────────────────────────

  Future<void> insertLroHistory(LroHistory history) async {
    if (_memoryMode) {
      _lroHistory[history.id] = history;
      return;
    }
    await db.insert(
      'lro_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroHistory>> getLroHistoryForEntity(
    String entityType,
    String entityId,
  ) async {
    if (_memoryMode) {
      final list = _lroHistory.values
          .where((h) => h.entityType == entityType && h.entityId == entityId)
          .toList()
        ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
      return list;
    }
    final rows = await db.query(
      'lro_history',
      where: 'entityType = ? AND entityId = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'changedAt DESC',
    );
    return rows.map(LroHistory.fromMap).toList();
  }

  Future<List<LroHistory>> getPendingLroHistory() async {
    if (_memoryMode) {
      return _lroHistory.values.where((h) => h.pendingSync).toList();
    }
    final rows = await db.query('lro_history', where: 'pendingSync = 1');
    return rows.map(LroHistory.fromMap).toList();
  }

  Future<void> markLroHistorySynced(String id) async {
    if (_memoryMode) {
      final h = _lroHistory[id];
      if (h != null) _lroHistory[id] = h.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_history',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

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
    _db = await openDatabase(path);
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
  }
}
