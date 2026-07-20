import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/lro/lro_theme.dart';
import '../../models/lro_case.dart';
import '../../models/lro_notice.dart';
import '../../providers/providers.dart';
import '../../services/lro_export_service.dart';

/// Date-ranged CSV / Excel / PDF exports across cases and notices.
class LroReportsScreen extends ConsumerStatefulWidget {
  const LroReportsScreen({super.key});

  @override
  ConsumerState<LroReportsScreen> createState() => _LroReportsScreenState();
}

class _LroReportsScreenState extends ConsumerState<LroReportsScreen> {
  final _exportService = LroExportService();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime? _from;
  DateTime? _to;
  bool _include528 = true;
  bool _include928 = true;
  bool _includeNotices = false;
  bool _exporting = false;

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<List<LroCase>> _selectedCases() async {
    final repo = ref.read(lroRepositoryProvider);
    final cases = <LroCase>[];
    if (_include528) {
      cases.addAll(await repo.listCases(type: LroCaseType.status528));
    }
    if (_include928) {
      cases.addAll(await repo.listCases(type: LroCaseType.emancipation928));
    }
    return _exportService.filterCases(cases, from: _from, to: _to);
  }

  Future<List<LroNotice>> _selectedNotices() async {
    if (!_includeNotices) return const [];
    final repo = ref.read(lroRepositoryProvider);
    final notices = await repo.listNotices();
    return _exportService.filterNotices(notices, from: _from, to: _to);
  }

  bool _validateSelection() {
    if (!_include528 && !_include928 && !_includeNotices) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one category to export.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _exportCsv() async {
    if (!_validateSelection()) return;
    setState(() => _exporting = true);
    try {
      final stamp = _dateFmt.format(DateTime.now());
      if (_include528 || _include928) {
        final cases = await _selectedCases();
        await _exportService.saveOrShareText(
          text: _exportService.casesToCsv(cases),
          fileName: 'lro_cases_$stamp.csv',
        );
      }
      if (_includeNotices) {
        final notices = await _selectedNotices();
        await _exportService.saveOrShareText(
          text: _exportService.noticesToCsv(notices),
          fileName: 'lro_notices_$stamp.csv',
        );
      }
      _notifyDone();
    } catch (error) {
      _notifyError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportXlsx() async {
    if (!_validateSelection()) return;
    setState(() => _exporting = true);
    try {
      final stamp = _dateFmt.format(DateTime.now());
      if (_include528 || _include928) {
        final cases = await _selectedCases();
        await _exportService.saveOrShare(
          bytes: _exportService.casesToXlsx(cases),
          fileName: 'lro_cases_$stamp.xlsx',
        );
      }
      if (_includeNotices) {
        final notices = await _selectedNotices();
        await _exportService.saveOrShare(
          bytes: _exportService.noticesToXlsx(notices),
          fileName: 'lro_notices_$stamp.xlsx',
        );
      }
      _notifyDone();
    } catch (error) {
      _notifyError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (!_validateSelection()) return;
    setState(() => _exporting = true);
    try {
      final stamp = _dateFmt.format(DateTime.now());
      if (_include528 || _include928) {
        final cases = await _selectedCases();
        final bytes = await _exportService.casesToPdfSummary(
          cases,
          title: 'LRO Cases Report',
        );
        await _exportService.saveOrShare(
          bytes: bytes,
          fileName: 'lro_cases_summary_$stamp.pdf',
        );
      }
      if (_includeNotices) {
        final notices = await _selectedNotices();
        final bytes = await _exportService.noticesToPdf(notices);
        await _exportService.saveOrShare(
          bytes: bytes,
          fileName: 'lro_notices_$stamp.pdf',
        );
      }
      _notifyDone();
    } catch (error) {
      _notifyError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _notifyDone() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export ready.')),
    );
  }

  void _notifyError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LroThemed(
      child: Scaffold(
      appBar: AppBar(title: const Text('LRO Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: LroTheme.text(context),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'From',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_from != null ? _dateFmt.format(_from!) : 'Any'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'To',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_to != null ? _dateFmt.format(_to!) : 'Any'),
                  ),
                ),
              ),
              if (_from != null || _to != null)
                IconButton(
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Include',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: LroTheme.text(context),
                  fontWeight: FontWeight.bold,
                ),
          ),
          CheckboxListTile(
            value: _include528,
            title: const Text('528 Status Correction cases'),
            onChanged: (v) => setState(() => _include528 = v ?? false),
          ),
          CheckboxListTile(
            value: _include928,
            title: const Text('928 Emancipation cases'),
            onChanged: (v) => setState(() => _include928 = v ?? false),
          ),
          CheckboxListTile(
            value: _includeNotices,
            title: const Text('Public Notices'),
            onChanged: (v) => setState(() => _includeNotices = v ?? false),
          ),
          const SizedBox(height: 24),
          Text(
            'Export',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: LroTheme.text(context),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export CSV'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportXlsx,
            icon: const Icon(Icons.grid_on_outlined),
            label: const Text('Export Excel (.xlsx)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDF Summary'),
          ),
          if (_exporting) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    ),
    );
  }
}
