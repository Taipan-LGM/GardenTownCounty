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
        selectedTileColor: AppTheme.forestGreen.withValues(alpha: 0.12),
        leading: Text(f.iconLabel, style: const TextStyle(fontSize: 16)),
        title: Text(
          '${f.label} ($count)',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.forestGreen : null,
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
            label: Text('${f.iconLabel} ${f.label} ($count)'),
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
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'FILTERS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.forestGreen,
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
