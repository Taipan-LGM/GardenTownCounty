import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../models/user_role.dart';
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
    final countyAddress = profile?.countyAddress.trim() ?? '';
    final countyRegNo = profile?.countyRegNo.trim() ?? '';

    bool can(AppPermission p) =>
        user?.hasPermission(p) ?? false;

    final showSearch = isAdmin || can(AppPermission.search);
    final showMemberInfo = isAdmin || can(AppPermission.memberInfo);
    final show528 = isAdmin || can(AppPermission.global528);
    final show928 = isAdmin || can(AppPermission.global928);
    final showLro = isAdmin || can(AppPermission.lro);
    final showSos = isAdmin || can(AppPermission.sos);
    final showReminders = isAdmin || can(AppPermission.reminders);
    final showActivities = isAdmin || can(AppPermission.activities);
    final showOnboarding = isAdmin || can(AppPermission.onboarding);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              decoration: const BoxDecoration(color: AppTheme.forestGreen),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: strings.settings,
                      icon: Icon(
                        Icons.settings,
                        color: section == AppSection.settings
                            ? AppTheme.gold
                            : Colors.white,
                      ),
                      onPressed: () =>
                          _go(context, ref, AppSection.settings),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
                            user.userRole.label,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(
                    context,
                    ref,
                    icon: Icons.home,
                    label: strings.home,
                    selected: section == AppSection.home,
                    onTap: () => _go(context, ref, AppSection.home),
                  ),
                  if (showSearch)
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
                  if (showMemberInfo)
                    _item(
                      context,
                      ref,
                      icon: Icons.badge_outlined,
                      label: strings.memberInfo,
                      selected: section == AppSection.memberInfo,
                      onTap: () => _go(context, ref, AppSection.memberInfo),
                    ),
                  if (show528)
                    _item(
                      context,
                      ref,
                      icon: Icons.public,
                      label: strings.global528,
                      selected: section == AppSection.global528,
                      onTap: () => _go(context, ref, AppSection.global528),
                    ),
                  if (show928)
                    _item(
                      context,
                      ref,
                      icon: Icons.public_outlined,
                      label: strings.global928,
                      selected: section == AppSection.global928,
                      onTap: () => _go(context, ref, AppSection.global928),
                    ),
                  if (showLro)
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
                      onTap: () =>
                          _go(context, ref, AppSection.backupRestore),
                    ),
                  if (isAdmin)
                    _item(
                      context,
                      ref,
                      icon: Icons.manage_accounts_outlined,
                      label: strings.userManagement,
                      selected: section == AppSection.addUser,
                      onTap: () => _go(context, ref, AppSection.addUser),
                    ),
                  if (isAdmin)
                    _item(
                      context,
                      ref,
                      icon: Icons.lock_outline,
                      label: 'Locked Members',
                      selected: section == AppSection.lockedMembers,
                      onTap: () =>
                          _go(context, ref, AppSection.lockedMembers),
                    ),
                  if (showOnboarding)
                    _item(
                      context,
                      ref,
                      icon: Icons.how_to_reg_outlined,
                      label: 'Onboarding',
                      selected: section == AppSection.onboarding,
                      onTap: () =>
                          _go(context, ref, AppSection.onboarding),
                    ),
                  if (showSos)
                    _item(
                      context,
                      ref,
                      icon: Icons.sos_outlined,
                      label: strings.sos,
                      selected: section == AppSection.sos,
                      onTap: () => _go(context, ref, AppSection.sos),
                    ),
                  if (showReminders)
                    _item(
                      context,
                      ref,
                      icon: Icons.notifications_outlined,
                      label: strings.reminders,
                      selected: section == AppSection.reminders,
                      onTap: () => _go(context, ref, AppSection.reminders),
                    ),
                  if (showActivities)
                    _item(
                      context,
                      ref,
                      icon: Icons.timeline,
                      label: strings.activities,
                      selected: section == AppSection.activities,
                      onTap: () =>
                          _go(context, ref, AppSection.activities),
                    ),
                  ListTile(
                    leading:
                        const Icon(Icons.logout, color: Colors.white70),
                    title: Text(
                      strings.signOut,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      await ref.read(authServiceProvider).signOut();
                      ref.read(authUserProvider.notifier).state = null;
                      ref.read(verifiedTempAccessIdsProvider.notifier).state =
                          <String>{};
                      ref.read(appSectionProvider.notifier).state =
                          AppSection.home;
                      ref.read(landingCompleteProvider.notifier).state =
                          false;
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      strings.countyInfo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _countyField(
                      label: strings.countyName,
                      value: countyName,
                    ),
                    const SizedBox(height: 6),
                    _countyField(
                      label: strings.countyAddress,
                      value: countyAddress.isEmpty ? '—' : countyAddress,
                    ),
                    const SizedBox(height: 6),
                    _countyField(
                      label: strings.countyRegNo,
                      value: countyRegNo.isEmpty ? '—' : countyRegNo,
                    ),
                  ],
                ),
              ),
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

  Widget _countyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
