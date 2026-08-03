import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_strings.dart';
import 'models/remuneration_settings.dart';
import 'models/user_role.dart';
import 'providers/providers.dart';
import 'screens/activities/activities_screen.dart';
import 'screens/backup/backup_restore_screen.dart';
import 'screens/home/info_content_screen.dart';
import 'screens/home/videos_content_screen.dart';
import 'screens/live_view/live_view_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/member/cancellations_screen.dart';
import 'screens/member/duplicate_report_screen.dart';
import 'screens/member/member_form_screen.dart';
import 'screens/member/step_workflow_screen.dart';
import 'screens/reminders/reminders_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'screens/users/add_user_screen.dart';
import 'services/app_preferences_service.dart';
import 'services/auth_service.dart';
import 'services/reminder_expiry_service.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/sync_status_indicator.dart';

class GardenTownCountyApp extends ConsumerWidget {
  const GardenTownCountyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);
    final locale = language == AppLanguage.afrikaans
        ? const Locale('af')
        : const Locale('en');

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('af')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
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
  late final Map<AppSection, Widget> _sectionBodies;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sectionBodies = {
      AppSection.home: LandingScreen(onFinished: _onLandingFinished),
      AppSection.settings: const SettingsScreen(),
      AppSection.liveView: const LiveViewScreen(),
      AppSection.memberInfo: const MemberFormScreen(),
      AppSection.sos: const SosScreen(),
      AppSection.reminders: const RemindersScreen(),
      AppSection.activities: const ActivitiesScreen(),
      AppSection.addUser: const AddUserScreen(),
      AppSection.backupRestore: const BackupRestoreScreen(),
      AppSection.global528: const StepWorkflowScreen(stepNumber: 1),
      AppSection.global528Step2: const StepWorkflowScreen(stepNumber: 2),
      AppSection.global928: const StepWorkflowScreen(stepNumber: 3),
      AppSection.lro: const StepWorkflowScreen(stepNumber: 4),
      AppSection.credentialCard: const StepWorkflowScreen(stepNumber: 5),
      AppSection.lockedMembers: const CancellationsScreen(),
      AppSection.duplicateReport: const DuplicateReportScreen(),
      AppSection.countyInfo: const InfoContentScreen(),
      AppSection.countyVideos: const VideosContentScreen(),
    };
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
    final overdue = await ref
        .read(backupAuthServiceProvider)
        .isBackupOverdue(days: 7);
    if (!overdue || !mounted) return;
    _backupReminderShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings(ref.read(appLanguageProvider)).backupOverdue),
        duration: const Duration(seconds: 6),
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
    final remunerationSettings =
        ref.watch(remunerationSettingsProvider).valueOrNull ??
        RemunerationSettings.defaults();
    final effectiveSection = !_canAccessSection(section, user)
        ? AppSection.home
        : section;

    if (effectiveSection != section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appSectionProvider.notifier).state = AppSection.home;
      });
    }

    final isHomeHub =
        effectiveSection == AppSection.home ||
        effectiveSection == AppSection.settings ||
        effectiveSection == AppSection.liveView ||
        effectiveSection == AppSection.countyInfo ||
        effectiveSection == AppSection.countyVideos;
    final showAppBar = !isHomeHub;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(
                _sectionTitle(effectiveSection, strings, remunerationSettings),
              ),
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
                          child: KeyedSubtree(
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

  String _sectionTitle(
    AppSection section,
    AppStrings strings,
    RemunerationSettings settings,
  ) {
    return switch (section) {
      AppSection.global528 => strings.global528,
      AppSection.global528Step2 => settings.stepName(2),
      AppSection.global928 => settings.stepName(3),
      AppSection.lro => settings.stepName(4),
      AppSection.credentialCard => settings.stepName(5),
      _ => strings.sectionTitle(section),
    };
  }

  bool _canAccessSection(AppSection section, AuthUser? user) {
    if (user == null) return section == AppSection.home;
    switch (section) {
      case AppSection.home:
      case AppSection.settings:
        return true;
      case AppSection.liveView:
        return user.isAdmin;
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

  static int sectionIndexFor(AppSection section) {
    switch (section) {
      case AppSection.home:
        return 0;
      case AppSection.settings:
        return 1;
      case AppSection.liveView:
        return 2;
      case AppSection.memberInfo:
        return 3;
      case AppSection.sos:
        return 4;
      case AppSection.reminders:
        return 5;
      case AppSection.activities:
        return 6;
      case AppSection.addUser:
        return 7;
      case AppSection.backupRestore:
        return 8;
      case AppSection.global528:
        return 9;
      case AppSection.global528Step2:
        return 10;
      case AppSection.global928:
        return 11;
      case AppSection.lro:
        return 12;
      case AppSection.credentialCard:
        return 13;
      case AppSection.lockedMembers:
        return 14;
      case AppSection.duplicateReport:
        return 15;
      case AppSection.countyInfo:
        return 16;
      case AppSection.countyVideos:
        return 17;
    }
  }

  Widget _bodyFor(AppSection section) {
    final body =
        _sectionBodies[section] ??
        LandingScreen(onFinished: _onLandingFinished);
    return body;
  }
}
