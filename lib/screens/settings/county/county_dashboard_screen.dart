import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/county.dart';
import '../../../providers/providers.dart';
import '../../../widgets/county_selector.dart';
import '../../../widgets/standard_buttons.dart';
import 'create_county_dialog.dart';

/// Super Admin overview of all counties: tiles with member count + revenue,
/// plus a "Create New County" tile and delete-with-confirm.
class CountyDashboardScreen extends ConsumerWidget {
  const CountyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final db = ref.watch(databaseServiceProvider);
    final countiesAsync = ref.watch(countiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('CountyConnect'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CountySelector(),
            ),
          ),
        ),
      ),
      body: countiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (counties) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.countyDashboard,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  strings.appSlogan,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: counties.length + 1,
                    itemBuilder: (context, index) {
                      if (index == counties.length) {
                        // "Create New County" tile.
                        return _CreateTile(
                          onTap: () async {
                            final created = await showDialog<bool>(
                              context: context,
                              builder: (_) => const CreateCountyDialog(),
                            );
                            if (created == true) {
                              ref.invalidate(countiesProvider);
                            }
                          },
                          label: strings.createNewCounty,
                        );
                      }
                      final county = counties[index];
                      return _CountyTile(
                        county: county,
                        strings: strings,
                        db: db,
                        onDelete: () => _confirmDelete(
                          context,
                          ref,
                          county,
                          strings,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    County county,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${strings.manageCounties}: ${county.countyName}'),
        content: Text(strings.deleteCountyConfirm),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(ctx, false),
            text: strings.cancel,
          ),
          ActionButton(
            onPressed: () => Navigator.pop(ctx, true),
            text: strings.delete,
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseServiceProvider).deleteCounty(county.id);
    ref.invalidate(countiesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${county.countyName} deleted')),
      );
    }
  }
}

class _CountyTile extends StatelessWidget {
  const _CountyTile({
    required this.county,
    required this.strings,
    required this.db,
    required this.onDelete,
  });

  final County county;
  final AppStrings strings;
  final dynamic db;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({int memberCount, double revenue})>(
      future: db.getCountyStats(county.id),
      builder: (context, snap) {
        final memberCount = snap.data?.memberCount ?? 0;
        final revenue = snap.data?.revenue ?? 0.0;
        return Card(
          color: AppTheme.forestGreen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  county.countyName,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${strings.membersCount}: $memberCount',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '${strings.revenue}: R ${revenue.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: strings.delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: Colors.white.withValues(alpha: 0.06),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, size: 40, color: Colors.white70),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
