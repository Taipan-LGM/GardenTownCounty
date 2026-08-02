import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_log.dart';
import '../../models/remuneration_settings.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';
import 'activity_map_dialog.dart';

enum _ActivityViewMode { all, audit }

enum _AuditCategory { payment, pdfRelease, aiId, cardIssuance }

enum _AuditDateRangeFilter {
  today,
  sevenDays,
  thirtyDays,
  currentMonth,
  custom,
}

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  _ActivityViewMode _mode = _ActivityViewMode.all;
  _AuditDateRangeFilter _dateFilter = _AuditDateRangeFilter.sevenDays;
  DateTimeRange? _customRange;
  final Set<_AuditCategory> _selectedAuditCategories = {
    _AuditCategory.payment,
    _AuditCategory.pdfRelease,
    _AuditCategory.aiId,
    _AuditCategory.cardIssuance,
  };

  String _categoryLabel(_AuditCategory category) {
    switch (category) {
      case _AuditCategory.payment:
        return 'Payments';
      case _AuditCategory.pdfRelease:
        return 'PDF Releases';
      case _AuditCategory.aiId:
        return 'AI ID';
      case _AuditCategory.cardIssuance:
        return 'Card Issuance';
    }
  }

  String _dateFilterLabel(_AuditDateRangeFilter filter) {
    switch (filter) {
      case _AuditDateRangeFilter.today:
        return 'Today';
      case _AuditDateRangeFilter.sevenDays:
        return '7 Days';
      case _AuditDateRangeFilter.thirtyDays:
        return '30 Days';
      case _AuditDateRangeFilter.currentMonth:
        return 'This Month';
      case _AuditDateRangeFilter.custom:
        return 'Custom';
    }
  }

  String? _extractActionId(String action) {
    final match = RegExp(r'\[([A-Z0-9-]+)\]').firstMatch(action);
    return match?.group(1);
  }

  String _displayAction(String action, RemunerationSettings settings) {
    final match = RegExp(
      r'step[_ ](\d+)',
      caseSensitive: false,
    ).firstMatch(action);
    final step = int.tryParse(match?.group(1) ?? '');
    if (step == null) return action;

    final stepName = settings.stepName(step);
    if (action.contains(stepName)) return action;

    final labeledStep = RegExp('step_$step \\([^)]+\\)', caseSensitive: false);
    if (labeledStep.hasMatch(action)) {
      return action.replaceFirst(labeledStep, 'step_$step ($stepName)');
    }
    return '$action ($stepName)';
  }

  bool _withinAuditDateRange(ActivityLog activity) {
    final local = activity.occurredAt.toLocal();
    switch (_dateFilter) {
      case _AuditDateRangeFilter.today:
        final now = DateTime.now();
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      case _AuditDateRangeFilter.sevenDays:
        final from = DateTime.now().subtract(const Duration(days: 7));
        return !local.isBefore(from);
      case _AuditDateRangeFilter.thirtyDays:
        final from = DateTime.now().subtract(const Duration(days: 30));
        return !local.isBefore(from);
      case _AuditDateRangeFilter.currentMonth:
        final now = DateTime.now();
        return local.year == now.year && local.month == now.month;
      case _AuditDateRangeFilter.custom:
        final range = _customRange;
        if (range == null) return true;
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        );
        return !local.isBefore(start) && !local.isAfter(end);
    }
  }

  bool _isAuditMatch(ActivityLog activity, _AuditCategory category) {
    final action = activity.action.toLowerCase();
    switch (category) {
      case _AuditCategory.payment:
        return action.contains('manual_payment') ||
            action.contains('remuneration_paid') ||
            action.contains('in_app_step_') ||
            action.contains('remuneration_approved') ||
            action.contains('recorded_manual_payment') ||
            action.contains('payment');
      case _AuditCategory.pdfRelease:
        return action.contains('pdf_released');
      case _AuditCategory.aiId:
        return action.contains('ai_id_generated');
      case _AuditCategory.cardIssuance:
        return action.contains('credential_card_issued') ||
            action.contains('card issued');
    }
  }

  String _auditTypeFor(ActivityLog activity) {
    final action = activity.action.toLowerCase();
    if (_isAuditMatch(activity, _AuditCategory.payment)) return 'Payment';
    if (_isAuditMatch(activity, _AuditCategory.pdfRelease))
      return 'PDF Release';
    if (_isAuditMatch(activity, _AuditCategory.aiId)) return 'AI ID';
    if (_isAuditMatch(activity, _AuditCategory.cardIssuance)) {
      return 'Card Issuance';
    }
    if (action.contains('step_')) return 'Step Event';
    return 'Other';
  }

  List<ActivityLog> _filteredAuditLogs(List<ActivityLog> activities) {
    return activities.where((activity) {
      if (!_withinAuditDateRange(activity)) return false;
      for (final category in _selectedAuditCategories) {
        if (_isAuditMatch(activity, category)) return true;
      }
      return false;
    }).toList();
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildAuditCsv(List<ActivityLog> rows) {
    final buffer = StringBuffer()
      ..writeln(
        [
          'ActionID',
          'Type',
          'DateTime',
          'User',
          'Action',
          'Location',
        ].join(','),
      );

    for (final row in rows) {
      final localTime = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(row.occurredAt.toLocal());
      buffer.writeln(
        [
          _csvEscape(_extractActionId(row.action) ?? ''),
          _csvEscape(_auditTypeFor(row)),
          _csvEscape(localTime),
          _csvEscape(row.userName),
          _csvEscape(row.action),
          _csvEscape(row.locationLabel ?? ''),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  String _actionIdCategory(String? actionId) {
    if (actionId == null || actionId.isEmpty) return 'Uncoded';
    final parts = actionId.split('-');
    if (parts.length < 3) return actionId;
    return '${parts[0]}-${parts[1]}-${parts[2]}';
  }

  Map<String, int> _summaryByActionIdCategory(List<ActivityLog> rows) {
    final summary = <String, int>{};
    for (final row in rows) {
      final category = _actionIdCategory(_extractActionId(row.action));
      summary[category] = (summary[category] ?? 0) + 1;
    }
    final entries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  Future<void> _exportAuditCsv(List<ActivityLog> rows) async {
    final now = DateTime.now();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'admin_audit_$ts.csv';
    final csv = _buildAuditCsv(rows);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv)),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'Admin Audit Export',
        text: 'Garden Town County admin audit export',
      ),
    );
  }

  Future<void> _copyAuditCsv(
    BuildContext context,
    List<ActivityLog> rows,
  ) async {
    final csv = _buildAuditCsv(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit CSV copied to clipboard.'),
        backgroundColor: Colors.green,
      ),
    );
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.noGpsYet)));
      return;
    }
    await showActivityMapDialog(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final strings = ref.watch(appStringsProvider);
    final remunerationSettings =
        ref.watch(remunerationSettingsProvider).valueOrNull ??
        RemunerationSettings.defaults();
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
              if (ref.watch(isAdminProvider))
                SegmentedButton<_ActivityViewMode>(
                  segments: const [
                    ButtonSegment<_ActivityViewMode>(
                      value: _ActivityViewMode.all,
                      label: Text('All'),
                      icon: Icon(Icons.list_alt),
                    ),
                    ButtonSegment<_ActivityViewMode>(
                      value: _ActivityViewMode.audit,
                      label: Text('Admin Audit'),
                      icon: Icon(Icons.rule_folder_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              if (ref.watch(isAdminProvider)) const SizedBox(width: 8),
              activitiesAsync.maybeWhen(
                data: (activities) {
                  final isAudit =
                      _mode == _ActivityViewMode.audit &&
                      ref.watch(isAdminProvider);
                  if (!isAudit) return const SizedBox.shrink();
                  final rows = _filteredAuditLogs(activities);
                  return ActionButton(
                    onPressed: rows.isEmpty
                        ? null
                        : () => _exportAuditCsv(rows),
                    text: 'Export CSV',
                    icon: Icons.download_outlined,
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              if (ref.watch(isAdminProvider)) const SizedBox(width: 8),
              activitiesAsync.maybeWhen(
                data: (activities) {
                  final isAudit =
                      _mode == _ActivityViewMode.audit &&
                      ref.watch(isAdminProvider);
                  if (!isAudit) return const SizedBox.shrink();
                  final rows = _filteredAuditLogs(activities);
                  return ActionButton(
                    onPressed: rows.isEmpty
                        ? null
                        : () => _copyAuditCsv(context, rows),
                    text: 'Copy CSV',
                    icon: Icons.copy_all_outlined,
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              if (ref.watch(isAdminProvider)) const SizedBox(width: 8),
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
          Text(
            _mode == _ActivityViewMode.audit
                ? 'Audit focus: payment, PDF release, AI ID generation, and card issuance events.'
                : strings.activitiesSubtitle,
          ),
          if (_mode == _ActivityViewMode.audit && ref.watch(isAdminProvider))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._AuditCategory.values.map((category) {
                    final selected = _selectedAuditCategories.contains(
                      category,
                    );
                    return FilterChip(
                      selected: selected,
                      label: Text(_categoryLabel(category)),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedAuditCategories.add(category);
                          } else {
                            _selectedAuditCategories.remove(category);
                          }
                          if (_selectedAuditCategories.isEmpty) {
                            _selectedAuditCategories.add(category);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(width: 8),
                  ..._AuditDateRangeFilter.values.map((filter) {
                    final selected = _dateFilter == filter;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(_dateFilterLabel(filter)),
                      onSelected: (_) async {
                        if (filter == _AuditDateRangeFilter.custom) {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            initialDateRange: _customRange,
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked == null) return;
                          setState(() {
                            _customRange = picked;
                            _dateFilter = _AuditDateRangeFilter.custom;
                          });
                          return;
                        }
                        setState(() => _dateFilter = filter);
                      },
                    );
                  }),
                  if (_dateFilter == _AuditDateRangeFilter.custom &&
                      _customRange != null)
                    ActionChip(
                      label: Text(
                        '${DateFormat('yyyy-MM-dd').format(_customRange!.start)} to ${DateFormat('yyyy-MM-dd').format(_customRange!.end)}',
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _customRange,
                          firstDate: DateTime(DateTime.now().year - 5),
                          lastDate: DateTime(DateTime.now().year + 1),
                        );
                        if (picked == null) return;
                        setState(() => _customRange = picked);
                      },
                    ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('${strings.errorLabel}: $e')),
              data: (activities) {
                if (activities.isEmpty) {
                  return Center(child: Text(strings.noActivitiesYet));
                }

                final isAudit =
                    _mode == _ActivityViewMode.audit &&
                    ref.watch(isAdminProvider);
                final rows = isAudit
                    ? _filteredAuditLogs(activities)
                    : activities;

                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching audit events for selected filters.',
                    ),
                  );
                }

                final summary = isAudit
                    ? _summaryByActionIdCategory(rows)
                    : const <String, int>{};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAudit)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin Audit Summary (Action ID Categories)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: summary.entries
                                    .map(
                                      (entry) => Chip(
                                        label: Text(
                                          '${entry.key}: ${entry.value}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            if (isAudit)
                              const DataColumn(label: Text('Action ID')),
                            if (isAudit) const DataColumn(label: Text('Type')),
                            DataColumn(label: Text(strings.dateTime)),
                            DataColumn(label: Text(strings.user)),
                            DataColumn(label: Text(strings.action)),
                            DataColumn(label: Text(strings.gpsLocation)),
                            DataColumn(label: Text(strings.map)),
                          ],
                          rows: rows.map((a) {
                            final hasGps =
                                a.latitude != null && a.longitude != null;
                            return DataRow(
                              cells: [
                                if (isAudit)
                                  DataCell(
                                    Text(_extractActionId(a.action) ?? '—'),
                                  ),
                                if (isAudit)
                                  DataCell(
                                    Text(
                                      _auditTypeFor(a),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                DataCell(
                                  Text(
                                    dateFormat.format(a.occurredAt.toLocal()),
                                  ),
                                ),
                                DataCell(Text(a.userName)),
                                DataCell(
                                  Text(
                                    _displayAction(
                                      a.action,
                                      remunerationSettings,
                                    ),
                                  ),
                                ),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
