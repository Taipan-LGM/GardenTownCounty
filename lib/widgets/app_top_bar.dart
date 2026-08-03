import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/providers.dart';
import 'county_logo.dart';
import 'standard_buttons.dart';

/// Fixed top chrome: Logo 1 + county name | Settings · Live View · Videos · Info · Menu.
///
/// // NEW ADDITION - Delete this file to revert top bar layout.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key, required this.onOpenMenu, this.height = 72});

  final VoidCallback onOpenMenu;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final profile = ref.watch(countyProfileProvider).valueOrNull;
    final countyName = profile?.countyName.trim().isNotEmpty == true
        ? profile!.countyName
        : 'Garden Town County';
    final tabs = <Widget>[
      if (isAdmin)
        _TabChip(
          icon: Icons.science,
          label: strings.demoData,
          selected: false,
          onTap: () => _generateDemoData(context, ref),
        ),
      _TabChip(
        icon: Icons.settings,
        label: strings.settings,
        selected: section == AppSection.settings,
        onTap: () =>
            ref.read(appSectionProvider.notifier).state = AppSection.settings,
      ),
      if (isAdmin)
        _TabChip(
          icon: Icons.monitor_heart_outlined,
          label: strings.liveView,
          selected: section == AppSection.liveView,
          onTap: () =>
              ref.read(appSectionProvider.notifier).state = AppSection.liveView,
        ),
      _TabChip(
        icon: Icons.video_library,
        label: strings.videos,
        selected: section == AppSection.countyVideos,
        onTap: () => ref.read(appSectionProvider.notifier).state =
            AppSection.countyVideos,
      ),
      _TabChip(
        icon: Icons.info_outline,
        label: strings.info,
        selected: section == AppSection.countyInfo,
        onTap: () =>
            ref.read(appSectionProvider.notifier).state = AppSection.countyInfo,
      ),
      _TabChip(
        icon: Icons.menu,
        label: strings.menu,
        selected: false,
        onTap: onOpenMenu,
      ),
    ];

    return Material(
      color: Colors.grey.shade900,
      elevation: 4,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showCountyName = constraints.maxWidth >= 760;
            return Row(
              children: [
                const RoundCountyLogo(size: 48),
                const SizedBox(width: 8),
                if (showCountyName)
                  Expanded(
                    child: Text(
                      countyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: tabs),
                    ),
                  ),
                if (showCountyName) ...tabs,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _generateDemoData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generate Demo Data?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create demo data for:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 10 members + onboarding reminders'),
            Text('• Payments summary (35 completed members)'),
            Text('• Paid + PDF completed total R 6,900.00'),
            Text('• Duplicate Manager (3 pairs)'),
            Text('• Cancellations (5 cancelled members)'),
            Text('• Info (8 Garden Town articles)'),
            Text('• Videos (6 member videos)'),
            SizedBox(height: 12),
            Text(
              'Adds to existing data (skips IDs that already exist).',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            text: 'Cancel',
          ),
          ActionButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            text: 'Generate Demo Data',
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final result = await ref.read(demoDataServiceProvider).generateDemoData();
      ref.invalidate(membersProvider);
      ref.invalidate(appUsersProvider);
      ref.invalidate(cancelledMembersProvider);
      ref.invalidate(activeOnboardingRemindersProvider);
      ref.invalidate(reminderStatsProvider);
      ref.invalidate(activeReminderCountProvider);
      ref.invalidate(remunerationSettingsProvider);
      ref.invalidate(publishedArticlesProvider);
      ref.invalidate(activeVideosProvider);
      ref.invalidate(liveViewDataProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demo data ready: ${result.membersCreated} members, '
            '${result.remindersCreated} reminders, '
            '${result.duplicateMembersCreated} duplicates, '
            '${result.cancelledMembersCreated} cancelled, '
            '${result.articlesCreated} articles, '
            '${result.videosCreated} videos, '
            'Payments summary R 6,900.00 / 35 completed members '
            '(existing IDs skipped).',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating demo data: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: selected ? Colors.blue.shade900 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: Colors.blue.shade300, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
