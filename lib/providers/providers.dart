import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_log.dart';
import '../models/app_user.dart';
import '../models/county_info.dart';
import '../models/county_profile.dart';
import '../models/county.dart';
import '../models/lookup_item.dart';
import '../models/live_view_data.dart';
import '../models/member.dart';
import '../models/reminder.dart';
import '../models/remuneration_settings.dart';
import '../models/role_definition.dart';
import '../models/sos_preset.dart';
import '../models/temporary_access_log.dart';
import '../models/user_role.dart';
import '../navigation/app_section.dart';
import '../l10n/app_strings.dart';
import '../models/lro_settings.dart';
import '../services/lro_settings_service.dart';

export '../navigation/app_section.dart';

import '../services/activity_service.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/auto_assignment_service.dart';
import '../services/auto_backup_scheduler.dart';
import '../services/backup_auth_service.dart';
import '../services/backup_service.dart';
import '../services/bulk_import_service.dart';
import '../services/card_payment_gateway.dart';
import '../services/claims_service.dart';
import '../services/connectivity_service.dart';
import '../services/county_info_service.dart';
import '../services/county_media_service.dart';
import '../services/county_settings_service.dart';
import '../services/database_service.dart';
import '../services/data_access_service.dart';
import '../services/file_storage_service.dart';
import '../services/demo_data_service.dart';
import '../services/promotion_service.dart';
import '../services/reminder_notification_service.dart';
import '../services/reminder_service.dart';
import '../services/remuneration_service.dart';
import '../services/member_duplicate_service.dart';
import '../services/member_repository.dart';
import '../services/member_lock_service.dart';
import '../services/free_upload_service.dart';
import '../services/temporary_access_service.dart';
import '../services/test_data_service.dart';
import '../services/smart_auto_assignment_service.dart';
import '../services/step_activation_service.dart';
import '../services/messaging_service.dart';
import '../services/sync_engine.dart';
import '../services/temp_access_expiry_service.dart';
import '../services/member_list_service.dart';

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

final hasPermissionProvider = Provider.family<bool, AppPermission>((
  ref,
  permission,
) {
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

// NEW ADDITION - County Information service/providers (Delete to revert)
final countyInfoServiceProvider = Provider<CountyInfoService>((ref) {
  return CountyInfoService(
    ref.watch(databaseServiceProvider),
    ref.watch(activityServiceProvider),
    ref.watch(countySettingsServiceProvider),
  );
});

final countyInfoProvider = FutureProvider.autoDispose<CountyInfo>((ref) async {
  return ref.watch(countyInfoServiceProvider).getCountyInfo();
});

/// Current active county id (Super Admin switches between counties).
/// Persisted via shared_preferences so it survives reloads.
final currentCountyIdProvider = StateProvider<String>((ref) => '');

final countiesProvider = FutureProvider.autoDispose<List<County>>((ref) async {
  return ref.watch(databaseServiceProvider).getCounties();
});

final currentCountyProvider = FutureProvider.autoDispose<County?>((ref) async {
  final id = ref.watch(currentCountyIdProvider);
  if (id.isEmpty) {
    final counties = await ref.watch(countiesProvider.future);
    return counties.isNotEmpty ? counties.first : null;
  }
  return ref.watch(databaseServiceProvider).getCountyById(id);
});

/// Resolved active county id used for scoping SharedPreferences-backed LRO
/// settings. Falls back to the first seeded county when none is selected.
final activeCountyIdProvider = Provider<String>((ref) {
  final selected = ref.watch(currentCountyIdProvider);
  if (selected.isNotEmpty) return selected;
  final counties = ref.watch(countiesProvider).valueOrNull;
  if (counties != null && counties.isNotEmpty) return counties.first.id;
  return '';
});

final countyMediaServiceProvider = Provider<CountyMediaService>((ref) {
  return CountyMediaService(ref.watch(databaseServiceProvider));
});

/// Land Recovery Office admin settings.
final lroSettingsServiceProvider = Provider<LroSettingsService>((ref) {
  return LroSettingsService();
});

final publishedArticlesProvider = FutureProvider((ref) {
  return ref.watch(countyMediaServiceProvider).getPublishedArticles();
});

final activeVideosProvider = FutureProvider((ref) {
  return ref.watch(countyMediaServiceProvider).getActiveVideos();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final appLanguageProvider = StateProvider<AppLanguage>(
  (ref) => AppLanguage.english,
);

final appStringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(appLanguageProvider));
});

/// Apply language immediately in UI, then persist (so the first tap works).
Future<void> setAppLanguage(WidgetRef ref, AppLanguage lang) async {
  ref.read(appLanguageProvider.notifier).state = lang;
  await ref.read(appPreferencesServiceProvider).saveLanguage(lang);
}

final countyProfileProvider = FutureProvider.autoDispose<CountyProfile>((
  ref,
) async {
  final countyId = ref.watch(activeCountyIdProvider);
  return ref.watch(countySettingsServiceProvider).load(countyId: countyId);
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

final backupAuthProvider = FutureProvider.autoDispose<BackupAuthInfo>((
  ref,
) async {
  return ref.watch(backupAuthServiceProvider).checkAuthorization();
});

final lastBackupAtProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  return ref.watch(backupAuthServiceProvider).lastBackupAt();
});

final syncStatusProvider = StreamProvider<SyncState>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  yield engine.state;
  yield* engine.statusStream;
});

final memberDuplicateServiceProvider = Provider<MemberDuplicateService>((ref) {
  return MemberDuplicateService(ref.watch(databaseServiceProvider));
});

final bulkImportServiceProvider = Provider<BulkImportService>((ref) {
  return BulkImportService(
    ref.watch(databaseServiceProvider),
    ref.watch(memberDuplicateServiceProvider),
  );
});

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
    ref.watch(memberDuplicateServiceProvider),
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

final cardPaymentGatewayProvider = Provider<CardPaymentGateway>((ref) {
  return CardPaymentGateway();
});

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

final memberLockServiceProvider = Provider<MemberLockService>((ref) {
  return MemberLockService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
    ref.watch(activityServiceProvider),
    // NEW ADDITION - wire remuneration on step complete
    remunerationService: ref.watch(remunerationServiceProvider),
  );
});

final freeUploadServiceProvider = Provider<FreeUploadService>((ref) {
  return FreeUploadService(
    ref.watch(databaseServiceProvider),
    ref.watch(memberLockServiceProvider),
    ref.watch(activityServiceProvider),
    ref.watch(lroSettingsServiceProvider),
    ref.watch(countySettingsServiceProvider),
    countyId: ref.watch(activeCountyIdProvider),
  );
});

final temporaryAccessServiceProvider = Provider<TemporaryAccessService>((ref) {
  return TemporaryAccessService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
    ref.watch(activityServiceProvider),
  );
});

final tempAccessExpiryServiceProvider = Provider<TempAccessExpiryService>((
  ref,
) {
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
final verifiedTempAccessIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

final lockedMembersProvider = FutureProvider.autoDispose<List<Member>>((
  ref,
) async {
  final user = ref.watch(authUserProvider);
  final locked = await ref.watch(databaseServiceProvider).getLockedMembers();
  if (user == null || user.isAdmin) return locked;
  final visible = await ref
      .watch(dataAccessServiceProvider)
      .getVisibleMembers(user);
  final ids = visible.map((m) => m.id).toSet();
  return locked.where((m) => ids.contains(m.id)).toList();
});

/// Soft-cancelled members (Admin Cancellations screen).
// NEW ADDITION - Delete provider to revert cancellations list
final cancelledMembersProvider = FutureProvider.autoDispose<List<Member>>((
  ref,
) async {
  final user = ref.watch(authUserProvider);
  if (user == null || !user.isAdmin) return const [];
  return ref.watch(databaseServiceProvider).getCancelledMembers();
});

// NEW ADDITION - role-scoped data access (Delete provider to revert)
final dataAccessServiceProvider = Provider<DataAccessService>((ref) {
  return DataAccessService(ref.watch(databaseServiceProvider));
});

final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) async {
  final user = ref.watch(authUserProvider);
  return ref.watch(dataAccessServiceProvider).getVisibleMembers(user);
});

final memberListServiceProvider = Provider<MemberListService>((ref) {
  return MemberListService(ref.watch(dataAccessServiceProvider));
});

final claimsServiceProvider = Provider<ClaimsService>((ref) {
  return ClaimsService();
});

/// Paginated members: `(page, query)` → [MemberPage].
final membersPageProvider = FutureProvider.autoDispose
    .family<MemberPage, ({int page, String query})>((ref, args) async {
      final user = ref.watch(authUserProvider);
      return ref
          .watch(memberListServiceProvider)
          .loadPage(
            user,
            page: args.page,
            query: args.query.isEmpty ? null : args.query,
          );
    });

final lookupsProvider = FutureProvider.autoDispose
    .family<List<LookupItem>, LookupType>((ref, type) async {
      return ref.watch(memberRepositoryProvider).getLookups(type);
    });

final activitiesProvider = FutureProvider.autoDispose<List<ActivityLog>>((
  ref,
) async {
  return ref.watch(activityServiceProvider).list();
});

final liveViewDataProvider = FutureProvider.autoDispose<LiveViewData>((
  ref,
) async {
  final database = ref.watch(databaseServiceProvider);
  final activityService = ref.watch(activityServiceProvider);
  final membersFuture = database.getAllMembers();
  final recordsFuture = database.getAllRemunerationRecords();
  final activitiesFuture = activityService.list();
  return LiveViewData(
    members: await membersFuture,
    remunerationRecords: await recordsFuture,
    activities: await activitiesFuture,
    generatedAt: DateTime.now(),
  );
});

final sosPresetsProvider = FutureProvider.autoDispose<List<SosPreset>>((
  ref,
) async {
  return ref.watch(databaseServiceProvider).getSosPresets();
});

final appUsersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  return ref.watch(authServiceProvider).listOperators();
});

final rolesProvider = FutureProvider.autoDispose<List<RoleDefinition>>((
  ref,
) async {
  return ref.watch(authServiceProvider).listRoles();
});

final remindersProvider = FutureProvider.autoDispose<List<Reminder>>((
  ref,
) async {
  return ref.watch(databaseServiceProvider).getReminders();
});

final reminderNotificationServiceProvider =
    Provider<ReminderNotificationService>((ref) {
      return ReminderNotificationService(ref.watch(databaseServiceProvider));
    });

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    ref.watch(databaseServiceProvider),
    ref.watch(syncEngineProvider),
    ref.watch(reminderNotificationServiceProvider),
    activityService: ref.watch(activityServiceProvider),
  );
});

// NEW ADDITION - RS services (Delete providers to revert)
final autoAssignmentServiceProvider = Provider<AutoAssignmentService>((ref) {
  return AutoAssignmentService(
    ref.watch(databaseServiceProvider),
    notifications: ref.watch(reminderNotificationServiceProvider),
  );
});

final remunerationServiceProvider = Provider<RemunerationService>((ref) {
  return RemunerationService(
    ref.watch(databaseServiceProvider),
    notifications: ref.watch(reminderNotificationServiceProvider),
    activity: ref.watch(activityServiceProvider),
  );
});

final remunerationSettingsProvider =
    AsyncNotifierProvider<RemunerationSettingsNotifier, RemunerationSettings>(
      RemunerationSettingsNotifier.new,
    );

class RemunerationSettingsNotifier extends AsyncNotifier<RemunerationSettings> {
  @override
  Future<RemunerationSettings> build() {
    return ref.watch(remunerationServiceProvider).getSettings();
  }

  Future<void> save(RemunerationSettings settings) async {
    await ref.read(remunerationServiceProvider).saveSettings(settings);
    state = AsyncData(settings);
  }
}

final testDataServiceProvider = Provider<TestDataService>((ref) {
  return TestDataService(ref.watch(databaseServiceProvider));
});

// NEW ADDITION - demo data + smart auto-assign (Delete providers to revert)
final demoDataServiceProvider = Provider<DemoDataService>((ref) {
  return DemoDataService(ref.watch(databaseServiceProvider));
});

final smartAutoAssignmentServiceProvider = Provider<SmartAutoAssignmentService>(
  (ref) {
    return SmartAutoAssignmentService(
      ref.watch(databaseServiceProvider),
      notifications: ref.watch(reminderNotificationServiceProvider),
    );
  },
);

// NEW ADDITION - promotion service (Delete to revert)
final promotionServiceProvider = Provider<PromotionService>((ref) {
  return PromotionService(
    ref.watch(authServiceProvider),
    ref.watch(databaseServiceProvider),
    ref.watch(activityServiceProvider),
    notifications: ref.watch(reminderNotificationServiceProvider),
    claims: ref.watch(claimsServiceProvider),
  );
});

// NEW ADDITION - Step 1 auto-activation (Delete provider to revert)
final stepActivationServiceProvider = Provider<StepActivationService>((ref) {
  return StepActivationService(
    ref.watch(databaseServiceProvider),
    ref.watch(reminderServiceProvider),
    ref.watch(activityServiceProvider),
    notifications: ref.watch(reminderNotificationServiceProvider),
  );
});

final activeOnboardingRemindersProvider =
    FutureProvider.autoDispose<List<Reminder>>((ref) async {
      final user = ref.watch(authUserProvider);
      return ref.watch(dataAccessServiceProvider).getVisibleReminders(user);
    });

final reminderStatsProvider = FutureProvider.autoDispose<ReminderStats>((
  ref,
) async {
  final reminders = await ref.watch(activeOnboardingRemindersProvider.future);
  return ReminderStats.fromReminders(reminders);
});

final activeReminderCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final reminders = await ref.watch(activeOnboardingRemindersProvider.future);
  return reminders.length;
});

/// Navigation target shown inside the shell after login.
/// Main shell navigation sections — see [AppSection] in app_section.dart.
final appSectionProvider = StateProvider<AppSection>((ref) => AppSection.home);

final selectedMemberIdProvider = StateProvider<String?>((ref) => null);

/// Bump to force screens that key off this value to reload (e.g. Member form).
final appRefreshTickProvider = StateProvider<int>((ref) => 0);

/// Pull-to-refresh: sync cloud + invalidate cached lists.
Future<void> refreshApp(WidgetRef ref) async {
  await ref.read(syncEngineProvider).pushPending();
  ref.invalidate(membersProvider);
  ref.invalidate(activitiesProvider);
  ref.invalidate(sosPresetsProvider);
  ref.invalidate(appUsersProvider);
  ref.invalidate(remindersProvider);
  ref.invalidate(activeOnboardingRemindersProvider);
  ref.invalidate(reminderStatsProvider);
  ref.invalidate(activeReminderCountProvider);
  ref.invalidate(publishedArticlesProvider);
  ref.invalidate(activeVideosProvider);
  ref.invalidate(countyProfileProvider);
  ref.invalidate(remunerationSettingsProvider);
  ref.invalidate(backupAuthProvider);
  ref.invalidate(lastBackupAtProvider);
  for (final type in LookupType.values) {
    ref.invalidate(lookupsProvider(type));
  }
  ref.read(appRefreshTickProvider.notifier).state++;
}
