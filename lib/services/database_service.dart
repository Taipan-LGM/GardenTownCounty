import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File, Directory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants/app_constants.dart';
import '../core/exceptions/duplicate_exception.dart';
import '../models/activity_log.dart';
import '../models/app_user.dart';
import '../models/county_article.dart';
import '../models/county_info.dart';
import '../models/county_video.dart';
import '../models/lookup_item.dart';
import '../models/lro_case.dart';
import '../models/lro_document.dart';
import '../models/lro_notice.dart';
import '../models/lro_publication.dart';
import '../models/lro_history.dart';
import '../models/lro_notice.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import '../models/reminder.dart';
import '../models/remuneration_settings.dart';
import '../models/role_definition.dart';
import '../models/secretary_remuneration.dart';
import '../models/sos_preset.dart';
import '../models/temporary_access_log.dart';
import 'password_hasher.dart';

part 'database/db_roles_users.dart';
part 'database/db_reminders.dart';
part 'database/db_members.dart';
part 'database/db_lookups_files.dart';
part 'database/db_activities_sos.dart';
part 'database/db_lro.dart';
part 'database/db_lro_publications.dart';
part 'database/db_snapshot.dart';
part 'database/db_assignment_remuneration.dart';
part 'database/db_county.dart';

/// Shared state for [DatabaseService].
///
/// A Dart class body cannot span part files, so the storage plus the
/// signatures each section calls across section boundaries live here, and
/// every section is a mixin declared in `database/db_*.dart`.
abstract class _DatabaseServiceBase {
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
  // NEW ADDITION - RS remuneration memory maps (Delete maps + methods to revert)
  final Map<String, RemunerationSettings> _remunerationSettings = {};
  final Map<String, SecretaryRemuneration> _secretaryRemunerations = {};
  // NEW ADDITION - county_info single-row cache (Delete to revert)
  CountyInfo? _countyInfo;
  final Map<String, CountyArticle> _articles = {};
  final Map<String, CountyVideo> _videos = {};

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService not initialized. Call init() first.');
    }
    return database;
  }

  // Implemented by the mixins below (or by DatabaseService itself);
  // declared here so any section can call across section boundaries.
  Future<void> ensureSeedAdmin();
  Future<List<AppUser>> getAppUsers();
  Future<void> softDeleteAppUser(String id);
  Future<Member?> getMemberById(String id);
  Future<void> upsertMember(Member member);
  Future<List<Member>> getMembersAssignedToSecretary(String secretaryId);
  Future<Reminder?> getReminderById(String id);
  Future<void> upsertReminder(Reminder reminder);
  Future<List<Reminder>> getActiveOnboardingReminders();
  Future<void> _onCreate(Database database, int version);
  Future<void> _onUpgrade(Database database, int oldVersion, int newVersion);
}

/// Offline-first SQLite access layer for Garden Town County.
/// On web, uses an in-memory store (SQLite is unavailable in browsers).
class DatabaseService extends _DatabaseServiceBase
    with
        _DbRolesUsers,
        _DbReminders,
        _DbMembers,
        _DbLookupsFiles,
        _DbActivitiesSos,
        _DbLro,
        _DbSnapshot,
        _DbAssignmentRemuneration,
        _DbCounty {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

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
    _lroPublications.clear();
    _reminders.clear();
    _tempAccessLogs.clear();
    // NEW ADDITION - RS remuneration
    _remunerationSettings.clear();
    _secretaryRemunerations.clear();
    _countyInfo = null;
    _articles.clear();
    _videos.clear();
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
      version: 24,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _initialized = true;
    await ensureSeedAdmin();
  }

  @override
  Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE members ADD COLUMN photoLocalPath TEXT',
      );
      await database.execute('ALTER TABLE members ADD COLUMN photoUrl TEXT');
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
      await _addColumnIfMissing(
        database,
        'reminders',
        'kind',
        "TEXT DEFAULT 'manual'",
      );
      await _addColumnIfMissing(database, 'reminders', 'stepNumber', 'INTEGER');
      await _addColumnIfMissing(
        database,
        'reminders',
        'stepDescription',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'reminders', 'memberName', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'surname', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'saId', 'TEXT');
      await _addColumnIfMissing(database, 'reminders', 'expiryDate', 'TEXT');
      await _addColumnIfMissing(
        database,
        'reminders',
        'status',
        "TEXT DEFAULT 'active'",
      );
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
    // NEW ADDITION - RS assignment + remuneration (Delete block to revert v12)
    if (oldVersion < 12) {
      await _addColumnIfMissing(
        database,
        'members',
        'assignedSecretaryId',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'assignedSecretaryName',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'members', 'assignedDate', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'assignedBy', 'TEXT');
      await _addColumnIfMissing(
        database,
        'members',
        'assignmentMethod',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'reminders',
        'assignedSecretaryId',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'reminders',
        'assignedSecretaryName',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'reminders', 'assignedDate', 'TEXT');
      await _addColumnIfMissing(
        database,
        'reminders',
        'assignmentMethod',
        'TEXT',
      );
      await _createRemunerationTables(database);
    }
    // NEW ADDITION - LRO Record No. (Delete block to revert v13)
    if (oldVersion < 13) {
      await _addColumnIfMissing(database, 'members', 'lroRecordNo', 'TEXT');
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_lroRecordNo ON members(lroRecordNo)',
      );
    }
    // NEW ADDITION - soft cancellation columns (Delete block to revert v14)
    if (oldVersion < 14) {
      await _addColumnIfMissing(database, 'members', 'isCancelled', 'INTEGER');
      await _addColumnIfMissing(
        database,
        'members',
        'cancellationDate',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'members', 'cancelledBy', 'TEXT');
      await _addColumnIfMissing(
        database,
        'members',
        'cancellationReason',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'members', 'reinstatedDate', 'TEXT');
      await _addColumnIfMissing(database, 'members', 'reinstatedBy', 'TEXT');
    }
    // NEW ADDITION - county_info table (Delete block to revert v15)
    if (oldVersion < 15) {
      await _createCountyInfoTable(database);
    }
    // NEW ADDITION - countyContactNo (Delete block to revert v16)
    if (oldVersion < 16) {
      await _addColumnIfMissing(
        database,
        'county_info',
        'countyContactNo',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 17) {
      await _createCountyMediaTables(database);
    }
    // v18: drop UNIQUE on saId/globalRecordNo so Duplicate Manager can
    // surface (and demo can seed) true collisions. App-level checks remain.
    if (oldVersion < 18) {
      await _migrateMembersDropUniques(database);
    }
    if (oldVersion < 19) {
      await _addColumnIfMissing(
        database,
        'members',
        'step5CredentialCardComplete',
        'INTEGER',
      );
      await _addColumnIfMissing(
        database,
        'members',
        'step5CompletionDate',
        'TEXT',
      );
      await _addColumnIfMissing(database, 'members', 'step5ApprovedBy', 'TEXT');
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step1Amount',
        'REAL',
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step5Amount',
        'REAL',
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'bankDetails',
        'TEXT',
      );
    }
    if (oldVersion < 20) {
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'bankAccountName',
        "TEXT NOT NULL DEFAULT 'Garden Town County'",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'bankName',
        "TEXT NOT NULL DEFAULT 'Capitec Bank'",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'bankAccountNumber',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'bankAccountCode',
        "TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 21) {
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step1Name',
        "TEXT NOT NULL DEFAULT 'Step 1_Global 528'",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step2Name',
        "TEXT NOT NULL DEFAULT 'Step 2_Global 528'",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step3Name',
        "TEXT NOT NULL DEFAULT 'Step 3_Global 928'",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step4Name',
        "TEXT NOT NULL DEFAULT 'Step 4_LRO'",
      );
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'step5Name',
        "TEXT NOT NULL DEFAULT 'Step 5_Credential Card'",
      );
    }
    if (oldVersion < 22) {
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'stepsJson',
        "TEXT NOT NULL DEFAULT '[]'",
      );
      await _addColumnIfMissing(
        database,
        'members',
        'memberStepsJson',
        "TEXT NOT NULL DEFAULT '{}'",
      );
    }
    if (oldVersion < 23) {
      await _addColumnIfMissing(
        database,
        'member_files',
        'stepNumber',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        database,
        'member_files',
        'uploadConfirmed',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 24) {
      await _addColumnIfMissing(
        database,
        'remuneration_settings',
        'descriptionTemplatesJson',
        "TEXT NOT NULL DEFAULT '{}'",
      );
    }
  }

  /// Rebuild members without UNIQUE(saId) / UNIQUE(globalRecordNo).
  Future<void> _migrateMembersDropUniques(Database database) async {
    await database.execute('PRAGMA foreign_keys = OFF');
    await database.execute('ALTER TABLE members RENAME TO members_v17');
    await database.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        saId TEXT NOT NULL,
        globalRecordNo TEXT NOT NULL,
        lroRecordNo TEXT,
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
        step5CredentialCardComplete INTEGER,
        step1CompletionDate TEXT,
        step2CompletionDate TEXT,
        step3CompletionDate TEXT,
        step4CompletionDate TEXT,
        step5CompletionDate TEXT,
        step1ApprovedBy TEXT,
        step2ApprovedBy TEXT,
        step3ApprovedBy TEXT,
        step4ApprovedBy TEXT,
        step5ApprovedBy TEXT,
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
        isCancelled INTEGER,
        cancellationDate TEXT,
        cancelledBy TEXT,
        cancellationReason TEXT,
        reinstatedDate TEXT,
        reinstatedBy TEXT,
        assignedSecretaryId TEXT,
        assignedSecretaryName TEXT,
        assignedDate TEXT,
        assignedBy TEXT,
        assignmentMethod TEXT,
        createdBy TEXT,
        lastModifiedBy TEXT,
        createdAt TEXT,
        updatedAt TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('INSERT INTO members SELECT * FROM members_v17');
    await database.execute('DROP TABLE members_v17');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_saId ON members(saId)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_members_globalRecordNo '
      'ON members(globalRecordNo)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lroRecordNo ON members(lroRecordNo)',
    );
    await database.execute('PRAGMA foreign_keys = ON');
  }

  // NEW ADDITION - Delete method to revert remuneration tables helper
  Future<void> _createRemunerationTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS remuneration_settings (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        step1Name TEXT NOT NULL DEFAULT 'Step 1_Global 528',
        step2Name TEXT NOT NULL DEFAULT 'Step 2_Global 528',
        step3Name TEXT NOT NULL DEFAULT 'Step 3_Global 928',
        step4Name TEXT NOT NULL DEFAULT 'Step 4_LRO',
        step5Name TEXT NOT NULL DEFAULT 'Step 5_Credential Card',
        step1Amount REAL NOT NULL DEFAULT 100,
        step2Amount REAL NOT NULL DEFAULT 200,
        step3Amount REAL NOT NULL DEFAULT 300,
        step4Amount REAL NOT NULL DEFAULT 250,
        step5Amount REAL NOT NULL DEFAULT 250,
        stepsJson TEXT NOT NULL DEFAULT '[]',
        descriptionTemplatesJson TEXT NOT NULL DEFAULT '{}',
        bankDetails TEXT NOT NULL DEFAULT 'Bank: Standard Bank\nAccount: 00123456789\nBranch: 001\nReference: Membership',
        bankAccountName TEXT NOT NULL DEFAULT 'Garden Town County',
        bankName TEXT NOT NULL DEFAULT 'Capitec Bank',
        bankAccountNumber TEXT NOT NULL DEFAULT '',
        bankAccountCode TEXT NOT NULL DEFAULT '',
        extraServicesJson TEXT NOT NULL DEFAULT '[]',
        lastUpdated TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS secretary_remuneration (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        secretaryId TEXT NOT NULL,
        secretaryName TEXT NOT NULL DEFAULT '',
        memberId TEXT NOT NULL,
        memberName TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL DEFAULT 0,
        extraServiceId TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        dateEarned TEXT NOT NULL,
        dateApproved TEXT,
        datePaid TEXT,
        notes TEXT,
        approvedBy TEXT,
        paidBy TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'pending',
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sec_remun_secretary '
      'ON secretary_remuneration(secretaryId)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sec_remun_status '
      'ON secretary_remuneration(status)',
    );
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
        completedBy TEXT,
        assignedSecretaryId TEXT,
        assignedSecretaryName TEXT,
        assignedDate TEXT,
        assignmentMethod TEXT
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
        stepNumber INTEGER NOT NULL DEFAULT 1,
        uploadConfirmed INTEGER NOT NULL DEFAULT 0,
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

    await database.execute('''
      CREATE TABLE IF NOT EXISTS lro_publications (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        memberId TEXT NOT NULL,
        memberName TEXT NOT NULL,
        recordingNumber TEXT NOT NULL,
        imageBytes BLOB,
        publishedAt TEXT NOT NULL,
        facebookPostId TEXT,
        actorId TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_publications_member ON lro_publications(memberId)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_publications_pendingsync ON lro_publications(pendingSync)',
    );
  }

  @override
  Future<void> _onCreate(Database database, int version) async {
    await database.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        saId TEXT NOT NULL,
        globalRecordNo TEXT NOT NULL,
        lroRecordNo TEXT,
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
        step5CredentialCardComplete INTEGER,
        step1CompletionDate TEXT,
        step2CompletionDate TEXT,
        step3CompletionDate TEXT,
        step4CompletionDate TEXT,
        step5CompletionDate TEXT,
        step1ApprovedBy TEXT,
        step2ApprovedBy TEXT,
        step3ApprovedBy TEXT,
        step4ApprovedBy TEXT,
        step5ApprovedBy TEXT,
        memberStepsJson TEXT NOT NULL DEFAULT '{}',
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
        isCancelled INTEGER,
        cancellationDate TEXT,
        cancelledBy TEXT,
        cancellationReason TEXT,
        reinstatedDate TEXT,
        reinstatedBy TEXT,
        assignedSecretaryId TEXT,
        assignedSecretaryName TEXT,
        assignedDate TEXT,
        assignedBy TEXT,
        assignmentMethod TEXT,
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
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lroRecordNo ON members(lroRecordNo)',
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
    // NEW ADDITION - RS remuneration tables on fresh create
    await _createRemunerationTables(database);
    // NEW ADDITION - county_info on fresh create
    await _createCountyInfoTable(database);
    await _createCountyMediaTables(database);
  }

  Future<void> _createCountyMediaTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS county_articles (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        author TEXT,
        pdfLocalPath TEXT,
        pdfUrl TEXT,
        imageUrl TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        isPublished INTEGER NOT NULL DEFAULT 1,
        category TEXT,
        viewCount INTEGER NOT NULL DEFAULT 0,
        createdBy TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'pending',
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS county_videos (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        videoLocalPath TEXT NOT NULL DEFAULT '',
        videoUrl TEXT,
        thumbnailLocalPath TEXT,
        thumbnailUrl TEXT,
        duration TEXT,
        uploadedAt TEXT NOT NULL,
        category TEXT,
        viewCount INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1,
        uploadedBy TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'pending',
        isDeleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // NEW ADDITION - Delete method to revert county_info table
  Future<void> _createCountyInfoTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS county_info (
        id TEXT PRIMARY KEY,
        firestoreId TEXT,
        countyName TEXT NOT NULL,
        countyAddress TEXT NOT NULL,
        countyContactNo TEXT NOT NULL DEFAULT '',
        countyRegistrationNo TEXT NOT NULL,
        lastUpdated TEXT NOT NULL,
        updatedBy TEXT NOT NULL DEFAULT 'system',
        syncStatus TEXT NOT NULL DEFAULT 'pending',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        lastResetDate TEXT,
        resetCount INTEGER NOT NULL DEFAULT 0,
        resetBy TEXT
      )
    ''');
  }

  @override
  Future<void> ensureSeedAdmin() async {
    await ensureSeedRoles();
    final existing = await getAppUserByUsername(AppConstants.demoUsername);
    if (existing == null) {
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
    // Ensure every Recording Secretary AppUser has a Member row (Admin list).
    // NEW ADDITION - Delete call to revert auto-link
    await ensureRecordingSecretaryMemberLinks();
  }

  /// Create/link Member profiles for RS AppUsers missing memberId.
  /// Admin Member List shows people via Member rows — orphan RS logins were invisible.
  // NEW ADDITION - Delete method to revert
  Future<void> ensureRecordingSecretaryMemberLinks() async {
    final users = await getAppUsers();
    final now = DateTime.now().toUtc();
    for (final user in users) {
      if (user.deleted || !user.isSecretary) continue;

      final linkedId = user.memberId?.trim();
      if (linkedId != null && linkedId.isNotEmpty) {
        final existing = await getMemberById(linkedId);
        if (existing != null && !existing.deleted) continue;
      }

      final memberId = (linkedId != null && linkedId.isNotEmpty)
          ? linkedId
          : 'rs_member_${user.id}';
      final parts = user.displayName.trim().split(RegExp(r'\s+'));
      final first = parts.isNotEmpty ? parts.first : user.username;
      final last = parts.length > 1 ? parts.sublist(1).join(' ') : 'Secretary';
      final saSeed = user.username.hashCode.abs().toString().padLeft(13, '0');
      final saId = saSeed.length >= 13
          ? saSeed.substring(0, 13)
          : saSeed.padRight(13, '0');

      final member = await getMemberById(memberId);
      if (member == null) {
        await upsertMember(
          Member(
            id: memberId,
            saId: saId,
            globalRecordNo: 'GR-RS-$memberId',
            memberName: first,
            surname: last,
            address: '1 Assembly Way',
            suburb: 'Garden Town',
            townCity: 'Garden Town',
            postalCode: '0001',
            contactNo1: '0820000000',
            contactNo2: '',
            emailAddress: '${user.username}@gardentown.local',
            registrationStatus: 'complete',
            isEmailVerified: true,
            step1MemberInfoComplete: true,
            step2Global528Complete: true,
            step3Global928Complete: true,
            step4LROComplete: false,
            userId: user.id,
            createdAt: now,
            updatedAt: now,
            pendingSync: true,
          ),
        );
      }

      if (user.memberId != memberId) {
        await upsertAppUser(
          user.copyWith(memberId: memberId, pendingSync: true, updatedAt: now),
        );
      }
    }
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
}
