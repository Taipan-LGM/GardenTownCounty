import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/activities/activities_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/member/member_form_screen.dart';
import 'screens/placeholders/placeholder_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'widgets/app_drawer.dart';

class GardenTownCountyApp extends ConsumerWidget {
  const GardenTownCountyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: user == null ? const LoginScreen() : const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);
    final refreshTick = ref.watch(appRefreshTickProvider);
    final isHome = section == AppSection.home;

    return Scaffold(
      appBar: isHome
          ? null
          : AppBar(
              title: Text(_titleFor(section)),
            ),
      drawer: const AppDrawer(),
      body: LayoutBuilder(
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
                child: isHome
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          const LandingScreen(),
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
                    : KeyedSubtree(
                        key: ValueKey('section-$section-$refreshTick'),
                        child: _bodyFor(section),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _titleFor(AppSection section) {
    switch (section) {
      case AppSection.home:
        return 'Home';
      case AppSection.memberInfo:
        return 'Member Info';
      case AppSection.sos:
        return 'SOS';
      case AppSection.activities:
        return 'Activities';
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
        return const LandingScreen();
      case AppSection.memberInfo:
        return const MemberFormScreen();
      case AppSection.sos:
        return const SosScreen();
      case AppSection.activities:
        return const ActivitiesScreen();
      case AppSection.global528:
        return const PlaceholderScreen(title: 'Global 528');
      case AppSection.global928:
        return const PlaceholderScreen(title: 'Global 928');
      case AppSection.lro:
        return const PlaceholderScreen(title: 'LRO');
    }
  }
}
