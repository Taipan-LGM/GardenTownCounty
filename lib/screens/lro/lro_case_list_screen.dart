import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/lro_case.dart';
import '../../providers/providers.dart';
import '../../widgets/lro/lro_search_bar.dart';
import '../../widgets/lro/lro_status_badge.dart';
import 'lro_case_detail_screen.dart';
import 'lro_case_form_screen.dart';

/// Full list of 528 or 928 cases. Rendered as the body for
/// [AppSection.global528] / [AppSection.global928] inside the shell.
class LroCaseListScreen extends ConsumerStatefulWidget {
  const LroCaseListScreen({super.key, required this.caseType});

  final LroCaseType caseType;

  @override
  ConsumerState<LroCaseListScreen> createState() => _LroCaseListScreenState();
}

class _LroCaseListScreenState extends ConsumerState<LroCaseListScreen> {
  static const _pageSize = 50;

  String _query = '';
  String? _statusFilter;
  bool _sortAscending = false;
  int _visibleCount = _pageSize;

  List<LroCase> _filterAndSort(List<LroCase> cases) {
    var result = cases.where((c) => !c.deleted).toList();
    if (_statusFilter != null) {
      result = result.where((c) => c.status == _statusFilter).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((c) {
        return c.caseNumber.toLowerCase().contains(query) ||
            c.subjectName.toLowerCase().contains(query) ||
            c.propertyAddress.toLowerCase().contains(query) ||
            c.assignedOfficer.toLowerCase().contains(query) ||
            c.zoningType.toLowerCase().contains(query) ||
            c.notes.toLowerCase().contains(query) ||
            (c.recordingNumber ?? '').toLowerCase().contains(query);
      }).toList();
    }
    result.sort((a, b) {
      final dateA = a.submissionDate ?? a.createdAt;
      final dateB = b.submissionDate ?? b.createdAt;
      return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
    return result;
  }

  void _refresh() {
    if (widget.caseType == LroCaseType.status528) {
      ref.invalidate(lroCases528Provider);
    } else {
      ref.invalidate(lroCases928Provider);
    }
    ref.invalidate(lroStatsProvider);
  }

  Future<void> _openForm({LroCase? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LroCaseFormScreen(
          caseType: widget.caseType,
          existing: existing,
        ),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openDetail(LroCase lroCase) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LroCaseDetailScreen(caseId: lroCase.id),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.caseType == LroCaseType.status528
        ? lroCases528Provider
        : lroCases928Provider;
    final casesAsync = ref.watch(provider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.caseType.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.forestGreen,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Case'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: LroSearchBar(
                  hintText: 'Search cases...',
                  onChanged: (v) => setState(() {
                    _query = v;
                    _visibleCount = _pageSize;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...LroCaseStatus.values.map(
                      (s) => DropdownMenuItem(
                        value: s.code,
                        child: Text(s.label),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _statusFilter = v;
                    _visibleCount = _pageSize;
                  }),
                ),
              ),
              IconButton(
                tooltip: _sortAscending
                    ? 'Sorted oldest first'
                    : 'Sorted newest first',
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                onPressed: () => setState(() {
                  _sortAscending = !_sortAscending;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: casesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (cases) {
                final filtered = _filterAndSort(cases);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No cases found.'));
                }
                final visible = filtered.take(_visibleCount).toList();
                final remaining = filtered.length - visible.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          child: SingleChildScrollView(
                            child: DataTable(
                              showCheckboxColumn: false,
                              columns: const [
                                DataColumn(label: Text('Case #')),
                                DataColumn(label: Text('Subject')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Submitted')),
                                DataColumn(label: Text('Fee'), numeric: true),
                              ],
                              rows: visible.map((c) {
                                return DataRow(
                                  onSelectChanged: (_) => _openDetail(c),
                                  cells: [
                                    DataCell(Text(c.caseNumber)),
                                    DataCell(
                                      Text(
                                        c.subjectName.isEmpty
                                            ? '—'
                                            : c.subjectName,
                                      ),
                                    ),
                                    DataCell(
                                      LroStatusBadge(
                                        status: c.status,
                                        label: c.statusEnum.label,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        c.submissionDate != null
                                            ? dateFmt.format(
                                                c.submissionDate!.toLocal(),
                                              )
                                            : '—',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        c.feeAmount != null
                                            ? c.feeAmount!.toStringAsFixed(2)
                                            : '—',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (remaining > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _visibleCount += _pageSize;
                            }),
                            child: Text('Load more ($remaining remaining)'),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Showing ${visible.length} of ${filtered.length}',
                        style: Theme.of(context).textTheme.bodySmall,
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
