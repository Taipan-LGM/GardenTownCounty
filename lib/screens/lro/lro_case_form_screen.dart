import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/lro/lro_theme.dart';
import '../../models/lro_case.dart';
import '../../providers/providers.dart';

/// Create/edit form for a 528 or 928 case.
class LroCaseFormScreen extends ConsumerStatefulWidget {
  const LroCaseFormScreen({
    super.key,
    required this.caseType,
    this.existing,
  });

  final LroCaseType caseType;
  final LroCase? existing;

  @override
  ConsumerState<LroCaseFormScreen> createState() => _LroCaseFormScreenState();
}

class _LroCaseFormScreenState extends ConsumerState<LroCaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caseNumberCtrl = TextEditingController();
  final _recordingNumberCtrl = TextEditingController();
  final _subjectNameCtrl = TextEditingController();
  final _propertyAddressCtrl = TextEditingController();
  final _propertySizeCtrl = TextEditingController();
  final _zoningTypeCtrl = TextEditingController();
  final _assignedOfficerCtrl = TextEditingController();
  final _feeAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  String? _memberId;
  DateTime? _submissionDate;
  late String _status;
  String _rejectionReason = '';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _memberId = existing.memberId;
      _caseNumberCtrl.text = existing.caseNumber;
      _recordingNumberCtrl.text = existing.recordingNumber ?? '';
      _subjectNameCtrl.text = existing.subjectName;
      _propertyAddressCtrl.text = existing.propertyAddress;
      _propertySizeCtrl.text = existing.propertySize;
      _zoningTypeCtrl.text = existing.zoningType;
      _assignedOfficerCtrl.text = existing.assignedOfficer;
      _feeAmountCtrl.text = existing.feeAmount?.toStringAsFixed(2) ?? '';
      _notesCtrl.text = existing.notes;
      _submissionDate = existing.submissionDate;
      _status = existing.status;
      _rejectionReason = existing.rejectionReason;
    } else {
      _status = LroCaseStatus.draft.code;
    }
  }

  @override
  void dispose() {
    _caseNumberCtrl.dispose();
    _recordingNumberCtrl.dispose();
    _subjectNameCtrl.dispose();
    _propertyAddressCtrl.dispose();
    _propertySizeCtrl.dispose();
    _zoningTypeCtrl.dispose();
    _assignedOfficerCtrl.dispose();
    _feeAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSubmissionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _submissionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _submissionDate = picked);
  }

  Future<bool> _promptRejectionReason() async {
    final controller = TextEditingController(text: _rejectionReason);
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rejection Reason Required'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Explain why this case is being rejected',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty) return false;
    setState(() => _rejectionReason = reason.trim());
    return true;
  }

  Future<void> _onStatusChanged(String? value) async {
    if (value == null) return;
    if (value == LroCaseStatus.rejected.code) {
      final ok = await _promptRejectionReason();
      if (!ok) return;
    }
    setState(() => _status = value);
  }

  Future<void> _save(bool isAdmin) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_memberId == null || _memberId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member.')),
      );
      return;
    }
    if (isAdmin &&
        _status == LroCaseStatus.rejected.code &&
        _rejectionReason.trim().isEmpty) {
      final ok = await _promptRejectionReason();
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final authUser = ref.read(authUserProvider);
      final updatedBy = authUser?.displayName ?? '';
      final now = DateTime.now().toUtc();
      final feeText = _feeAmountCtrl.text.trim();
      final recordingText = _recordingNumberCtrl.text.trim();
      final rejectionReason =
          _status == LroCaseStatus.rejected.code ? _rejectionReason : '';

      final LroCase toSave;
      if (widget.existing == null) {
        toSave = LroCase(
          id: const Uuid().v4(),
          memberId: _memberId!,
          caseType: widget.caseType.code,
          caseNumber: _caseNumberCtrl.text.trim(),
          recordingNumber: recordingText.isEmpty ? null : recordingText,
          subjectName: _subjectNameCtrl.text.trim(),
          propertyAddress: _propertyAddressCtrl.text.trim(),
          propertySize: _propertySizeCtrl.text.trim(),
          zoningType: _zoningTypeCtrl.text.trim(),
          status: _status,
          submissionDate: _submissionDate,
          assignedOfficer: _assignedOfficerCtrl.text.trim(),
          feeAmount: feeText.isEmpty ? null : double.tryParse(feeText),
          notes: _notesCtrl.text.trim(),
          rejectionReason: rejectionReason,
          createdBy: updatedBy,
          updatedBy: updatedBy,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        toSave = widget.existing!.copyWith(
          memberId: _memberId,
          caseNumber: _caseNumberCtrl.text.trim(),
          recordingNumber: recordingText.isEmpty ? null : recordingText,
          clearRecordingNumber: recordingText.isEmpty,
          subjectName: _subjectNameCtrl.text.trim(),
          propertyAddress: _propertyAddressCtrl.text.trim(),
          propertySize: _propertySizeCtrl.text.trim(),
          zoningType: _zoningTypeCtrl.text.trim(),
          status: _status,
          submissionDate: _submissionDate,
          clearSubmissionDate: _submissionDate == null,
          assignedOfficer: _assignedOfficerCtrl.text.trim(),
          feeAmount: feeText.isEmpty ? null : double.tryParse(feeText),
          clearFeeAmount: feeText.isEmpty,
          notes: _notesCtrl.text.trim(),
          rejectionReason: rejectionReason,
          updatedBy: updatedBy,
        );
      }

      await ref.read(lroRepositoryProvider).saveCase(toSave);

      ref.invalidate(lroCases528Provider);
      ref.invalidate(lroCases928Provider);
      ref.invalidate(lroStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Case updated' : 'Case created')),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final membersAsync = ref.watch(membersProvider);

    return LroThemed(
      child: Scaffold(
      appBar: AppBar(
        title: Text('${_isEdit ? 'Edit' : 'New'} ${widget.caseType.label} Case'),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading members: $e')),
        data: (members) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _memberId,
                  decoration: const InputDecoration(labelText: 'Member *'),
                  items: members
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _memberId = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Member is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caseNumberCtrl,
                  decoration: const InputDecoration(labelText: 'Case Number *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Case number is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recordingNumberCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Recording Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectNameCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _propertyAddressCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Property Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _propertySizeCtrl,
                  decoration: const InputDecoration(labelText: 'Property Size'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _zoningTypeCtrl,
                  decoration: const InputDecoration(labelText: 'Zoning Type'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assignedOfficerCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Assigned Officer'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _feeAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fee Amount (optional)',
                    prefixText: 'R ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return double.tryParse(v.trim()) == null
                        ? 'Enter a valid amount'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickSubmissionDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Submission Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _submissionDate != null
                          ? _dateFmt.format(_submissionDate!.toLocal())
                          : 'Not set',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isAdmin) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: LroCaseStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.code,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    onChanged: _onStatusChanged,
                  ),
                  if (_status == LroCaseStatus.rejected.code &&
                      _rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rejection reason: $_rejectionReason',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.brick,
                          ),
                    ),
                  ],
                ] else
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Status'),
                    child: Text(LroCaseStatus.fromCode(_status).label),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(isAdmin),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving…' : 'Save Case'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}
