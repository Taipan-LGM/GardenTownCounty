import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_log.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';
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
    WidgetRef ref,
    List<ActivityLog> activities, {
    ActivityLog? specific,
  }) async {
    final strings = ref.read(appStringsProvider);
    final target = specific ?? _bestGpsActivity(activities);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noGpsYet)),
      );
      return;
    }
    await showActivityMapDialog(context, target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final strings = ref.watch(appStringsProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                strings.activitiesTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bodyText,
                ),
              ),
              const Spacer(),
              activitiesAsync.maybeWhen(
                data: (activities) => ActionButton(
                  onPressed: () => _openGps(context, ref, activities),
                  text: 'GPS',
                  icon: Icons.gps_fixed,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: strings.refresh,
                onPressed: () => ref.invalidate(activitiesProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(strings.activitiesSubtitle),
          const Divider(),
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${strings.errorLabel}: $e')),
              data: (activities) {
                if (activities.isEmpty) {
                  return Center(child: Text(strings.noActivitiesYet));
                }
                return SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text(strings.dateTime)),
                      DataColumn(label: Text(strings.user)),
                      DataColumn(label: Text(strings.action)),
                      DataColumn(label: Text(strings.gpsLocation)),
                      DataColumn(label: Text(strings.map)),
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
                                    tooltip: strings.openGpsMap,
                                    icon: const Icon(
                                      Icons.map_outlined,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _openGps(
                                      context,
                                      ref,
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
