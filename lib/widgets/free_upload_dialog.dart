import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';
import '../models/remuneration_settings.dart';
import '../providers/providers.dart';

/// Admin-only dialog to mark one or more Member onboarding steps as
/// completed-and-paid via "Free Upload" (no actual money taken).
///
/// Layout mirrors the approved design plan:
///  - step list from RS Remuneration Settings (names + amounts, dynamic)
///  - first 4 Steps activated by default; Step 5 off; already-paid Steps locked
///  - [All] / [Deselect All] bulk controls
///  - live summary (activated count, total value, remaining to pay)
///  - confirmation dialog before applying
///  - reversal with a warning when Step 4_LRO was already published
class FreeUploadDialog extends ConsumerStatefulWidget {
  const FreeUploadDialog({super.key, required this.member});

  final Member member;

  @override
  ConsumerState<FreeUploadDialog> createState() => _FreeUploadDialogState();
}

class _FreeUploadDialogState extends ConsumerState<FreeUploadDialog> {
  late Map<int, bool> _selections;
  final _reasonController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(remunerationSettingsProvider).valueOrNull;
    final steps = settings?.configuredSteps ?? const <RemunerationStep>[];
    _selections = {
      for (final step in steps)
        step.number: _defaultActive(step.number, steps.length),
    };
  }

  /// First 4 Steps active by default; Step 5 off. Locked (already-paid) steps
  /// cannot be toggled, so their selection is forced off (they're untouched).
  bool _defaultActive(int stepNumber, int totalSteps) {
    if (_isLocked(stepNumber)) return false;
    return stepNumber <= 4;
  }

  bool _isLocked(int stepNumber) => widget.member.isStepCompleteAt(stepNumber);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<RemunerationStep> get _steps =>
      ref.watch(remunerationSettingsProvider).valueOrNull?.configuredSteps ??
      const [];

  double _amountFor(int stepNumber) =>
      ref.watch(remunerationSettingsProvider).valueOrNull?.stepAmount(stepNumber) ??
      0.0;

  List<int> get _selectedUnpaid =>
      _steps.where((s) => _selections[s.number] == true).map((s) => s.number).toList();

  double get _selectedValue => _selectedUnpaid.fold<double>(
        0,
        (sum, step) => sum + _amountFor(step),
      );

  double get _totalOutstanding => _steps.fold<double>(
        0,
        (sum, step) => sum + (widget.member.isStepCompleteAt(step.number) ? 0 : _amountFor(step.number)),
      );

  double get _remaining => _totalOutstanding - _selectedValue;

  Future<void> _apply() async {
    final actor = ref.read(authUserProvider);
    if (actor == null) return;
    final settings = ref.read(remunerationSettingsProvider).valueOrNull;
    if (settings == null) return;

    final confirmed = await _confirmApply();
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      final svc = ref.read(freeUploadServiceProvider);
      final updated = await svc.apply(
        member: widget.member,
        actor: actor,
        steps: _selectedUnpaid,
        settings: settings,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Free Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmApply() async {
    final settings = ref.read(remunerationSettingsProvider).valueOrNull;
    final steps = _selectedUnpaid;
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one Step to Free Upload.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    final lines = steps
        .map((s) =>
            '• ${settings?.stepName(s)} – R ${_amountFor(s).toStringAsFixed(2)}')
        .join('\n');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm Free Upload'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Member: ${widget.member.fullName}'),
              const SizedBox(height: 8),
              const Text('Activated Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(lines),
              const SizedBox(height: 8),
              Text(
                'Total Free Upload Value: R ${_selectedValue.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action will be logged in the audit trail.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Free Upload'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Reverses prior Free Uploads on already-free-uploaded steps. Warns when
  /// Step 4_LRO was already published to Facebook / LRO Publications.
  Future<void> _reverse() async {
    final actor = ref.read(authUserProvider);
    if (actor == null) return;
    final settings = ref.read(remunerationSettingsProvider).valueOrNull;
    if (settings == null) return;

    final freeUploaded = _steps
        .where((s) => widget.member.paymentFor(s.number)?.isFreeUpload == true)
        .map((s) => s.number)
        .toList();
    if (freeUploaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Free Uploaded Steps to reverse for this Member.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final publishedLro =
        widget.member.lroPublicationDate != null && freeUploaded.contains(4);
    if (publishedLro) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Reverse Published LRO?'),
            ],
          ),
          content: const Text(
            '⚠️ This Member’s LRO has already been published. Reversing this '
            'Free Upload will NOT remove the published notice from Facebook or '
            'the LRO Publications section. Only the Member’s record will be '
            'updated. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reverse Anyway'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      final svc = ref.read(freeUploadServiceProvider);
      final updated = await svc.reverse(
        member: widget.member,
        actor: actor,
        steps: freeUploaded,
        settings: settings,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Free Upload reversed.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reversal failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final hasFreeUploaded = steps.any(
      (s) => widget.member.paymentFor(s.number)?.isFreeUpload == true,
    );

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.upload_file_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text('Free Upload – ${widget.member.fullName}')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select the Steps to mark as completed (Free Upload).',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              for (final s in steps) {
                                if (!_isLocked(s.number)) {
                                  _selections[s.number] = true;
                                }
                              }
                            }),
                    child: const Text('All'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              for (final s in steps) {
                                _selections[s.number] = false;
                              }
                            }),
                    child: const Text('Deselect All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...steps.map((step) {
                final locked = _isLocked(step.number);
                final selected = _selections[step.number] ?? false;
                final isFree = widget.member.paymentFor(step.number)?.isFreeUpload == true;
                return ListTile(
                  leading: locked
                      ? const Icon(Icons.lock_outline, color: Colors.green)
                      : Switch(
                          value: selected,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _selections[step.number] = v),
                        ),
                  title: Text(step.name),
                  subtitle: locked
                      ? Text(isFree ? 'Free Uploaded' : 'Paid')
                      : Text('R ${step.amount.toStringAsFixed(2)}'),
                  trailing: locked
                      ? const Chip(
                          label: Text('Paid'),
                          backgroundColor: Color(0xFFE6F4EA),
                        )
                      : Chip(
                          label: Text(selected ? 'Activated' : 'Deactivated'),
                          backgroundColor: selected
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFFCE8E6),
                        ),
                );
              }),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activated Steps: ${_selectedUnpaid.length}'),
                      Text(
                        'Total Free Upload Value: R ${_selectedValue.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Remaining to Pay: R ${_remaining < 0 ? 0 : _remaining.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '💡 Only Steps not already paid will be affected.',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (hasFreeUploaded)
          TextButton(
            onPressed: _busy ? null : _reverse,
            child: const Text('Reverse Free Upload'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _apply,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply Free Upload'),
        ),
      ],
    );
  }
}
