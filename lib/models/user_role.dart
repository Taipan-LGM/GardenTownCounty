/// Canonical 3-tier roles for Garden Town County.
enum UserRole {
  admin('Admin', 'System Administrator'),
  secretary('Recording Secretary', 'Recording Secretary'),
  member('Member', 'Member');

  const UserRole(this.storageName, this.label);
  final String storageName;
  final String label;

  static UserRole fromStorage(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'admin' || v == 'system administrator') return UserRole.admin;
    if (v == 'secretary' ||
        v == 'recording secretary' ||
        v == 'recording_secretary') {
      return UserRole.secretary;
    }
    if (v == 'manager' || v == 'supervisor' || v == 'user') {
      return UserRole.member;
    }
    return UserRole.member;
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isSecretary => this == UserRole.secretary;
  bool get isMember => this == UserRole.member;
}

/// Drawer / module permissions (10 total; two Admin-only).
enum AppPermission {
  search('search', 'Search'),
  memberInfo('memberInfo', 'Member Info'),
  global528('global528', 'Global 528'),
  global928('global928', 'Global 928'),
  lro('lro', 'LRO'),
  backupRestore('backupRestore', 'Backup & Restore'),
  userManagement('userManagement', 'User Management'),
  sos('sos', 'SOS'),
  reminders('reminders', 'Reminders'),
  activities('activities', 'Activities');

  const AppPermission(this.code, this.label);
  final String code;
  final String label;

  /// Exact order for the User Management toggle list.
  static const managementOrder = [
    search,
    memberInfo,
    global528,
    global928,
    lro,
    backupRestore,
    userManagement,
    sos,
    reminders,
    activities,
  ];

  /// May be granted to Recording Secretaries.
  static const assignable = [
    search,
    memberInfo,
    global528,
    global928,
    lro,
    sos,
    reminders,
    activities,
  ];

  /// Always Admin-only — shown locked OFF in User Management.
  static const adminOnly = [
    backupRestore,
    userManagement,
  ];

  bool get isAdminOnly => adminOnly.contains(this);

  static AppPermission? fromCode(String? code) {
    for (final p in AppPermission.values) {
      if (p.code == code) return p;
    }
    return null;
  }

  static List<AppPermission> parseList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final parts = raw.contains(',') ? raw.split(',') : raw.split('|');
    final out = <AppPermission>[];
    for (final part in parts) {
      final p = fromCode(part.trim());
      if (p != null && !p.isAdminOnly) out.add(p);
    }
    return out;
  }

  static String encodeList(Iterable<AppPermission> perms) =>
      perms.where((p) => !p.isAdminOnly).map((p) => p.code).join(',');
}

/// Display-name constants for permission labels (User Management UI / docs).
class AppPermissions {
  static const String search = 'Search';
  static const String memberInfo = 'Member Info';
  static const String global528 = 'Global 528';
  static const String global928 = 'Global 928';
  static const String lro = 'LRO';
  static const String backupRestore = 'Backup & Restore';
  static const String userManagement = 'User Management';
  static const String sos = 'SOS';
  static const String reminders = 'Reminders';
  static const String activities = 'Activities';
}
