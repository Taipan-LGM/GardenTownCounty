class AppConstants {
  static const String appName = 'Garden Town County';
  static const String logoAsset = 'assets/images/county_logo.png';

  static const String membersCollection = 'members';
  static const String lookupsCollection = 'lookups';
  static const String memberFilesCollection = 'member_files';
  static const String activitiesCollection = 'activities';
  static const String sosPresetsCollection = 'sos_presets';
  static const String appUsersCollection = 'app_users';

  /// Local backup authorization marker (Documents/GardenTown/.gardentown_auth).
  static const String backupAuthKeyLine = 'AUTH_KEY=GT528-GLOBAL';
  static const String backupMasterPassword = 'GardenTownSecureBackup2026';
  static const String gardenTownFolderName = 'GardenTown';
  static const String backupAuthFileName = '.gardentown_auth';
  static const String backupsFolderName = 'Backups';
  static const String autoBackupsFolderName = 'AutoBackups';
  static const int autoBackupRetentionDays = 7;

  static const int saIdMaxLength = 13;
  static const int globalRecordNoMaxLength = 14;
  static const int contactNoMaxLength = 12;

  /// Demo login when Firebase Auth is not configured.
  static const String demoUsername = 'admin';
  static const String demoPassword = 'garden2026';
  static const String demoDisplayName = 'County Administrator';
}
