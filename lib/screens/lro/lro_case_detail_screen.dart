import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/lro/lro_theme.dart';
import '../../models/lro_case.dart';
import '../../models/lro_document.dart';
import '../../models/lro_history.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../services/lro_export_service.dart';
import '../../widgets/lro/lro_status_badge.dart';
import 'lro_case_form_screen.dart';

/// Full detail view for a single case: fields, attachments and audit
/// history. Always reached via [Navigator.push].
class LroCaseDetailScreen extends ConsumerStatefulWidget {
  const LroCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<LroCaseDetailScreen> createState() =>
      _LroCaseDetailScreenState();
}

class _LroCaseDetailScreenState extends ConsumerState<LroCaseDetailScreen> {
  final _exportService = LroExportService();
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  LroCase? _lroCase;
  List<LroDocument> _documents = const [];
  List<LroHistory> _history = const [];
  bool _loading = true;
  bool _uploading = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(lroRepositoryProvider);
    final lroCase = await repo.getCase(widget.caseId);
    final documents = lroCase == null
        ? <LroDocument>[]
        : await repo.listDocuments('case', widget.caseId);
    final history = lroCase == null
        ? <LroHistory>[]
        : await repo.listHistory('case', widget.caseId);
    if (!mounted) return;
    setState(() {
      _lroCase = lroCase;
      _documents = documents;
      _history = history;
      _loading = false;
    });
  }

  void _invalidateLists() {
    ref.invalidate(lroCases528Provider);
    ref.invalidate(lroCases928Provider);
    ref.invalidate(lroStatsProvider);
  }

  Future<void> _edit() async {
    final current = _lroCase;
    if (current == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LroCaseFormScreen(
          caseType: current.type,
          existing: current,
        ),
      ),
    );
    if (saved == true) {
      _invalidateLists();
      await _load();
    }
  }

  Future<void> _delete() async {
    final current = _lroCase;
    if (current == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete case?'),
        content: Text(
          'This will remove case ${current.caseNumber}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(lroRepositoryProvider).deleteCase(widget.caseId);
      _invalidateLists();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _upload() async {
    final user = ref.read(authUserProvider);
    setState(() => _uploading = true);
    try {
      final doc = await ref.read(fileStorageServiceProvider).pickAndUploadLroDocument(
            parentType: 'case',
            parentId: widget.caseId,
            uploadedBy: user?.displayName ?? '',
          );
      if (doc != null) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _exportPdf() async {
    final current = _lroCase;
    if (current == null) return;
    final members = ref.read(membersProvider).valueOrNull ?? const <Member>[];
    final memberName =
        members.firstWhereOrNull((m) => m.id == current.memberId)?.fullName;
    final bytes =
        await _exportService.caseDetailToPdf(current, memberName: memberName);
    await _exportService.saveOrShare(
      bytes: bytes,
      fileName: '${current.caseNumber}_detail.pdf',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported')),
      );
    }
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final lroCase = _lroCase;

    return LroThemed(
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          lroCase == null
              ? 'Case Detail'
              : '${lroCase.type.label} — ${lroCase.caseNumber}',
        ),
        actions: lroCase == null
            ? null
            : [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _edit,
                ),
                IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: _exportPdf,
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                  onPressed: _deleting ? null : _delete,
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : lroCase == null
              ? const Center(child: Text('Case not found.'))
              : membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading members: $e')),
                  data: (members) {
                    final memberName = members
                            .firstWhereOrNull((m) => m.id == lroCase.memberId)
                            ?.fullName ??
                        lroCase.memberId;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            LroStatusBadge(
                              status: lroCase.status,
                              label: lroCase.statusEnum.label,
                            ),
                            const Spacer(),
                            if (_uploading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _field('Member', memberName),
                                _field('Case Number', lroCase.caseNumber),
                                _field(
                                  'Recording Number',
                                  lroCase.recordingNumber ?? '—',
                                ),
                                _field(
                                  'Subject Name',
                                  lroCase.subjectName.isEmpty
                                      ? '—'
                                      : lroCase.subjectName,
                                ),
                                _field(
                                  'Property Address',
                                  lroCase.propertyAddress.isEmpty
                                      ? '—'
                                      : lroCase.propertyAddress,
                                ),
                                _field(
                                  'Property Size',
                                  lroCase.propertySize.isEmpty
                                      ? '—'
                                      : lroCase.propertySize,
                                ),
                                _field(
                                  'Zoning Type',
                                  lroCase.zoningType.isEmpty
                                      ? '—'
                                      : lroCase.zoningType,
                                ),
                                _field(
                                  'Assigned Officer',
                                  lroCase.assignedOfficer.isEmpty
                                      ? '—'
                                      : lroCase.assignedOfficer,
                                ),
                                _field(
                                  'Fee Amount',
                                  lroCase.feeAmount != null
                                      ? lroCase.feeAmount!.toStringAsFixed(2)
                                      : '—',
                                ),
                                _field(
                                  'Submission Date',
                                  lroCase.submissionDate != null
                                      ? _dateFmt.format(
                                          lroCase.submissionDate!.toLocal(),
                                        )
                                      : '—',
                                ),
                                _field(
                                  'Approval Date',
                                  lroCase.approvalDate != null
                                      ? _dateFmt.format(
                                          lroCase.approvalDate!.toLocal(),
                                        )
                                      : '—',
                                ),
                                _field(
                                  'Published Date',
                                  lroCase.publishedDate != null
                                      ? _dateFmt.format(
                                          lroCase.publishedDate!.toLocal(),
                                        )
                                      : '—',
                                ),
                                _field(
                                  'Notes',
                                  lroCase.notes.isEmpty ? '—' : lroCase.notes,
                                ),
                                if (lroCase.rejectionReason.isNotEmpty)
                                  _field(
                                    'Rejection Reason',
                                    lroCase.rejectionReason,
                                  ),
                                _field(
                                  'Created By',
                                  lroCase.createdBy.isEmpty
                                      ? '—'
                                      : lroCase.createdBy,
                                ),
                                _field(
                                  'Updated By',
                                  lroCase.updatedBy.isEmpty
                                      ? '—'
                                      : lroCase.updatedBy,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Attachments',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: LroTheme.text(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : _upload,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text('Upload'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_documents.isEmpty)
                          const Text('No attachments yet.')
                        else
                          ..._documents.map(
                            (d) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file_outlined),
                                title: Text(d.fileName),
                                subtitle: Text(
                                  '${d.docType} · ${_dateFmt.format(d.uploadedAt.toLocal())} · ${d.uploadedBy}',
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Audit History',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: LroTheme.text(context),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_history.isEmpty)
                          const Text('No history yet.')
                        else
                          ..._history.map(
                            (h) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.history, size: 20),
                              title: Text(h.action),
                              subtitle: Text(
                                '${h.fromStatus != null ? '${h.fromStatus} → ' : ''}${h.toStatus ?? ''}'
                                '${h.detail.isNotEmpty ? ' · ${h.detail}' : ''}\n'
                                '${_dateFmt.format(h.changedAt.toLocal())} by ${h.changedBy}',
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
    ),
    );
  }
}
