import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/lro_notice.dart';
import '../../providers/providers.dart';
import '../../widgets/lro/lro_theme.dart';

/// Create/edit form for a public notice.
class LroNoticeFormScreen extends ConsumerStatefulWidget {
  const LroNoticeFormScreen({super.key, this.existing});

  final LroNotice? existing;

  @override
  ConsumerState<LroNoticeFormScreen> createState() =>
      _LroNoticeFormScreenState();
}

class _LroNoticeFormScreenState extends ConsumerState<LroNoticeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime? _publicationDate;
  DateTime? _expiryDate;
  String _status = LroNoticeStatus.draft.code;
  String? _memberId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _contentCtrl.text = existing.content;
      _publicationDate = existing.publicationDate;
      _expiryDate = existing.expiryDate;
      _status = existing.status;
      _memberId = existing.memberId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final initial =
        (isExpiry ? _expiryDate : _publicationDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isExpiry) {
        _expiryDate = picked;
      } else {
        _publicationDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final authUser = ref.read(authUserProvider);
      final updatedBy = authUser?.displayName ?? '';
      final now = DateTime.now().toUtc();

      final LroNotice toSave;
      if (widget.existing == null) {
        toSave = LroNotice(
          id: const Uuid().v4(),
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          publicationDate: _publicationDate,
          expiryDate: _expiryDate,
          status: _status,
          memberId: _memberId,
          createdBy: updatedBy,
          updatedBy: updatedBy,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        toSave = widget.existing!.copyWith(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          publicationDate: _publicationDate,
          clearPublicationDate: _publicationDate == null,
          expiryDate: _expiryDate,
          clearExpiryDate: _expiryDate == null,
          status: _status,
          memberId: _memberId,
          clearMemberId: _memberId == null,
          updatedBy: updatedBy,
        );
      }

      await ref.read(lroRepositoryProvider).saveNotice(toSave);
      ref.invalidate(lroNoticesProvider);
      ref.invalidate(lroNoticeFeedProvider);
      ref.invalidate(lroStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Notice updated' : 'Notice created'),
          ),
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
    final membersAsync = ref.watch(membersProvider);

    return LroThemed(
      child: Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Notice' : 'New Notice')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading members: $e')),
        data: (members) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickDate(isExpiry: false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Publication Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _publicationDate != null
                          ? _dateFmt.format(_publicationDate!.toLocal())
                          : 'Not set',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickDate(isExpiry: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiry Date (optional)',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _expiryDate != null
                          ? _dateFmt.format(_expiryDate!.toLocal())
                          : 'Not set',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _memberId,
                  decoration:
                      const InputDecoration(labelText: 'Related Member (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    ...members.map(
                      (m) => DropdownMenuItem(value: m.id, child: Text(m.fullName)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _memberId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: LroNoticeStatus.values
                      .map(
                        (s) => DropdownMenuItem(value: s.code, child: Text(s.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
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
                  label: Text(_saving ? 'Saving…' : 'Save Notice'),
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
