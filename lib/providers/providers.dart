import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_log.dart';
import '../models/lookup_item.dart';
import '../models/member.dart';
import '../models/sos_preset.dart';
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';
import '../services/member_repository.dart';
import '../services/messaging_service.dart';
import '../services/sync_engine.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref.watch(databaseServiceProvider));
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authUserProvider = StateProvider<AuthUser?>((ref) => null);

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

/// Navigation target shown inside the shell after login.
enum AppSection {
  home,
  memberInfo,
  sos,
  activities,
  global528,
  global928,
  lro,
}

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
  for (final type in LookupType.values) {
    ref.invalidate(lookupsProvider(type));
  }
  ref.read(appRefreshTickProvider.notifier).state++;
}
