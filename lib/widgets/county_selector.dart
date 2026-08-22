import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/county.dart';
import '../providers/providers.dart';

/// County switcher shown in the header for Super Admins. Selecting a county
/// updates [currentCountyIdProvider] and invalidates all county-scoped lists.
class CountySelector extends ConsumerWidget {
  const CountySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final countiesAsync = ref.watch(countiesProvider);
    final currentId = ref.watch(currentCountyIdProvider);

    return countiesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (counties) {
        if (counties.isEmpty) return const SizedBox.shrink();
        final activeId = currentId.isNotEmpty
            ? currentId
            : counties.first.id;
        final active = counties.firstWhere(
          (c) => c.id == activeId,
          orElse: () => counties.first,
        );

        // Keep DB scoping in sync with the selected (or default) county.
        ref.read(databaseServiceProvider).setActiveCounty(active.id);

        return Container(
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white38),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: active.id,
                    dropdownColor: Colors.grey.shade900,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white70,
                    ),
                    isExpanded: true,
                    items: [
                      for (final c in counties)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.countyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      ref.read(databaseServiceProvider).setActiveCounty(id);
                      ref.read(currentCountyIdProvider.notifier).state = id;
                      _invalidateScopedLists(ref);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${strings.currentCounty}: ${counties.firstWhere((c) => c.id == id).countyName}',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _invalidateScopedLists(WidgetRef ref) {
    ref.invalidate(membersProvider);
    ref.invalidate(appUsersProvider);
    ref.invalidate(activeOnboardingRemindersProvider);
    ref.invalidate(reminderStatsProvider);
    ref.invalidate(activeReminderCountProvider);
    ref.invalidate(publishedArticlesProvider);
    ref.invalidate(activeVideosProvider);
    ref.invalidate(countyProfileProvider);
    ref.invalidate(countyInfoProvider);
    ref.invalidate(liveViewDataProvider);
  }
}
