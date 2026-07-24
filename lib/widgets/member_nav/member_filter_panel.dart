import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member_navigation_state.dart';
import '../../providers/member_navigation_provider.dart';

class MemberFilterPanel extends ConsumerWidget {
  const MemberFilterPanel({
    super.key,
    required this.counts,
    this.compact = false,
  });

  final Map<MemberQuickFilter, int> counts;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(memberNavigationProvider).selectedFilter;
    final nav = ref.read(memberNavigationProvider.notifier);

    final children = MemberQuickFilter.values.map((f) {
      final count = counts[f] ?? 0;
      final isSelected = selected == f;
      return ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: AppTheme.forestGreen,
        selectedColor: Colors.white,
        iconColor: isSelected ? Colors.white : null,
        textColor: isSelected ? Colors.white : null,
        leading: Text(
          f.iconLabel,
          style: TextStyle(
            fontSize: 16,
            color: isSelected ? Colors.white : null,
          ),
        ),
        title: Text(
          '${f.label} ($count)',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            // MODIFIED - selected filter labels (incl. All) white on green
            color: isSelected ? Colors.white : null,
          ),
        ),
        onTap: () => nav.setFilter(f),
      );
    }).toList();

    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: MemberQuickFilter.values.map((f) {
          final count = counts[f] ?? 0;
          final isSelected = selected == f;
          return FilterChip(
            selected: isSelected,
            label: Text(
              '${f.iconLabel} ${f.label} ($count)',
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selectedColor: AppTheme.forestGreen,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
            ),
            onSelected: (_) => nav.setFilter(f),
          );
        }).toList(),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Material(
              color: AppTheme.forestGreen,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'FILTERS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
