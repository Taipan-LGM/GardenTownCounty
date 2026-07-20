import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/activities/activities_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/backup/backup_restore_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/member/member_form_screen.dart';
import 'screens/placeholders/placeholder_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'screens/users/add_user_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/county_logo.dart';
import 'widgets/sync_status_indicator.dart';

class GardenTownCountyApp extends ConsumerWidget {
  const GardenTownCountyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
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
  }

  @override
  void dispose() {
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
    // Stay on Home — first logo remains fixed as background.
    ref.read(appSectionProvider.notifier).state = AppSection.home;
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(appSectionProvider);
    final refreshTick = ref.watch(appRefreshTickProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final landingComplete = ref.watch(landingCompleteProvider);

    final effectiveSection = (!isAdmin &&
            (section == AppSection.activities ||
                section == AppSection.addUser ||
                section == AppSection.backupRestore))
        ? AppSection.home
        : section;

    if (effectiveSection != section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appSectionProvider.notifier).state = AppSection.home;
      });
    }

    final showLandingChrome = effectiveSection == AppSection.home;

    return Scaffold(
      appBar: showLandingChrome
          ? null
          : AppBar(
              title: Text(_titleFor(effectiveSection)),
            ),
      drawer: const AppDrawer(),
      body: Stack(
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
                    child: showLandingChrome
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              LandingScreen(onFinished: _onLandingFinished),
                              SafeArea(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Builder(
                                    builder: (context) {
                                      return IconButton(
                                        icon: const Icon(
                                          Icons.menu,
                                          color: AppTheme.gold,
                                          size: 32,
                                        ),
                                        tooltip: 'Open menu',
                                        onPressed: () =>
                                            Scaffold.of(context).openDrawer(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              // First + second logos share the same back layer.
                              if (landingComplete) ...[
                                const IgnorePointer(
                                  child: FixedFirstLogoBackground(),
                                ),
                                // Must be a direct Stack child (Positioned).
                                const CornerLogoOverlay(),
                              ],
                              ColoredBox(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor
                                    .withValues(
                                      alpha: landingComplete ? 0.92 : 1,
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    'section-$effectiveSection-$refreshTick',
                                  ),
                                  child: _bodyFor(effectiveSection),
                                ),
                              ),
                            ],
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
    );
  }

  String _titleFor(AppSection section) {
    switch (section) {
      case AppSection.home:
        return 'Home';
      case AppSection.settings:
        return 'Settings';
      case AppSection.memberInfo:
        return 'Member Info';
      case AppSection.sos:
        return 'SOS';
      case AppSection.activities:
        return 'Activities';
      case AppSection.addUser:
        return 'Add User';
      case AppSection.backupRestore:
        return 'Backup & Restore';
      case AppSection.global528:
        return 'Global 528';
      case AppSection.global928:
        return 'Global 928';
      case AppSection.lro:
        return 'LRO';
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
      case AppSection.activities:
        return const ActivitiesScreen();
      case AppSection.addUser:
        return const AddUserScreen();
      case AppSection.backupRestore:
        return const BackupRestoreScreen();
      case AppSection.global528:
        return const PlaceholderScreen(title: 'Global 528');
      case AppSection.global928:
        return const PlaceholderScreen(title: 'Global 928');
      case AppSection.lro:
        return const PlaceholderScreen(title: 'LRO');
    }
  }
}
