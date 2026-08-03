import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/app_user.dart';
import '../../models/member.dart';
import '../../models/member_file.dart';
import '../../models/remuneration_settings.dart';
import '../../models/secretary_remuneration.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';

class _ManualPaymentRequest {
  const _ManualPaymentRequest({
    required this.memberId,
    required this.secretaryId,
    required this.secretaryName,
    required this.stepNumber,
    required this.paymentDateTime,
    required this.receiptNumber,
    this.notes,
  });

  final String memberId;
  final String secretaryId;
  final String secretaryName;
  final int stepNumber;
  final DateTime paymentDateTime;
  final String receiptNumber;
  final String? notes;
}

class _CardPaymentRequest {
  const _CardPaymentRequest({required this.memberId, required this.stepNumber});

  final String memberId;
  final int stepNumber;
}

typedef _PaymentScreenData = ({
  List<SecretaryRemuneration> records,
  Map<String, List<MemberFile>> filesByMember,
  List<AppUser> secretaries,
});

class StepWorkflowScreen extends ConsumerStatefulWidget {
  const StepWorkflowScreen({super.key, required this.stepNumber});

  final int stepNumber;

  @override
  ConsumerState<StepWorkflowScreen> createState() => _StepWorkflowScreenState();
}

class _StepWorkflowScreenState extends ConsumerState<StepWorkflowScreen> {
  final Set<String> _busyMemberIds = <String>{};
  final TextEditingController _paymentSearchController =
      TextEditingController();
  int _historyRefreshTick = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _viewBySecretary = false;
  String? _selectedSecretaryId;
  String? _paymentDataSignature;
  Future<_PaymentScreenData>? _paymentDataFuture;

  @override
  void dispose() {
    _paymentSearchController.dispose();
    super.dispose();
  }

  bool _matchesMemberSearch(Member member, String query) {
    if (query.isEmpty) return true;
    final searchable = [
      member.fullName,
      member.saId,
      member.globalRecordNo,
      member.lroRecordNo ?? '',
      member.address,
      member.suburb,
      member.townCity,
      member.postalCode,
      member.contactNo1,
      member.contactNo2,
      member.emailAddress,
      member.comment,
      member.assignedSecretaryName ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  bool _matchesPaymentSearch(
    SecretaryRemuneration record,
    Member? member,
    String query,
  ) {
    if (query.isEmpty) return true;
    if (member != null && _matchesMemberSearch(member, query)) return true;
    final searchable = [
      record.memberName,
      record.memberId,
      record.secretaryName,
      record.secretaryId,
      record.type,
      record.description,
      record.status,
      record.notes ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  bool _recordInDateRange(SecretaryRemuneration record) {
    final timestamp = (record.datePaid ?? record.dateEarned).toLocal();
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final start = _startDate;
    final end = _endDate;
    if (start != null &&
        date.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null && date.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  Future<_PaymentScreenData> _loadPaymentData(
    List<Member> members, {
    required bool isAdmin,
  }) async {
    final database = ref.read(databaseServiceProvider);
    final records = await database.getAllRemunerationRecords();
    final secretaries = isAdmin
        ? await database.getRecordingSecretaries(activeOnly: true)
        : const <AppUser>[];
    final memberFiles = await Future.wait(
      members.map((member) async {
        return MapEntry(
          member.id,
          await database.getFilesForMember(member.id),
        );
      }),
    );
    return (
      records: records,
      filesByMember: Map<String, List<MemberFile>>.fromEntries(memberFiles),
      secretaries: secretaries,
    );
  }

  Future<_PaymentScreenData> _paymentDataFor(
    List<Member> members, {
    required bool isAdmin,
  }) {
    final signature = [
      isAdmin,
      _historyRefreshTick,
      ...members.map((member) => '${member.id}:${member.updatedAt}'),
    ].join('|');
    if (_paymentDataFuture == null || _paymentDataSignature != signature) {
      _paymentDataSignature = signature;
      _paymentDataFuture = _loadPaymentData(members, isAdmin: isAdmin);
    }
    return _paymentDataFuture!;
  }

  Future<void> _pickFilterDate({required bool start}) async {
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  String _csvCell(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';

  Future<void> _exportPaymentsCsv(
    List<SecretaryRemuneration> records,
  ) async {
    final rows = <String>[
      ['Member', 'Member ID', 'RS', 'Step', 'Amount', 'Status', 'Date']
          .map(_csvCell)
          .join(','),
      ...records.map(
        (record) => [
          record.memberName,
          record.memberId,
          record.secretaryName,
          record.type,
          record.amount.toStringAsFixed(2),
          record.status,
          (record.datePaid ?? record.dateEarned).toIso8601String(),
        ].map(_csvCell).join(','),
      ),
    ];
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(rows.join('\r\n'))),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: ['payments_report_$timestamp.csv'],
        subject: 'Garden Town County Payments Report',
        text: 'Filtered payments report (${records.length} records)',
      ),
    );
  }

  String _stepLabel(int stepNumber) =>
      ref
          .read(remunerationSettingsProvider)
          .valueOrNull
          ?.stepName(stepNumber) ??
      RemunerationSettings.defaults().stepName(stepNumber);

  bool _stepCompleteAt(Member member, int stepNumber) =>
      member.isStepCompleteAt(stepNumber);

  Future<void> _setStep(Member member, int stepNumber, bool complete) async {
    final actor = ref.read(authUserProvider);
    if (actor == null) return;

    setState(() => _busyMemberIds.add(member.id));
    try {
      await ref
          .read(memberLockServiceProvider)
          .setOnboardingStep(
            member: member,
            actor: actor,
            step: stepNumber,
            complete: complete,
          );
      ref.invalidate(membersProvider);
      ref.invalidate(activeOnboardingRemindersProvider);
      ref.invalidate(reminderStatsProvider);
      ref.invalidate(activeReminderCountProvider);
      ref.invalidate(activitiesProvider);
      setState(() => _historyRefreshTick++);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complete
                ? 'Step $stepNumber marked complete for ${member.fullName}'
                : 'Step $stepNumber unchecked for ${member.fullName}',
          ),
          backgroundColor: complete ? Colors.green : Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyMemberIds.remove(member.id));
      }
    }
  }

  Future<bool> _confirmAssistantCredentials(AppUser assistant) async {
    final operator = ref.read(authUserProvider);
    final usernameController = TextEditingController(text: assistant.username);
    final passwordController = TextEditingController();
    var obscurePassword = true;
    var verifying = false;
    String? errorMessage;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> verify() async {
            if (verifying) return;
            setDialogState(() {
              verifying = true;
              errorMessage = null;
            });
            try {
              await ref
                  .read(authServiceProvider)
                  .verifyPaymentAssistantCredentials(
                    assistantId: assistant.id,
                    username: usernameController.text,
                    password: passwordController.text,
                  );
              await ref
                  .read(activityServiceProvider)
                  .record(
                    userName: assistant.displayName,
                    action:
                        '[ACT-PAY-ASSIST-VERIFY-SUCCESS] payment_assistant_verified role ${assistant.userRole.label} for manual payment assistance requested by ${operator?.displayName ?? 'Unknown operator'}',
                    captureGps: false,
                  );
              ref.invalidate(activitiesProvider);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            } catch (error) {
              await ref
                  .read(activityServiceProvider)
                  .record(
                    userName: operator?.displayName ?? 'Unknown operator',
                    action:
                        '[ACT-PAY-ASSIST-VERIFY-FAILED] payment_assistant_verification_failed for ${assistant.displayName} role ${assistant.userRole.label} during manual payment assistance',
                    captureGps: false,
                  );
              ref.invalidate(activitiesProvider);
              if (dialogContext.mounted) {
                setDialogState(() {
                  errorMessage = error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  );
                  verifying = false;
                  passwordController.clear();
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Confirm Payment Assistant'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${assistant.displayName} (${assistant.userRole.label})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  enabled: !verifying,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  enabled: !verifying,
                  obscureText: obscurePassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: verifying
                          ? null
                          : () => setDialogState(
                              () => obscurePassword = !obscurePassword,
                            ),
                    ),
                  ),
                  onSubmitted: (_) => verify(),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
            actions: [
              CancelButton(
                onPressed: verifying
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                text: 'Cancel',
              ),
              SubmitButton(
                onPressed: verifying ? null : verify,
                text: 'Verify Assistant',
                isLoading: verifying,
                icon: Icons.verified_user_outlined,
              ),
            ],
          );
        },
      ),
    );

    usernameController.dispose();
    passwordController.dispose();
    return verified ?? false;
  }

  Future<_ManualPaymentRequest?> _showManualPaymentDialog({
    required List<Member> members,
    required Member initialMember,
    required List<AppUser> assistants,
  }) async {
    final settings = await ref.read(remunerationServiceProvider).getSettings();

    double amountForStep(int step) => settings.stepAmount(step);

    var selectedMemberId = initialMember.id;
    String? selectedSecretaryId;
    String? verifiedSecretaryId;
    var selectedStep = widget.stepNumber;
    var selectedDate = DateTime.now();
    var selectedTime = TimeOfDay.now();
    final receiptController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<_ManualPaymentRequest>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedMember = members.firstWhere(
              (m) => m.id == selectedMemberId,
              orElse: () => initialMember,
            );
            final selectedSecretary = selectedSecretaryId == null
                ? null
                : assistants.firstWhere(
                    (assistant) => assistant.id == selectedSecretaryId,
                  );
            final amount = amountForStep(selectedStep);

            return AlertDialog(
              title: const Text('Record Manual Payment (RS Form)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedStep,
                      decoration: const InputDecoration(
                        labelText: 'Step',
                        border: OutlineInputBorder(),
                      ),
                      items: settings.configuredSteps
                          .map(
                            (step) => DropdownMenuItem<int>(
                              value: step.number,
                              child: Text(step.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedStep = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedMemberId,
                      decoration: const InputDecoration(
                        labelText: 'Member',
                        border: OutlineInputBorder(),
                      ),
                      items: members
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(m.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final member = members.firstWhere((m) => m.id == value);
                        setDialogState(() {
                          selectedMemberId = value;
                          selectedSecretaryId = null;
                          verifiedSecretaryId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedSecretaryId,
                      decoration: const InputDecoration(
                        labelText: 'Admin / Recording Secretary',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select Admin or Recording Secretary'),
                      items: assistants
                          .map(
                            (assistant) => DropdownMenuItem<String>(
                              value: assistant.id,
                              child: Text(
                                '${assistant.displayName} (${assistant.userRole.label})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        final assistant = assistants.firstWhere(
                          (item) => item.id == value,
                        );
                        setDialogState(() {
                          selectedSecretaryId = null;
                          verifiedSecretaryId = null;
                        });
                        final verified = await _confirmAssistantCredentials(
                          assistant,
                        );
                        if (!context.mounted) return;
                        setDialogState(() {
                          selectedSecretaryId = verified ? assistant.id : null;
                          verifiedSecretaryId = verified ? assistant.id : null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Please enter Bank receipt Date and Time, below.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(
                        '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Time'),
                      subtitle: Text(selectedTime.format(context)),
                      trailing: const Icon(Icons.access_time_outlined),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: receiptController,
                      decoration: const InputDecoration(
                        labelText: 'Receipt No.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Amount (auto): R ${amount.toStringAsFixed(2)}\nMember: ${selectedMember.fullName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CancelButton(
                  onPressed: () => Navigator.pop(context),
                  text: 'Cancel',
                ),
                SaveButton(
                  onPressed: () {
                    if (selectedSecretary == null ||
                        verifiedSecretaryId != selectedSecretary.id) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A verified Admin or Recording Secretary login is required.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final receipt = receiptController.text.trim();
                    if (receipt.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt number is required.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final paymentDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    Navigator.pop(
                      context,
                      _ManualPaymentRequest(
                        memberId: selectedMemberId,
                        secretaryId: selectedSecretary.id,
                        secretaryName: selectedSecretary.displayName,
                        stepNumber: selectedStep,
                        paymentDateTime: paymentDateTime,
                        receiptNumber: receipt,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ),
                    );
                  },
                  text: 'Save Payment',
                ),
              ],
            );
          },
        );
      },
    );

    receiptController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _recordManualPayment({
    required Member member,
    required List<Member> members,
  }) async {
    final actor = ref.read(authUserProvider);
    if (actor == null) return;

    final users = await ref.read(databaseServiceProvider).getAppUsers();
    final assistants =
        users
            .where(
              (user) =>
                  (user.isAdmin || user.isSecretary) &&
                  user.active &&
                  !user.deleted,
            )
            .toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
    if (assistants.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add an active Admin or Recording Secretary before recording a manual payment.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final request = await _showManualPaymentDialog(
      members: members,
      initialMember: member,
      assistants: assistants,
    );
    if (request == null) return;

    final selectedMember = members.firstWhere(
      (m) => m.id == request.memberId,
      orElse: () => member,
    );

    try {
      await _validatePaymentSequence(selectedMember, request.stepNumber);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('StateError: ', '')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _busyMemberIds.add(selectedMember.id));
    try {
      final record = await ref
          .read(remunerationServiceProvider)
          .recordManualPayment(
            memberId: selectedMember.id,
            memberName: selectedMember.fullName,
            secretaryId: request.secretaryId,
            secretaryName: request.secretaryName,
            stepNumber: request.stepNumber,
            paymentDateTime: request.paymentDateTime,
            receiptNumber: request.receiptNumber,
            notes: request.notes,
            paymentReference: 'RS-Manual-Form',
          );

      await _setStep(selectedMember, request.stepNumber, true);
      setState(() => _historyRefreshTick++);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Manual payment saved: R ${record.amount.toStringAsFixed(2)} for ${selectedMember.fullName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyMemberIds.remove(selectedMember.id));
      }
    }
  }

  Future<void> _validatePaymentSequence(Member member, int stepNumber) async {
    final settings = await ref.read(remunerationServiceProvider).getSettings();
    final configured = settings.configuredSteps;
    final index = configured.indexWhere((step) => step.number == stepNumber);
    if (index <= 0) return;
    final previousStep = configured[index - 1].number;
    final previousComplete = _stepCompleteAt(member, previousStep);
    final previousPaid = await ref
        .read(remunerationServiceProvider)
        .hasPaidStepPayment(memberId: member.id, stepNumber: previousStep);
    if (!previousComplete || !previousPaid) {
      throw StateError(
        '${_stepLabel(previousStep)} must be completed and paid first.',
      );
    }
  }

  Future<_CardPaymentRequest?> _showCardPaymentDialog({
    required List<Member> members,
    required Member initialMember,
  }) async {
    final settings = await ref.read(remunerationServiceProvider).getSettings();
    var selectedMemberId = initialMember.id;
    var selectedStep = widget.stepNumber;

    double amountForStep(int step) => settings.stepAmount(step);

    if (!mounted) return null;
    return showDialog<_CardPaymentRequest>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedMember = members.firstWhere(
            (member) => member.id == selectedMemberId,
            orElse: () => initialMember,
          );
          final amount = amountForStep(selectedStep);
          final configured = ref.read(cardPaymentGatewayProvider).isConfigured;
          return AlertDialog(
            title: const Text('Card Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedStep,
                    decoration: const InputDecoration(
                      labelText: 'Payment step',
                      border: OutlineInputBorder(),
                    ),
                    items: settings.configuredSteps
                        .map(
                          (step) => DropdownMenuItem<int>(
                            value: step.number,
                            child: Text(step.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStep = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMemberId,
                    decoration: const InputDecoration(
                      labelText: 'Member',
                      border: OutlineInputBorder(),
                    ),
                    items: members
                        .map(
                          (member) => DropdownMenuItem<String>(
                            value: member.id,
                            child: Text(member.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedMemberId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${selectedMember.fullName}\n${settings.stepName(selectedStep)}\nAmount: R ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    configured
                        ? 'Card details are handled securely by the configured payment provider and are never stored in this app.'
                        : 'Card gateway setup is required before a payment can be processed.',
                    style: TextStyle(
                      color: configured
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              CancelButton(
                onPressed: () => Navigator.pop(context),
                text: 'Cancel',
              ),
              SubmitButton(
                onPressed: configured
                    ? () => Navigator.pop(
                        context,
                        _CardPaymentRequest(
                          memberId: selectedMemberId,
                          stepNumber: selectedStep,
                        ),
                      )
                    : null,
                text: 'Process Card Payment',
                icon: Icons.credit_card,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _recordCardPayment({
    required Member member,
    required List<Member> members,
  }) async {
    final actor = ref.read(authUserProvider);
    if (actor == null) return;
    final request = await _showCardPaymentDialog(
      members: members,
      initialMember: member,
    );
    if (request == null) return;
    final selectedMember = members.firstWhere(
      (item) => item.id == request.memberId,
      orElse: () => member,
    );
    final secretaryId = selectedMember.assignedSecretaryId?.trim() ?? '';
    if (secretaryId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign a Recording Secretary to this member first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _busyMemberIds.add(selectedMember.id));
    try {
      await _validatePaymentSequence(selectedMember, request.stepNumber);
      final amount = await ref
          .read(remunerationServiceProvider)
          .getStepAmount(request.stepNumber);
      await ref
          .read(activityServiceProvider)
          .record(
            userName: actor.displayName,
            action:
                '[ACT-PAY-CARD-INIT] card_payment_initiated step ${request.stepNumber} for ${selectedMember.fullName} amount R ${amount.toStringAsFixed(2)}',
            captureGps: false,
          );
      final result = await ref
          .read(cardPaymentGatewayProvider)
          .authorize(
            memberId: selectedMember.id,
            memberName: selectedMember.fullName,
            stepNumber: request.stepNumber,
            amount: amount,
            requestedBy: actor.displayName,
          );
      final record = await ref
          .read(remunerationServiceProvider)
          .recordCardPayment(
            memberId: selectedMember.id,
            memberName: selectedMember.fullName,
            secretaryId: secretaryId,
            stepNumber: request.stepNumber,
            paymentDateTime: DateTime.now(),
            receiptNumber: result.receiptNumber,
            transactionId: result.transactionId,
            gateway: result.gateway,
            actorName: actor.displayName,
          );
      await _setStep(selectedMember, request.stepNumber, true);
      ref.invalidate(activitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Card payment approved: R ${record.amount.toStringAsFixed(2)} · ${result.transactionId}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      await ref
          .read(activityServiceProvider)
          .record(
            userName: actor.displayName,
            action:
                '[ACT-PAY-CARD-FAILED] card_payment_failed step ${request.stepNumber} for ${selectedMember.fullName}: ${error.toString()}',
            captureGps: false,
          );
      ref.invalidate(activitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('StateError: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyMemberIds.remove(selectedMember.id));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _summaryField(
    String text, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: fontSize + 5,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _paymentsSummary({
    required List<Member> members,
    required List<SecretaryRemuneration> records,
    required Map<String, List<MemberFile>> filesByMember,
    required RemunerationSettings settings,
    required bool isAdmin,
    required List<AppUser> secretaries,
  }) {
    final steps = settings.configuredSteps.take(5).toList(growable: false);
    final stepTotals = <int, double>{};
    final memberCounts = <int, int>{};
    final memberById = {for (final member in members) member.id: member};

    bool hasStepPdf(String memberId, int stepNumber, String stepName) {
      final stepPattern = RegExp(
        '(^|[^0-9])step[_ -]*$stepNumber([^0-9]|\$)',
        caseSensitive: false,
      );
      final normalizedName = stepName.toLowerCase().replaceAll('_', ' ');
      return (filesByMember[memberId] ?? const <MemberFile>[]).any((file) {
        final isPdf =
            file.contentType.toLowerCase() == 'application/pdf' ||
            file.fileName.toLowerCase().endsWith('.pdf');
        final searchable = '${file.fileName} ${file.description}'.toLowerCase();
        return isPdf &&
            (stepPattern.hasMatch(searchable) ||
                searchable.contains(normalizedName));
      });
    }

    for (final step in steps) {
      final completedRecords = records
          .where(
            (record) =>
                !record.isDeleted &&
                record.status == 'paid' &&
                record.type == 'step${step.number}' &&
                (memberById[record.memberId]?.isStepCompleteAt(step.number) ??
                    false) &&
                (step.number == 5 ||
                    hasStepPdf(record.memberId, step.number, step.name)),
          )
          .toList(growable: false);
      final memberCount = completedRecords
          .map((record) => record.memberId)
          .toSet()
          .length;
      memberCounts[step.number] = memberCount;
      stepTotals[step.number] = memberCount * step.amount;
    }

    final totalAmount = stepTotals.values.fold<double>(0, (a, b) => a + b);
    final totalMembers = memberCounts.values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Payments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _paymentSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Search member information',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickFilterDate(start: true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _startDate == null
                            ? 'Start Date'
                            : DateFormat('yyyy-MM-dd').format(_startDate!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickFilterDate(start: false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _endDate == null
                            ? 'End Date'
                            : DateFormat('yyyy-MM-dd').format(_endDate!),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const Spacer(),
                  ActionButton(
                    onPressed: () {
                      ref.invalidate(membersProvider);
                      ref.invalidate(remunerationSettingsProvider);
                      setState(() => _historyRefreshTick++);
                    },
                    text: 'Refresh',
                    icon: Icons.refresh,
                  ),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<bool>(
                        key: ValueKey('payment-filter-$_viewBySecretary'),
                        initialValue: _viewBySecretary,
                        decoration: const InputDecoration(
                          labelText: 'Filter',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: false,
                            child: Text('View All'),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text('View RS'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _viewBySecretary = value ?? false;
                          if (!_viewBySecretary) {
                            _selectedSecretaryId = null;
                          }
                        }),
                      ),
                    ),
                    if (_viewBySecretary)
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'payment-secretary-${_selectedSecretaryId ?? 'none'}',
                          ),
                          initialValue: _selectedSecretaryId,
                          decoration: const InputDecoration(
                            labelText: 'Select RS',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: secretaries
                              .map(
                                (secretary) => DropdownMenuItem(
                                  value: secretary.id,
                                  child: Text(secretary.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedSecretaryId = value),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _startDate == null &&
                              _endDate == null &&
                              _paymentSearchController.text.isEmpty &&
                              !_viewBySecretary
                          ? null
                          : () => setState(() {
                              _startDate = null;
                              _endDate = null;
                              _viewBySecretary = false;
                              _selectedSecretaryId = null;
                              _paymentSearchController.clear();
                            }),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear'),
                    ),
                    ActionButton(
                      onPressed: records.isEmpty
                          ? null
                          : () => _exportPaymentsCsv(records),
                      text: 'Export CSV',
                      icon: Icons.download_outlined,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _summaryField(
                              steps[index].name,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            _summaryField(
                              'RS Amount: R ${(stepTotals[steps[index].number] ?? 0).toStringAsFixed(2)}',
                              fontSize: 12,
                            ),
                            _summaryField(
                              'Total Members: ${memberCounts[steps[index].number] ?? 0}',
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: 16),
              _summaryField(
                'Total RS Amount: R ${totalAmount.toStringAsFixed(2)}   |   Total Members: $totalMembers',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyPanel(List<SecretaryRemuneration> sourceRecords) {
    final records = sourceRecords.toList()
      ..sort((a, b) => b.dateEarned.compareTo(a.dateEarned));

    final total = records.fold<double>(0, (sum, r) => sum + r.amount);

    return Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text('Payment History · ${records.length} record(s)'),
            subtitle: Text('Total: R ${total.toStringAsFixed(2)}'),
            children: [
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No payment records yet.'),
                  ),
                )
              else
                ...records.take(50).map((record) {
                  final description = record.description.toLowerCase();
                  final isManual = description.contains('manual payment');
                  final isCard = description.contains('card payment');
                  final earned = record.dateEarned.toLocal();
                  final paid = record.datePaid?.toLocal();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isCard
                          ? Icons.credit_card
                          : (isManual
                                ? Icons.payments_outlined
                                : Icons.auto_graph),
                      color: isCard
                          ? Colors.blue
                          : (isManual ? Colors.deepPurple : Colors.teal),
                    ),
                    title: Text(
                      '${record.memberName.isEmpty ? record.memberId : record.memberName} · R ${record.amount.toStringAsFixed(2)}',
                    ),
                    subtitle: Text(
                      '${record.secretaryName.isEmpty ? record.secretaryId : record.secretaryName} · ${earned.toString().substring(0, 16)}'
                      '${paid != null ? ' · paid ${paid.toString().substring(0, 16)}' : ''}',
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            isCard
                                ? 'Card'
                                : (isManual ? 'Manual' : 'Integrated'),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _statusColor(
                            record.status,
                          ).withValues(alpha: 0.15),
                          label: Text(
                            record.status,
                            style: TextStyle(
                              color: _statusColor(record.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authUserProvider);
    final isAdmin = actor?.isAdmin == true || actor?.isSystemAdministrator == true;
    final membersAsync = ref.watch(membersProvider);
    final remunerationSettings =
        ref.watch(remunerationSettingsProvider).valueOrNull ??
        RemunerationSettings.defaults();

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Could not load members: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (members) {
        return FutureBuilder<_PaymentScreenData>(
          key: ValueKey('step-gates-${widget.stepNumber}-$_historyRefreshTick'),
          future: _paymentDataFor(members, isAdmin: isAdmin),
          builder: (context, paySnapshot) {
            final allRecords =
                paySnapshot.data?.records ?? const <SecretaryRemuneration>[];
            final filesByMember =
                paySnapshot.data?.filesByMember ??
                const <String, List<MemberFile>>{};
            final secretaries =
              paySnapshot.data?.secretaries ?? const <AppUser>[];
            final memberById = {
              for (final member in members) member.id: member,
            };
            final visibleMemberIds = memberById.keys.toSet();
            final authorizedRecords = allRecords.where((record) {
              if (record.isDeleted) return false;
              return isAdmin || visibleMemberIds.contains(record.memberId);
            }).toList(growable: false);

            bool hasPaidStep(Member member, int stepNumber) {
              final type = 'step$stepNumber';
              return authorizedRecords.any(
                (r) =>
                    !r.isDeleted &&
                    r.memberId == member.id &&
                    r.type == type &&
                    r.status == 'paid',
              );
            }

            bool previousStepReady(Member member) {
              final index = remunerationSettings.configuredSteps.indexWhere(
                (step) => step.number == widget.stepNumber,
              );
              if (index <= 0) return true;
              final previous =
                  remunerationSettings.configuredSteps[index - 1].number;
              return _stepCompleteAt(member, previous) &&
                  hasPaidStep(member, previous);
            }

            final query = _paymentSearchController.text.trim().toLowerCase();
            var filteredMembers = members.where((member) {
              if (isAdmin &&
                  _viewBySecretary &&
                  member.assignedSecretaryId != _selectedSecretaryId) {
                return false;
              }
              return !isAdmin || _matchesMemberSearch(member, query);
            }).toList(growable: false);
            final filteredRecords = authorizedRecords
                .where((record) {
                  if (!isAdmin) return true;
                  final member = memberById[record.memberId];
                  if (_viewBySecretary) {
                    final secretaryId = _selectedSecretaryId;
                    if (secretaryId == null ||
                        member?.assignedSecretaryId != secretaryId) {
                      return false;
                    }
                  }
                  return _matchesPaymentSearch(record, member, query) &&
                      _recordInDateRange(record);
                })
                .toList(growable: false);
            if (isAdmin && (_startDate != null || _endDate != null)) {
              final membersWithPayments = filteredRecords
                  .map((record) => record.memberId)
                  .toSet();
              filteredMembers = filteredMembers
                  .where((member) => membersWithPayments.contains(member.id))
                  .toList(growable: false);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _paymentsSummary(
                  members: filteredMembers,
                  records: filteredRecords,
                  filesByMember: filesByMember,
                  settings: remunerationSettings,
                  isAdmin: isAdmin,
                  secretaries: secretaries,
                ),
                _historyPanel(filteredRecords),
                Expanded(
                  child: filteredMembers.isEmpty
                      ? Center(
                          child: Text(
                            members.isEmpty
                                ? 'No members available for payment.'
                                : 'No members are unlocked for this step yet.\nComplete and pay the previous step first.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = filteredMembers[index];
                            final busy = _busyMemberIds.contains(member.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('SA ID: ${member.saId}'),
                                    Text(
                                      'Assigned RS: ${member.assignedSecretaryName?.trim().isNotEmpty == true ? member.assignedSecretaryName : 'Not assigned'}',
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: remunerationSettings
                                          .configuredSteps
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final configuredStep = entry.value;
                                            final step = configuredStep.number;
                                            final completed = _stepCompleteAt(
                                              member,
                                              step,
                                            );
                                            final paid = hasPaidStep(
                                              member,
                                              step,
                                            );
                                            final previous = entry.key == 0
                                                ? null
                                                : remunerationSettings
                                                      .configuredSteps[entry
                                                              .key -
                                                          1]
                                                      .number;
                                            final unlocked =
                                                previous == null ||
                                                (_stepCompleteAt(
                                                      member,
                                                      previous,
                                                    ) &&
                                                    hasPaidStep(
                                                      member,
                                                      previous,
                                                    ));
                                            return Chip(
                                              avatar: Icon(
                                                completed
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                size: 18,
                                                color: completed
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                                semanticLabel: completed
                                                    ? 'Completed'
                                                    : 'Not completed',
                                              ),
                                              label: Text(
                                                '${configuredStep.name} · ${completed ? 'Completed' : 'Not Completed'} · R ${configuredStep.amount.toStringAsFixed(2)} · ${paid ? 'Paid' : (unlocked ? 'Pending · Due' : 'Pending · Locked')}',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                              backgroundColor: completed
                                                  ? Colors.green.shade100
                                                  : Colors.red.shade50,
                                            );
                                          })
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Total: R ${remunerationSettings.configuredTotalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ActionButton(
                                          onPressed: busy
                                              ? null
                                              : () => _recordManualPayment(
                                                  member: member,
                                                  members: filteredMembers,
                                                ),
                                          text: 'Manual Payment',
                                          icon: Icons.payments_outlined,
                                          backgroundColor:
                                              AppButtonColors.editBg,
                                          foregroundColor: Colors.black,
                                          borderColor:
                                              AppButtonColors.blackRing,
                                        ),
                                        ActionButton(
                                          onPressed: busy
                                              ? null
                                              : () => _recordCardPayment(
                                                  member: member,
                                                  members: filteredMembers,
                                                ),
                                          text: 'Card Payment',
                                          icon: Icons.credit_card,
                                          foregroundColor: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
