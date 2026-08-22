import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/lro_settings.dart';
import '../models/member.dart';
import '../providers/providers.dart';
import '../services/lro_notice_renderer.dart';
import '../services/lro_payment_workflow.dart';
import '../services/lro_settings_service.dart';
import '../services/county_settings_service.dart';
import '../services/database_service.dart';
import '../services/activity_service.dart';
import '../widgets/standard_buttons.dart';

/// Review + publish dialog for a Member's Personal Public Notice.
///
/// Opened from the "LRO Publication" button on a Member row in the Payments
/// (Admin Only) screen. Shows the populated Public Notice (rendered from the
/// active county's LRO Settings) and the eight source fields, then — after a
/// confirmation — publishes to the County Facebook page, the in-app LRO
/// Publications section, and the Member's Application Form.
///
/// The [Publish] button is disabled until Step 4_LRO payment is complete
/// (which generates the Recording Number). If the notice was already
/// published, the dialog shows the publication timestamp and actor instead.
class LroPublicationDialog extends ConsumerStatefulWidget {
  const LroPublicationDialog({
    super.key,
    required this.member,
  });

  final Member member;

  @override
  ConsumerState<LroPublicationDialog> createState() =>
      _LroPublicationDialogState();
}

class _LroPublicationDialogState extends ConsumerState<LroPublicationDialog> {
  bool _busy = false;
  Uint8List? _previewBytes;
  bool _previewLoading = true;
  String? _previewError;
  Member? _member;
  String _countyName = 'Garden Town County';

  bool get _alreadyPublished =>
      _member?.lroPublicationDate != null;

  bool get _canPublish =>
      !_alreadyPublished &&
      (_member?.step4LROComplete == true) &&
      (_member?.lroRecordNo?.isNotEmpty == true);

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _previewLoading = true);
    try {
      final countyId = ref.read(activeCountyIdProvider);
      final settings = await ref
          .read(lroSettingsServiceProvider)
          .load(countyId: countyId);
      final countyProfile =
          await ref.read(countySettingsServiceProvider).load(countyId: countyId);
      final countyName = countyProfile.countyName.trim().isNotEmpty
          ? countyProfile.countyName.trim()
          : 'Garden Town County';
      if (mounted) setState(() => _countyName = countyName);
      final member = _member!;
      final paymentDate = member.step4CompletionDate ?? DateTime.now();

      Uint8List? bytes;
      if (settings.noticeTemplate != null) {
        final sealBytes = await ref
            .read(lroSettingsServiceProvider)
            .loadCountySealBytes(countyId: countyId);
        bytes = LroNoticeRenderer.render(
          style: settings.noticeTemplate!,
          countyName: countyName,
          memberName: member.fullName,
          recordingNumber: member.lroRecordNo ?? '',
          paymentDate: paymentDate,
          statusCorrections: settings.statusCorrections,
          sealBytes:
              (sealBytes != null && sealBytes.isNotEmpty) ? sealBytes : null,
        );
      } else {
        // Legacy overlay path requires an uploaded template image. Render via
        // the workflow's private overlay through a thin helper.
        final templateBytes = await ref
            .read(lroSettingsServiceProvider)
            .loadPublicNoticeTemplateBytes(countyId: countyId);
        if (templateBytes != null && templateBytes.isNotEmpty) {
          final workflow = LroPaymentWorkflow(
            ref.read(databaseServiceProvider),
            ref.read(activityServiceProvider),
            ref.read(lroSettingsServiceProvider),
            ref.read(countySettingsServiceProvider),
            countyId: countyId,
          );
          bytes = await workflow.renderLegacyOverlay(
            templateBytes,
            countyName: countyName,
            memberName: member.fullName,
            recordingNumber: member.lroRecordNo ?? '',
            paymentDate: paymentDate,
            statusCorrections: settings.statusCorrections,
          );
        }
      }
      if (mounted) {
        setState(() {
          _previewBytes = bytes;
          _previewLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewError = e.toString();
          _previewLoading = false;
        });
      }
    }
  }

  Future<void> _confirmAndPublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Publication'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to publish this Public Notice?'),
            SizedBox(height: 12),
            Text('This will publish to:'),
            SizedBox(height: 6),
            Text('• County Facebook page'),
            Text('• LRO Publications (in-app)'),
            Text('• Member\'s Application Form'),
          ],
        ),
        actions: [
          CancelButton(
            onPressed: () => Navigator.pop(context, false),
            text: 'Cancel',
          ),
          SubmitButton(
            onPressed: () => Navigator.pop(context, true),
            text: 'Confirm Publish',
            icon: Icons.cloud_upload_outlined,
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final countyId = ref.read(activeCountyIdProvider);
      final actor = ref.read(authUserProvider);
      final actorId = actor?.displayName ?? 'System';
      final workflow = LroPaymentWorkflow(
        ref.read(databaseServiceProvider),
        ref.read(activityServiceProvider),
        ref.read(lroSettingsServiceProvider),
        ref.read(countySettingsServiceProvider),
        countyId: countyId,
      );
      final updated = await workflow.publish(
        member: _member!,
        actorId: actorId,
      );
      final member = await ref
          .read(databaseServiceProvider)
          .getMemberById(updated.id);
      if (mounted) {
        setState(() {
          _member = member ?? updated;
          _busy = false;
        });
      }
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Published successfully!'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Public Notice published to:'),
                SizedBox(height: 6),
                Text('• County Facebook page (best-effort)'),
                Text('• LRO Publications (✓)'),
                Text('• Member\'s Application Form (✓)'),
              ],
            ),
            actions: [
              SubmitButton(
                onPressed: () {
                  Navigator.pop(context); // close success dialog
                  Navigator.pop(context, member ?? updated); // return updated member
                },
                text: 'Done',
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publish failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = _member ?? widget.member;
    final dateStr = member.step4CompletionDate != null
        ? DateFormat('dd/MM/yyyy').format(member.step4CompletionDate!)
        : '—';

    return AlertDialog(
      title: const Text('Personal Public Notice'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice preview
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: _previewLoading
                    ? const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _previewError != null
                        ? SizedBox(
                            height: 220,
                            child: Center(
                              child: Text(
                                'Preview unavailable:\n$_previewError',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          )
                        : _previewBytes != null
                            ? Image.memory(_previewBytes!, fit: BoxFit.contain)
                            : const SizedBox(
                                height: 220,
                                child: Center(
                                  child:
                                      Text('No Public Notice template configured.'),
                                ),
                              ),
              ),
              const SizedBox(height: 12),
              // Source fields
              _field('Member', '${member.fullName} (C)'),
              _field('Recording Number', member.lroRecordNo ?? '—'),
              _field('Date of Registration', dateStr),
              _field('County Name', _countyName),
              _field('Land Recording Office', 'Fixed text'),
              _field('County Seal', 'Uploaded seal image'),
              _field('Public Notice Text', 'Template design'),
              if (_alreadyPublished) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Already published on '
                    '${DateFormat('dd/MM/yyyy HH:mm').format(member.lroPublicationDate!)} '
                    'by ${member.lroPublishedBy ?? 'Unknown'}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        CancelButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          text: 'Close',
        ),
        if (!_alreadyPublished)
          SubmitButton(
            onPressed: (_busy || !_canPublish) ? null : _confirmAndPublish,
            text: _busy
                ? 'Publishing…'
                : (member.step4LROComplete
                    ? 'Publish'
                    : 'Complete Step 4_LRO first'),
            icon: Icons.cloud_upload_outlined,
          ),
      ],
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
