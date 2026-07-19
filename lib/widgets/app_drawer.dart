import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/providers.dart';
import '../screens/search/global_search_dialog.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);
    final user = ref.watch(authUserProvider);

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
                  const Text(
                    'Garden Town County',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.displayName ?? 'Guest',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _item(
              context,
              ref,
              icon: Icons.home,
              label: 'Home',
              selected: section == AppSection.home,
              onTap: () => _go(context, ref, AppSection.home),
            ),
            _item(
              context,
              ref,
              icon: Icons.search,
              label: 'Search',
              selected: false,
              onTap: () async {
                Navigator.of(context).pop();
                await showGlobalSearchDialog(context, ref);
              },
            ),
            _item(
              context,
              ref,
              icon: Icons.badge_outlined,
              label: 'Member Info',
              selected: section == AppSection.memberInfo,
              onTap: () => _go(context, ref, AppSection.memberInfo),
            ),
            _item(
              context,
              ref,
              icon: Icons.sos_outlined,
              label: 'SOS',
              selected: section == AppSection.sos,
              onTap: () => _go(context, ref, AppSection.sos),
            ),
            _item(
              context,
              ref,
              icon: Icons.public,
              label: 'Global 528',
              selected: section == AppSection.global528,
              onTap: () => _go(context, ref, AppSection.global528),
            ),
            _item(
              context,
              ref,
              icon: Icons.public_outlined,
              label: 'Global 928',
              selected: section == AppSection.global928,
              onTap: () => _go(context, ref, AppSection.global928),
            ),
            _item(
              context,
              ref,
              icon: Icons.account_balance,
              label: 'LRO',
              selected: section == AppSection.lro,
              onTap: () => _go(context, ref, AppSection.lro),
            ),
            _item(
              context,
              ref,
              icon: Icons.timeline,
              label: 'Activities',
              selected: section == AppSection.activities,
              onTap: () => _go(context, ref, AppSection.activities),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text('Sign out', style: TextStyle(color: Colors.white)),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                ref.read(authUserProvider.notifier).state = null;
                ref.read(appSectionProvider.notifier).state = AppSection.home;
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, WidgetRef ref, AppSection section) {
    ref.read(appSectionProvider.notifier).state = section;
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
