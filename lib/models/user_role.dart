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

/// Drawer / module permissions.
///
/// **Keep in sync with** `lib/navigation/app_drawer_catalog.dart`.
/// Adding a drawer button: update the catalog first, then add/adjust the
/// matching [AppPermission] value and lists below. Run
/// `drawer_catalog_sync_test.dart` to verify.
enum AppPermission {
  home('home', 'Home'),
  search('search', 'Search'),
  memberInfo('memberInfo', 'Application Form'),
  global528('global528', 'Step 1_Global 528'),
  global528Step2('global528Step2', 'Step 2_Global 528'),
  global928('global928', 'Step 3_Global 928'),
  lro('lro', 'Step 4_LRO'),
  credentialCard('credentialCard', 'Step 5_Credential Card'),
  backupRestore('backupRestore', 'Backup & Restore'),
  userManagement('userManagement', 'RS Rights'),
  cancellations('cancellations', 'Cancellations'),
  duplicateManagement('duplicateManagement', 'Duplicate Manager'),
  sos('sos', 'SOS'),
  reminders('reminders', 'Reminders'),
  activities('activities', 'Activities'),
  demoData('demoData', 'Demo Data'),
  signOut('signOut', 'Sign Out'),
  /// Internal (not a drawer row) — temporary unlock / onboarding flows.
  onboarding('onboarding', 'Onboarding');

  const AppPermission(this.code, this.label);
  final String code;
  final String label;

  /// RS Rights toggle order = drawer order + onboarding.
  static const managementOrder = [
    home,
    search,
    memberInfo,
    global528,
    global528Step2,
    global928,
    lro,
    credentialCard,
    backupRestore,
    userManagement,
    cancellations,
    duplicateManagement,
    sos,
    reminders,
    activities,
    demoData,
    signOut,
    onboarding,
  ];

  /// Default rights on promote → Recording Secretary (matches drawer defaults).
  /// Admin may later turn any of these off in RS Rights.
  static const defaultSecretary = [
    home,
    search,
    memberInfo,
    global528,
    global528Step2,
    global928,
    lro,
    credentialCard,
    sos,
    reminders,
    activities,
  ];

  /// Formerly locked-on rights. Empty: Admin may deactivate any assignable right.
  static const requiredSecretary = <AppPermission>[];

  /// Extra rights Admin may grant beyond [defaultSecretary].
  static const optionalSecretary = [
    onboarding,
  ];

  /// May be granted to Recording Secretaries.
  static const assignable = [
    ...defaultSecretary,
    ...optionalSecretary,
  ];

  /// Always Admin-only — shown locked OFF in RS Rights.
  static const adminOnly = [
    backupRestore,
    userManagement,
    cancellations,
    duplicateManagement,
    demoData,
    signOut,
  ];

  bool get isAdminOnly => adminOnly.contains(this);

  bool get isRequiredForSecretary => requiredSecretary.contains(this);

  bool get isOptionalForSecretary => optionalSecretary.contains(this);

  bool get isDefaultForSecretary => defaultSecretary.contains(this);

  /// Normalize requested rights: drop Admin-only; keep only assignable.
  /// Does **not** force defaults back on — Admin may clear any right.
  static List<AppPermission> mergeSecretaryPermissions(
    Iterable<AppPermission> requested,
  ) {
    final selected = <AppPermission>{};
    for (final p in requested) {
      if (p.isAdminOnly) continue;
      if (assignable.contains(p)) {
        selected.add(p);
      }
    }
    return managementOrder.where(selected.contains).toList();
  }

  static AppPermission? fromCode(String? code) {
    if (code == null) return null;
    final c = code.trim();
    const aliases = <String, String>{
      'application_form': 'memberInfo',
      'applicationForm': 'memberInfo',
      'step1_global528': 'global528',
      'step1Global528': 'global528',
      'step2_global528': 'global528Step2',
      'step2Global528': 'global528Step2',
      'step3_global928': 'global928',
      'step3Global928': 'global928',
      'step4_lro': 'lro',
      'step4LRO': 'lro',
      'step5_credential': 'credentialCard',
      'step5Credential': 'credentialCard',
      'backup_restore': 'backupRestore',
      'user_management': 'userManagement',
      'duplicate_management': 'duplicateManagement',
      'demo_data': 'demoData',
      'sign_out': 'signOut',
    };
    final resolved = aliases[c] ?? c;
    for (final p in AppPermission.values) {
      if (p.code == resolved) return p;
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

/// Display-name constants for permission labels (docs / legacy).
class AppPermissions {
  static const String home = 'Home';
  static const String search = 'Search';
  static const String memberInfo = 'Application Form';
  static const String global528 = 'Step 1_Global 528';
  static const String global528Step2 = 'Step 2_Global 528';
  static const String global928 = 'Step 3_Global 928';
  static const String lro = 'Step 4_LRO';
  static const String credentialCard = 'Step 5_Credential Card';
  static const String backupRestore = 'Backup & Restore';
  static const String userManagement = 'RS Rights';
  static const String cancellations = 'Cancellations';
  static const String duplicateManagement = 'Duplicate Manager';
  static const String sos = 'SOS';
  static const String reminders = 'Reminders';
  static const String activities = 'Activities';
  static const String demoData = 'Demo Data';
  static const String signOut = 'Sign Out';
  static const String onboarding = 'Onboarding';

  static const List<String> defaultSecretaryPermissions = [
    home,
    search,
    memberInfo,
    global528,
    global528Step2,
    global928,
    lro,
    credentialCard,
    sos,
    reminders,
    activities,
  ];

  static const List<String> allPermissions = [
    home,
    search,
    memberInfo,
    global528,
    global528Step2,
    global928,
    lro,
    credentialCard,
    backupRestore,
    userManagement,
    cancellations,
    duplicateManagement,
    sos,
    reminders,
    activities,
    demoData,
    signOut,
    onboarding,
  ];
}
