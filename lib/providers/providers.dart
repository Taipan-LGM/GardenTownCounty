import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_log.dart';
import '../models/app_user.dart';
import '../models/county_profile.dart';
import '../models/lookup_item.dart';
import '../models/member.dart';
import '../models/reminder.dart';
import '../models/role_definition.dart';
import '../models/sos_preset.dart';
import '../models/temporary_access_log.dart';
import '../models/user_role.dart';
import '../services/activity_service.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/auto_backup_scheduler.dart';
import '../services/backup_auth_service.dart';
import '../services/backup_service.dart';
import '../services/connectivity_service.dart';
import '../services/county_settings_service.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';
import '../services/member_repository.dart';
import '../services/member_lock_service.dart';
import '../services/temporary_access_service.dart';
import '../services/messaging_service.dart';
import '../services/sync_engine.dart';
import '../services/temp_access_expiry_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref.watch(databaseServiceProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(databaseServiceProvider));
});

final authUserProvider = StateProvider<AuthUser?>((ref) => null);

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authUserProvider)?.isAdmin ?? false;
});

final isSecretaryProvider = Provider<bool>((ref) {
  return ref.watch(authUserProvider)?.isSecretary ?? false;
});

final hasPermissionProvider = Provider.family<bool, AppPermission>((ref, permission) {
  final user = ref.watch(authUserProvider);
  if (user == null) return false;
  return user.hasPermission(permission);
});

final appPreferencesServiceProvider = Provider<AppPreferencesService>((ref) {
  return AppPreferencesService();
});

final countySettingsServiceProvider = Provider<CountySettingsService>((ref) {
  return CountySettingsService();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final appLanguageProvider =
    StateProvider<AppLanguage>((ref) => AppLanguage.english);

final countyProfileProvider =
    FutureProvider.autoDispose<CountyProfile>((ref) async {
  return ref.watch(countySettingsServiceProvider).load();
});

/// True after splash logo animation finishes (session).
final landingCompleteProvider = StateProvider<bool>((ref) => false);

final backupAuthServiceProvider = Provider<BackupAuthService>((ref) {
  return BackupAuthService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(databaseServiceProvider),
    ref.watch(backupAuthServiceProvider),
  );
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref.watch(syncEngineProvider));
});

final autoBackupSchedulerProvider = Provider<AutoBackupScheduler>((ref) {
  return AutoBackupScheduler(
    ref.watch(backupAuthServiceProvider),
    ref.watch(backupServiceProvider),
  );
});

final backupAuthProvider =
    FutureProvider.autoDispose<BackupAuthInfo>((ref) async {
  return ref.watch(backupAuthServiceProvider).checkAuthorization();
});

final lastBackupAtProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
  return ref.watch(backupAuthServiceProvider).lastBackupAt();
});

final syncStatusProvider = StreamProvider<SyncState>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  yield engine.state;
  yield* engine.statusStream;
});

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
  );
});

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
  );
});

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
  );
});

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

final memberLockServiceProvider = Provider<MemberLockService>((ref) {
  return MemberLockService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
    ref.watch(activityServiceProvider),
  );
});

final temporaryAccessServiceProvider = Provider<TemporaryAccessService>((ref) {
  return TemporaryAccessService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
    ref.watch(activityServiceProvider),
  );
});

final tempAccessExpiryServiceProvider = Provider<TempAccessExpiryService>((ref) {
  final service = TempAccessExpiryService(
    ref.watch(temporaryAccessServiceProvider),
  );
  ref.onDispose(service.stop);
  return service;
});

final temporaryAccessLogsProvider =
    FutureProvider.autoDispose<List<TemporaryAccessLog>>((ref) async {
  return ref.watch(databaseServiceProvider).getAllTemporaryAccessLogs();
});

/// Session-verified temporary access member IDs (after code entry).
final verifiedTempAccessIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

final lockedMembersProvider =
    FutureProvider.autoDispose<List<Member>>((ref) async {
  return ref.watch(databaseServiceProvider).getLockedMembers();
});

final membersProvider =
    FutureProvider.autoDispose<List<Member>>((ref) async {
  return ref.watch(memberRepositoryProvider).getAll();
});

final lookupsProvider =
    FutureProvider.autoDispose.family<List<LookupItem>, LookupType>(
  (ref, type) async {
    return ref.watch(memberRepositoryProvider).getLookups(type);
  },
);

final activitiesProvider =
    FutureProvider.autoDispose<List<ActivityLog>>((ref) async {
  return ref.watch(activityServiceProvider).list();
});

final sosPresetsProvider =
    FutureProvider.autoDispose<List<SosPreset>>((ref) async {
  return ref.watch(databaseServiceProvider).getSosPresets();
});

final appUsersProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  return ref.watch(authServiceProvider).listOperators();
});

final rolesProvider =
    FutureProvider.autoDispose<List<RoleDefinition>>((ref) async {
  return ref.watch(authServiceProvider).listRoles();
});

final remindersProvider =
    FutureProvider.autoDispose<List<Reminder>>((ref) async {
  return ref.watch(databaseServiceProvider).getReminders();
});

/// Navigation target shown inside the shell after login.
enum AppSection {
  home,
  settings,
  memberInfo,
  sos,
  reminders,
  activities,
  addUser,
  backupRestore,
  global528,
  global928,
  lro,
  lockedMembers,
  onboarding,
}

final appSectionProvider = StateProvider<AppSection>((ref) => AppSection.home);

final selectedMemberIdProvider = StateProvider<String?>((ref) => null);

/// Bump to force screens that key off this value to reload (e.g. Member form).
final appRefreshTickProvider = StateProvider<int>((ref) => 0);

/// Pull-to-refresh: sync cloud + invalidate cached lists.
Future<void> refreshApp(WidgetRef ref) async {
  await ref.read(syncEngineProvider).pushPending();
  ref.invalidate(membersProvider);
  ref.invalidate(lockedMembersProvider);
  ref.invalidate(activitiesProvider);
  ref.invalidate(sosPresetsProvider);
  ref.invalidate(appUsersProvider);
  ref.invalidate(rolesProvider);
  ref.invalidate(remindersProvider);
  ref.invalidate(backupAuthProvider);
  ref.invalidate(lastBackupAtProvider);
  ref.invalidate(countyProfileProvider);
  for (final type in LookupType.values) {
    ref.invalidate(lookupsProvider(type));
  }
  ref.read(appRefreshTickProvider.notifier).state++;
}
