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
      // Legacy roles collapse to member (or secretary if was privileged — treat as member).
      return UserRole.member;
    }
    return UserRole.member;
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isSecretary => this == UserRole.secretary;
  bool get isMember => this == UserRole.member;
}

/// Drawer / module permissions assignable to Recording Secretaries.
enum AppPermission {
  search('search', 'Search'),
  memberInfo('memberInfo', '1_Member Info'),
  global528('global528', '2_Global 528'),
  global928('global928', '3_Global 928'),
  lro('lro', '4_LRO'),
  sos('sos', 'SOS'),
  reminders('reminders', 'Reminders'),
  activities('activities', 'Activities');

  const AppPermission(this.code, this.label);
  final String code;
  final String label;

  /// Permissions Admin may grant to Recording Secretaries.
  static const assignable = AppPermission.values;

  static AppPermission? fromCode(String? code) {
    for (final p in AppPermission.values) {
      if (p.code == code) return p;
    }
    return null;
  }

  static List<AppPermission> parseList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final parts = raw.contains(',')
        ? raw.split(',')
        : raw.split('|');
    final out = <AppPermission>[];
    for (final part in parts) {
      final p = fromCode(part.trim());
      if (p != null) out.add(p);
    }
    return out;
  }

  static String encodeList(Iterable<AppPermission> perms) =>
      perms.map((p) => p.code).join(',');
}
