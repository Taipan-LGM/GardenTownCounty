import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'county_logo.dart';

/// Fixed top chrome: Logo 1 + county name | Videos · Info · Menu.
///
/// // NEW ADDITION - Delete this file to revert top bar layout.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({
    super.key,
    required this.onOpenMenu,
    this.height = 72,
  });

  final VoidCallback onOpenMenu;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);
    final profile = ref.watch(countyProfileProvider).valueOrNull;
    final countyName = profile?.countyName.trim().isNotEmpty == true
        ? profile!.countyName
        : 'Garden Town County';

    return Material(
      color: Colors.grey.shade900,
      elevation: 4,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade700),
          ),
        ),
        child: Row(
          children: [
            const RoundCountyLogo(size: 48),
            const SizedBox(width: 12),
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
            ),
            // Order L→R: Videos, Info, Menu (Menu farthest right)
            _TabChip(
              icon: Icons.video_library,
              label: 'Videos',
              selected: section == AppSection.countyVideos,
              onTap: () => ref.read(appSectionProvider.notifier).state =
                  AppSection.countyVideos,
            ),
            _TabChip(
              icon: Icons.info_outline,
              label: 'Info',
              selected: section == AppSection.countyInfo,
              onTap: () => ref.read(appSectionProvider.notifier).state =
                  AppSection.countyInfo,
            ),
            _TabChip(
              icon: Icons.menu,
              label: 'Menu',
              selected: false,
              onTap: onOpenMenu,
            ),
          ],
        ),
      ),
    );
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
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
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
