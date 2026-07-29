import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_strings.dart';
import 'models/user_role.dart';
import 'providers/providers.dart';
import 'services/app_preferences_service.dart';
import 'services/auth_service.dart';
import 'services/reminder_expiry_service.dart';
import 'screens/activities/activities_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/backup/backup_restore_screen.dart';
import 'screens/home/info_content_screen.dart';
import 'screens/home/videos_content_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/member/duplicate_report_screen.dart';
import 'screens/member/cancellations_screen.dart';
import 'screens/member/member_form_screen.dart';
import 'screens/placeholders/placeholder_screen.dart';
import 'screens/reminders/reminders_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'screens/users/add_user_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/sync_status_indicator.dart';

class GardenTownCountyApp extends ConsumerWidget {
  const GardenTownCountyApp({super.key});

  /// Prefer rebuilding chrome without remounting MaterialApp (keeps session).
  /// Locale still drives Flutter's locale resolution for any Material widgets.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);
    final locale =
        language == AppLanguage.afrikaans ? const Locale('af') : const Locale('en');

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('af'),
      ],
      home: user == null ? const LoginScreen() : const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _backupReminderShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ReminderExpiryService.start(ref.read(reminderServiceProvider));
    });
  }

  @override
  void dispose() {
    ReminderExpiryService.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _maybeRemindBackup();
    }
  }


  Future<void> _maybeRemindBackup() async {
    if (_backupReminderShown) return;
    final isAdmin = ref.read(isAdminProvider);
    if (!isAdmin) return;
    final auth = await ref.read(backupAuthServiceProvider).checkAuthorization();
    if (!auth.authorized) return;
    final overdue =
        await ref.read(backupAuthServiceProvider).isBackupOverdue(days: 7);
    if (!overdue || !mounted) return;
    _backupReminderShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "It's been 7 days since your last backup. Please backup your data.",
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  void _onLandingFinished() {
    ref.read(landingCompleteProvider.notifier).state = true;
    ref.read(appSectionProvider.notifier).state = AppSection.home;
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(appSectionProvider);
    final refreshTick = ref.watch(appRefreshTickProvider);
    final user = ref.watch(authUserProvider);
    final language = ref.watch(appLanguageProvider);
    final strings = AppStrings(language);
    final effectiveSection = !_canAccessSection(section, user)
        ? AppSection.home
        : section;

    if (effectiveSection != section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appSectionProvider.notifier).state = AppSection.home;
      });
    }

    final isHomeHub = effectiveSection == AppSection.home ||
        effectiveSection == AppSection.settings ||
        effectiveSection == AppSection.countyInfo ||
        effectiveSection == AppSection.countyVideos;
    final showAppBar = !isHomeHub;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(strings.sectionTitle(effectiveSection)),
            )
          : null,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Builder(
              builder: (barContext) {
                return AppTopBar(
                  onOpenMenu: () {
                    Scaffold.of(barContext).openDrawer();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return RefreshIndicator(
                      color: AppTheme.gold,
                      backgroundColor: AppTheme.forestGreen,
                      displacement: 40,
                      onRefresh: () => refreshApp(ref),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          width: constraints.maxWidth,
                          child: effectiveSection == AppSection.home
                              ? LandingScreen(
                                  onFinished: _onLandingFinished,
                                )
                              : KeyedSubtree(
                                  key: ValueKey(
                                    'section-$effectiveSection-$refreshTick-${language.name}',
                                  ),
                                  child: _bodyFor(effectiveSection),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                const Positioned(
                  right: 16,
                  bottom: 16,
                  child: SyncStatusIndicator(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canAccessSection(AppSection section, AuthUser? user) {
    if (user == null) return section == AppSection.home;
    switch (section) {
      case AppSection.home:
      case AppSection.settings:
        return true;
      case AppSection.memberInfo:
        return user.hasPermission(AppPermission.memberInfo);
      case AppSection.sos:
        return user.hasPermission(AppPermission.sos);
      case AppSection.reminders:
        return user.hasPermission(AppPermission.reminders);
      case AppSection.activities:
        return user.hasPermission(AppPermission.activities);
      case AppSection.addUser:
      case AppSection.backupRestore:
      case AppSection.lockedMembers:
      case AppSection.duplicateReport:
        return user.isAdmin;
      case AppSection.global528:
        return user.hasPermission(AppPermission.global528);
      case AppSection.global528Step2:
        return user.hasPermission(AppPermission.global528Step2);
      case AppSection.global928:
        return user.hasPermission(AppPermission.global928);
      case AppSection.lro:
        return user.hasPermission(AppPermission.lro);
      case AppSection.credentialCard:
        return user.hasPermission(AppPermission.credentialCard);
      case AppSection.countyInfo:
      case AppSection.countyVideos:
        return true;
    }
  }

  Widget _bodyFor(AppSection section) {
    switch (section) {
      case AppSection.home:
        return LandingScreen(onFinished: _onLandingFinished);
      case AppSection.settings:
        return const SettingsScreen();
      case AppSection.memberInfo:
        return const MemberFormScreen();
      case AppSection.sos:
        return const SosScreen();
      case AppSection.reminders:
        return const RemindersScreen();
      case AppSection.activities:
        return const ActivitiesScreen();
      case AppSection.addUser:
        return const AddUserScreen();
      case AppSection.backupRestore:
        return const BackupRestoreScreen();
      case AppSection.global528:
        return const PlaceholderScreen(title: 'Step 1_Global 528');
      case AppSection.global528Step2:
        return const PlaceholderScreen(title: 'Step 2_Global 528');
      case AppSection.global928:
        return const PlaceholderScreen(title: 'Step 3_Global 928');
      case AppSection.lro:
        return const PlaceholderScreen(title: 'Step 4_LRO');
      case AppSection.credentialCard:
        return const PlaceholderScreen(title: 'Step 5_Credential Card');
      case AppSection.lockedMembers:
        return const CancellationsScreen();
      case AppSection.duplicateReport:
        return const DuplicateReportScreen();
      case AppSection.countyInfo:
        return const InfoContentScreen();
      case AppSection.countyVideos:
        return const VideosContentScreen();
    }
  }
}
