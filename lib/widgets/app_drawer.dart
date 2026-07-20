import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../providers/providers.dart';
import '../screens/search/global_search_dialog.dart';
import 'county_logo.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);
    final user = ref.watch(authUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final profile = ref.watch(countyProfileProvider).valueOrNull;
    final countyName = profile?.countyName ?? 'Garden Town County';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.forestGreen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const RoundCountyLogo(size: 48),
                  const SizedBox(height: 8),
                  Text(
                    countyName,
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.displayName ?? 'Guest',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (user != null)
                    Text(
                      user.role,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            _item(
              context,
              ref,
              icon: Icons.home,
              label: strings.home,
              selected: section == AppSection.home,
              onTap: () => _go(context, ref, AppSection.home),
            ),
            _item(
              context,
              ref,
              icon: Icons.search,
              label: strings.search,
              selected: false,
              onTap: () async {
                Navigator.of(context).pop();
                await showGlobalSearchDialog(context, ref);
              },
            ),
            _item(
              context,
              ref,
              icon: Icons.settings,
              label: strings.settings,
              selected: section == AppSection.settings,
              onTap: () => _go(context, ref, AppSection.settings),
            ),
            _item(
              context,
              ref,
              icon: Icons.badge_outlined,
              label: strings.memberInfo,
              selected: section == AppSection.memberInfo,
              onTap: () => _go(context, ref, AppSection.memberInfo),
            ),
            _item(
              context,
              ref,
              icon: Icons.sos_outlined,
              label: strings.sos,
              selected: section == AppSection.sos,
              onTap: () => _go(context, ref, AppSection.sos),
            ),
            _item(
              context,
              ref,
              icon: Icons.public,
              label: strings.global528,
              selected: section == AppSection.global528,
              onTap: () => _go(context, ref, AppSection.global528),
            ),
            _item(
              context,
              ref,
              icon: Icons.public_outlined,
              label: strings.global928,
              selected: section == AppSection.global928,
              onTap: () => _go(context, ref, AppSection.global928),
            ),
            _item(
              context,
              ref,
              icon: Icons.account_balance,
              label: strings.lro,
              selected: section == AppSection.lro,
              onTap: () => _go(context, ref, AppSection.lro),
            ),
            if (isAdmin)
              _item(
                context,
                ref,
                icon: Icons.backup,
                label: strings.backupRestore,
                selected: section == AppSection.backupRestore,
                onTap: () => _go(context, ref, AppSection.backupRestore),
              ),
            if (isAdmin) ...[
              _item(
                context,
                ref,
                icon: Icons.person_add_alt_1,
                label: strings.addUser,
                selected: section == AppSection.addUser,
                onTap: () => _go(context, ref, AppSection.addUser),
              ),
              _item(
                context,
                ref,
                icon: Icons.timeline,
                label: strings.activities,
                selected: section == AppSection.activities,
                onTap: () => _go(context, ref, AppSection.activities),
              ),
            ],
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: Text(
                strings.signOut,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                ref.read(authUserProvider.notifier).state = null;
                ref.read(appSectionProvider.notifier).state = AppSection.home;
                ref.read(landingCompleteProvider.notifier).state = false;
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                AppConstants.versionLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, WidgetRef ref, AppSection section) {
    // Replaying splash only when explicitly choosing Home before complete.
    if (section == AppSection.home &&
        ref.read(landingCompleteProvider)) {
      ref.read(appSectionProvider.notifier).state = AppSection.memberInfo;
    } else {
      ref.read(appSectionProvider.notifier).state = section;
    }
    Navigator.of(context).pop();
  }

  Widget _item(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppTheme.gold : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.gold : Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: Colors.white12,
      onTap: onTap,
    );
  }
}
