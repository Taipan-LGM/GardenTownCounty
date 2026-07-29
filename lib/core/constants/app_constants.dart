class AppConstants {
  static const String appName = 'Garden Town County';
  /// Keep in sync with pubspec.yaml `version:` (name+build).
  /// Scheme: v1.18.12 … v1.18.99 → v1.19.00 → v1.19.01 …
  static const String appVersion = '1.18.23';
  static const String buildNumber = '86';
  static String get fullVersion => '$appVersion+$buildNumber';
  static String get versionLabel => 'v$fullVersion';

  static const String logoAsset = 'assets/images/county_logo.png';
  /// Default second / corner logo (blue Assembly seal).
  static const String logoAltAsset = 'assets/images/county_logo_alt.png';

  static const String membersCollection = 'members';
  static const String membersUniqueSaIdCollection = 'members_unique_sa_id';
  static const String membersUniqueGlobalRecordCollection =
      'members_unique_global_record';
  static const String lookupsCollection = 'lookups';
  static const String memberFilesCollection = 'member_files';
  static const String activitiesCollection = 'activities';
  static const String sosPresetsCollection = 'sos_presets';
  static const String appUsersCollection = 'app_users';
  static const String rolesCollection = 'roles';
  static const String remindersCollection = 'reminders';
  static const String temporaryAccessLogsCollection = 'temporary_access_logs';
  static const String countyInfoCollection = 'county_info';
  static const String countyArticlesCollection = 'county_articles';
  static const String countyVideosCollection = 'county_videos';
  static const String remunerationSettingsCollection = 'remuneration_settings';
  static const String secretaryRemunerationCollection =
      'secretary_remuneration';
  static const String lroCasesCollection = 'lro_cases';
  static const String lroNoticesCollection = 'lro_notices';
  static const String lroDocumentsCollection = 'lro_documents';
  static const String lroHistoryCollection = 'lro_history';

  /// Local backup authorization marker (Documents/GardenTown/.gardentown_auth).
  static const String backupAuthKeyLine = 'AUTH_KEY=GT528-GLOBAL';
  /// Legacy GTB1 decrypt only — new backups use a user-chosen password (GTB2).
  static const String backupMasterPassword = 'GardenTownSecureBackup2026';
  static const String gardenTownFolderName = 'GardenTown';
  static const String backupAuthFileName = '.gardentown_auth';
  static const String backupsFolderName = 'Backups';
  static const String autoBackupsFolderName = 'AutoBackups';
  static const int autoBackupRetentionDays = 7;
  static const int backupPasswordMinLength = 8;

  static const int saIdMaxLength = 13;
  static const int globalRecordNoMaxLength = 14;
  /// NEW ADDITION - LRO Record No. max length (Delete with field to revert)
  static const int lroRecordNoMaxLength = 14;
  static const int contactNoMaxLength = 12;

  /// Default page size for member list queries.
  static const int membersPageSize = 50;

  /// Seeded System Administrator account (local SQLite). Credentials are only
  /// pre-filled / shown in debug builds — see [allowDemoLoginUi].
  static const String demoUsername = 'admin';
  static const String demoPassword = 'garden2026';
  static const String demoDisplayName = 'County Administrator';
}
