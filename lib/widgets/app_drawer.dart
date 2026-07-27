import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../models/user_role.dart';
import '../providers/providers.dart';
import '../screens/search/global_search_dialog.dart';
import 'cancel_button.dart';
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
    final countyContactNo = profile?.countyContactNo.trim() ?? '';
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
                  // 1. Home
                  _item(
                    context,
                    ref,
                    icon: Icons.home,
                    label: strings.home,
                    selected: section == AppSection.home,
                    onTap: () => _go(context, ref, AppSection.home),
                  ),
                  // 2. Search
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
                  // 3. Member Management
                  if (showMemberInfo)
                    _item(
                      context,
                      ref,
                      icon: Icons.assignment,
                      label: strings.memberInfo,
                      selected: section == AppSection.memberInfo,
                      onTap: () => _go(context, ref, AppSection.memberInfo),
                    ),
                  // 4. Step 1_Global 528
                  if (show528)
                    _item(
                      context,
                      ref,
                      icon: Icons.numbers,
                      label: strings.global528,
                      selected: section == AppSection.global528,
                      onTap: () => _go(context, ref, AppSection.global528),
                    ),
                  // 5. Step 2_Global 528 (NEW)
                  if (show528)
                    _item(
                      context,
                      ref,
                      icon: Icons.numbers,
                      label: strings.global528Step2,
                      selected: section == AppSection.global528Step2,
                      onTap: () =>
                          _go(context, ref, AppSection.global528Step2),
                    ),
                  // 6. Step 3_Global 928
                  if (show928)
                    _item(
                      context,
                      ref,
                      icon: Icons.numbers,
                      label: strings.global928,
                      selected: section == AppSection.global928,
                      onTap: () => _go(context, ref, AppSection.global928),
                    ),
                  // 7. Step 4_LRO
                  if (showLro)
                    _item(
                      context,
                      ref,
                      icon: Icons.gavel,
                      label: strings.lro,
                      selected: section == AppSection.lro,
                      onTap: () => _go(context, ref, AppSection.lro),
                    ),
                  // 8. Step 5_Credential Card (NEW)
                  if (showLro)
                    _item(
                      context,
                      ref,
                      icon: Icons.credit_card,
                      label: strings.credentialCard,
                      selected: section == AppSection.credentialCard,
                      onTap: () =>
                          _go(context, ref, AppSection.credentialCard),
                    ),
                  const Divider(color: Colors.white24),
                  // 9. Backup & Restore
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
                  // 10. RS Rights
                  if (isAdmin)
                    _item(
                      context,
                      ref,
                      icon: Icons.admin_panel_settings,
                      label: strings.userManagement,
                      selected: section == AppSection.addUser,
                      onTap: () => _go(context, ref, AppSection.addUser),
                    ),
                  // 11. Cancellations
                  if (isAdmin)
                    _item(
                      context,
                      ref,
                      icon: Icons.cancel_outlined,
                      label: strings.cancellations,
                      selected: section == AppSection.lockedMembers,
                      onTap: () =>
                          _go(context, ref, AppSection.lockedMembers),
                      iconColor: Colors.redAccent,
                    ),
                  // 12. Duplicate Manager
                  if (isAdmin)
                    _item(
                      context,
                      ref,
                      icon: Icons.warning_amber,
                      label: strings.duplicateManagement,
                      selected: section == AppSection.duplicateReport,
                      onTap: () =>
                          _go(context, ref, AppSection.duplicateReport),
                      iconColor: Colors.orangeAccent,
                    ),
                  // 13. SOS
                  if (showSos)
                    _item(
                      context,
                      ref,
                      icon: Icons.sos,
                      label: strings.sos,
                      selected: section == AppSection.sos,
                      onTap: () => _go(context, ref, AppSection.sos),
                    ),
                  // 14. Reminders
                  if (showReminders)
                    _item(
                      context,
                      ref,
                      icon: Icons.alarm,
                      label: strings.reminders,
                      selected: section == AppSection.reminders,
                      onTap: () => _go(context, ref, AppSection.reminders),
                      badgeCount: ref
                              .watch(activeReminderCountProvider)
                              .valueOrNull ??
                          0,
                    ),
                  // 15. Activities
                  if (showActivities)
                    _item(
                      context,
                      ref,
                      icon: Icons.list_alt,
                      label: strings.activities,
                      selected: section == AppSection.activities,
                      onTap: () =>
                          _go(context, ref, AppSection.activities),
                    ),
                  const Divider(color: Colors.white24),
                  // 16. Demo Data
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(
                        Icons.science,
                        color: Colors.purpleAccent,
                      ),
                      title: Text(
                        strings.demoData,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Generate 10 demo members',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _generateDemoData(context, ref),
                    ),
                  // 17. Sign Out
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      strings.signOut,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () => _confirmSignOut(context, ref, strings),
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
                      label: strings.countyContactNo,
                      value: countyContactNo.isEmpty ? 'Not set' : countyContactNo,
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

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          '${strings.signOut}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(ctx, false),
            text: 'Cancel',
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(strings.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _performSignOut(context, ref);
  }

  Future<void> _performSignOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    ref.read(authUserProvider.notifier).state = null;
    ref.read(verifiedTempAccessIdsProvider.notifier).state = <String>{};
    ref.read(appSectionProvider.notifier).state = AppSection.home;
    ref.read(landingCompleteProvider.notifier).state = false;
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _generateDemoData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Demo Data?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create 10 demo members with:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• South African ID numbers'),
            Text('• Realistic names (South African leaders)'),
            Text('• Various step completions (1–3)'),
            Text('• Some expired reminders'),
            Text('• Mix of assigned / unassigned RS'),
            SizedBox(height: 12),
            Text(
              'Adds to existing data (skips IDs that already exist).',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(ctx, false),
            text: 'Cancel',
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate Demo Data'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final result =
          await ref.read(demoDataServiceProvider).generateDemoData();
      ref.invalidate(membersProvider);
      ref.invalidate(appUsersProvider);
      ref.invalidate(activeOnboardingRemindersProvider);
      ref.invalidate(reminderStatsProvider);
      ref.invalidate(activeReminderCountProvider);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demo data ready: ${result.membersCreated} members, '
            '${result.remindersCreated} reminders created '
            '(existing IDs skipped).',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating demo data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _item(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int badgeCount = 0,
    Color? iconColor,
  }) {
    final leadingColor = selected
        ? AppTheme.gold
        : (iconColor ?? Colors.white70);
    return ListTile(
      leading: Icon(icon, color: leadingColor),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.gold : Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          : null,
      selected: selected,
      selectedTileColor: Colors.white12,
      onTap: onTap,
    );
  }
}
