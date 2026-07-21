import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_log.dart';
import '../../providers/providers.dart';
import 'activity_map_dialog.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  ActivityLog? _bestGpsActivity(List<ActivityLog> activities) {
    final withGps = activities
        .where((a) => a.latitude != null && a.longitude != null)
        .toList();
    if (withGps.isEmpty) return null;
    final login = withGps.where(
      (a) => a.action.toLowerCase().contains('login'),
    );
    if (login.isNotEmpty) return login.first;
    return withGps.first;
  }

  Future<void> _openGps(
    BuildContext context,
    List<ActivityLog> activities, {
    ActivityLog? specific,
  }) async {
    final target = specific ?? _bestGpsActivity(activities);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GPS location recorded yet.')),
      );
      return;
    }
    await showActivityMapDialog(context, target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Activities',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bodyText,
                ),
              ),
              const Spacer(),
              activitiesAsync.maybeWhen(
                data: (activities) => FilledButton.icon(
                  onPressed: () => _openGps(context, activities),
                  icon: const Icon(Icons.gps_fixed, size: 18),
                  label: const Text('GPS'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.bodyText,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(activitiesProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Login and member actions with GPS, date, time, and user name. '
            'Tap GPS to view map — print, save, or share via WhatsApp.',
          ),
          const Divider(),
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (activities) {
                if (activities.isEmpty) {
                  return const Center(
                    child: Text('No activities recorded yet.'),
                  );
                }
                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date / Time')),
                      DataColumn(label: Text('User')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('GPS Location')),
                      DataColumn(label: Text('Map')),
                    ],
                    rows: activities.map((a) {
                      final hasGps =
                          a.latitude != null && a.longitude != null;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(dateFormat.format(a.occurredAt.toLocal())),
                          ),
                          DataCell(Text(a.userName)),
                          DataCell(Text(a.action)),
                          DataCell(Text(a.locationLabel ?? '—')),
                          DataCell(
                            hasGps
                                ? IconButton(
                                    tooltip: 'Open GPS map',
                                    icon: const Icon(
                                      Icons.map_outlined,
                                      color: AppTheme.forestGreen,
                                    ),
                                    onPressed: () => _openGps(
                                      context,
                                      activities,
                                      specific: a,
                                    ),
                                  )
                                : const Text('—'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
