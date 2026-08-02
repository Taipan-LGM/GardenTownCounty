import '../models/remuneration_settings.dart';
import '../models/secretary_remuneration.dart';
import 'activity_service.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';

/// RS remuneration settings, earnings, approve/pay, dashboard.
///
/// // NEW ADDITION - Delete this file to revert remuneration service.
class RemunerationService {
  RemunerationService(
    this._db, {
    ReminderNotificationService? notifications,
    ActivityService? activity,
  }) : _notifications = notifications,
       _activity = activity;

  final DatabaseService _db;
  final ReminderNotificationService? _notifications;
  final ActivityService? _activity;

  static const String _idInAppStepRecorded = 'ACT-PAY-INAPP-STEP';
  static const String _idManualPaymentConfirmed = 'ACT-PAY-MANUAL-CONFIRM';
  static const String _idManualPaymentCreated = 'ACT-PAY-MANUAL-CREATE';
  static const String _idCardPaymentApproved = 'ACT-PAY-CARD-APPROVED';
  static const String _idRemunerationApproved = 'ACT-PAY-REMUN-APPROVE';
  static const String _idRemunerationPaid = 'ACT-PAY-REMUN-PAID';

  Future<RemunerationSettings> getSettings() => _db.getRemunerationSettings();

  Future<void> saveSettings(RemunerationSettings settings) =>
      _db.saveRemunerationSettings(settings);

  Future<double> getStepAmount(int stepNumber) async {
    final settings = await getSettings();
    final step = settings.configuredSteps
        .where((step) => step.number == stepNumber)
        .firstOrNull;
    if (step == null) throw ArgumentError('Step is not active.');
    return step.amount;
  }

  Future<bool> hasPaidStepPayment({
    required String memberId,
    required int stepNumber,
  }) async {
    if (stepNumber < 1) return false;
    final type = 'step$stepNumber';
    final records = await _db.getAllRemunerationRecords();
    return records.any(
      (r) =>
          !r.isDeleted &&
          r.memberId == memberId &&
          r.type == type &&
          r.status == 'paid',
    );
  }

  /// Create a remuneration record when a step is paid or completed.
  Future<SecretaryRemuneration?> calculateStepRemuneration({
    required String memberId,
    required int stepNumber,
    required String secretaryId,
  }) async {
    final type = 'step$stepNumber';
    if (await _db.hasStepRemuneration(memberId: memberId, type: type)) {
      return null;
    }

    final settings = await getSettings();
    final configuredStep = settings.configuredSteps
        .where((step) => step.number == stepNumber)
        .firstOrNull;
    if (configuredStep == null) return null;
    final amount = configuredStep.amount;
    final description = '${settings.stepName(stepNumber)} Completion';

    final member = await _db.getMemberById(memberId);
    final users = await _db.getAppUsers();
    String secretaryName = '';
    for (final u in users) {
      if (u.id == secretaryId) {
        secretaryName = u.displayName;
        break;
      }
    }

    final record = SecretaryRemuneration.create(
      secretaryId: secretaryId,
      secretaryName: secretaryName,
      memberId: memberId,
      memberName: member?.fullName ?? '',
      type: type,
      description: description,
      amount: amount,
    );
    await _db.saveRemuneration(record);
    await _activity?.record(
      userName: 'System',
      action:
          '[$_idInAppStepRecorded] 💰 ${settings.stepName(stepNumber)} recorded for ${member?.fullName ?? memberId} amount R ${amount.toStringAsFixed(2)}',
      captureGps: false,
    );

    await _notifications?.notifyRemunerationEarned(
      secretaryId: secretaryId,
      amount: amount,
      description: description,
      memberName: member?.fullName ?? memberId,
    );

    return record;
  }

  Future<SecretaryRemuneration> recordManualPayment({
    required String memberId,
    required String memberName,
    required String secretaryId,
    String secretaryName = '',
    required int stepNumber,
    required DateTime paymentDateTime,
    required String receiptNumber,
    String? notes,
    String? paymentReference,
  }) async {
    final type = 'step$stepNumber';
    final settings = await getSettings();
    final configuredStep = settings.configuredSteps
        .where((step) => step.number == stepNumber)
        .firstOrNull;
    if (configuredStep == null) throw ArgumentError('Step is not active.');
    final existing = await _db.hasStepRemuneration(
      memberId: memberId,
      type: type,
    );
    if (existing) {
      final existingRecords = await _db.getAllRemunerationRecords();
      final record = existingRecords.firstWhere(
        (item) =>
            item.memberId == memberId && item.type == type && !item.isDeleted,
        orElse: () => throw StateError('Remuneration record not found.'),
      );
      if (record.status == 'paid') {
        return record;
      }

      final updated = record.copyWith(
        secretaryId: secretaryId,
        secretaryName: secretaryName,
        status: 'paid',
        datePaid: paymentDateTime.toUtc(),
        notes: [
          'receiptNo=$receiptNumber',
          'manualPaidAt=${paymentDateTime.toUtc().toIso8601String()}',
          if (notes != null && notes.isNotEmpty) notes,
          if (paymentReference != null && paymentReference.isNotEmpty)
            'reference=$paymentReference',
        ].join(' | '),
        syncStatus: 'pending',
      );
      await _db.updateRemuneration(updated);
      await _activity?.record(
        userName: 'System',
        action:
            '[$_idManualPaymentConfirmed] 💳 manual payment for ${settings.stepName(stepNumber)} confirmed for $memberName assisted by ${secretaryName.isEmpty ? secretaryId : secretaryName} receipt $receiptNumber',
        captureGps: false,
      );
      return updated;
    }

    final amount = configuredStep.amount;
    final description = 'Manual payment - ${settings.stepName(stepNumber)}';

    final record =
        SecretaryRemuneration.create(
          secretaryId: secretaryId,
          secretaryName: secretaryName,
          memberId: memberId,
          memberName: memberName,
          type: type,
          description: description,
          amount: amount,
        ).copyWith(
          status: 'paid',
          datePaid: paymentDateTime.toUtc(),
          notes: [
            'receiptNo=$receiptNumber',
            'manualPaidAt=${paymentDateTime.toUtc().toIso8601String()}',
            if (notes != null && notes.isNotEmpty) notes,
            if (paymentReference != null && paymentReference.isNotEmpty)
              'reference=$paymentReference',
          ].join(' | '),
          syncStatus: 'pending',
        );

    await _db.saveRemuneration(record);
    await _activity?.record(
      userName: 'System',
      action:
          '[$_idManualPaymentCreated] 💳 manual payment for ${settings.stepName(stepNumber)} and $memberName assisted by ${secretaryName.isEmpty ? secretaryId : secretaryName} ($secretaryId) receipt $receiptNumber',
      captureGps: false,
    );
    return record;
  }

  Future<SecretaryRemuneration> recordCardPayment({
    required String memberId,
    required String memberName,
    required String secretaryId,
    required int stepNumber,
    required DateTime paymentDateTime,
    required String receiptNumber,
    required String transactionId,
    required String gateway,
    required String actorName,
  }) async {
    final type = 'step$stepNumber';
    final settings = await getSettings();
    final configuredStep = settings.configuredSteps
        .where((step) => step.number == stepNumber)
        .firstOrNull;
    if (configuredStep == null) throw ArgumentError('Step is not active.');
    final amount = configuredStep.amount;
    final records = await _db.getAllRemunerationRecords();
    SecretaryRemuneration? existing;
    for (final item in records) {
      if (!item.isDeleted && item.memberId == memberId && item.type == type) {
        existing = item;
        break;
      }
    }

    final notes = [
      'paymentMethod=card',
      'gateway=$gateway',
      'transactionId=$transactionId',
      'receiptNo=$receiptNumber',
      'cardPaidAt=${paymentDateTime.toUtc().toIso8601String()}',
    ].join(' | ');

    late final SecretaryRemuneration paidRecord;
    if (existing != null) {
      if (existing.status == 'paid') return existing;
      paidRecord = existing.copyWith(
        status: 'paid',
        datePaid: paymentDateTime.toUtc(),
        paidBy: actorName,
        notes: notes,
        syncStatus: 'pending',
      );
      await _db.updateRemuneration(paidRecord);
    } else {
      final description = 'Card payment - ${settings.stepName(stepNumber)}';
      paidRecord =
          SecretaryRemuneration.create(
            secretaryId: secretaryId,
            secretaryName: '',
            memberId: memberId,
            memberName: memberName,
            type: type,
            description: description,
            amount: amount,
          ).copyWith(
            status: 'paid',
            datePaid: paymentDateTime.toUtc(),
            paidBy: actorName,
            notes: notes,
            syncStatus: 'pending',
          );
      await _db.saveRemuneration(paidRecord);
    }

    await _activity?.record(
      userName: actorName,
      action:
          '[$_idCardPaymentApproved] card payment approved for ${settings.stepName(stepNumber)} and $memberName amount R ${amount.toStringAsFixed(2)} gateway $gateway transaction $transactionId receipt $receiptNumber',
      captureGps: false,
    );
    return paidRecord;
  }

  Future<SecretaryRemunerationSummary> getSecretarySummary(
    String secretaryId,
  ) async {
    final records = await _db.getSecretaryRemuneration(secretaryId);
    var totalEarned = 0.0;
    var pendingAmount = 0.0;
    var paidAmount = 0.0;
    for (final record in records) {
      totalEarned += record.amount;
      if (record.status == 'pending') pendingAmount += record.amount;
      if (record.status == 'paid') paidAmount += record.amount;
    }
    return SecretaryRemunerationSummary(
      totalEarned: totalEarned,
      pendingAmount: pendingAmount,
      paidAmount: paidAmount,
      recordCount: records.length,
      records: records,
    );
  }

  Future<void> approveRemuneration(
    String remunerationId,
    String adminId,
  ) async {
    final record = await _db.getRemuneration(remunerationId);
    if (record == null) return;
    final updated = record.copyWith(
      status: 'approved',
      dateApproved: DateTime.now().toUtc(),
      approvedBy: adminId,
      syncStatus: 'pending',
    );
    await _db.updateRemuneration(updated);
    await _activity?.record(
      userName: adminId,
      action:
          '[$_idRemunerationApproved] ✅ remuneration_approved ${record.memberName.isEmpty ? record.memberId : record.memberName} ${record.type} R ${record.amount.toStringAsFixed(2)}',
      captureGps: false,
    );
    await _notifications?.notifyRemunerationApproved(
      secretaryId: record.secretaryId,
      amount: record.amount,
      description: record.description,
    );
  }

  Future<void> payRemuneration(String remunerationId, String adminId) async {
    final record = await _db.getRemuneration(remunerationId);
    if (record == null) return;
    final updated = record.copyWith(
      status: 'paid',
      datePaid: DateTime.now().toUtc(),
      paidBy: adminId,
      syncStatus: 'pending',
    );
    await _db.updateRemuneration(updated);
    await _activity?.record(
      userName: adminId,
      action:
          '[$_idRemunerationPaid] 💵 remuneration_paid ${record.memberName.isEmpty ? record.memberId : record.memberName} ${record.type} R ${record.amount.toStringAsFixed(2)}',
      captureGps: false,
    );
    await _notifications?.notifyRemunerationPaid(
      secretaryId: record.secretaryId,
      amount: record.amount,
      description: record.description,
    );
  }

  Future<RemunerationDashboard> getDashboardData() async {
    final allRecords = await _db.getAllRemunerationRecords();
    final settings = await getSettings();

    final totalPaid = allRecords
        .where((r) => r.status == 'paid')
        .fold(0.0, (sum, r) => sum + r.amount);
    final totalPending = allRecords
        .where((r) => r.status == 'pending')
        .fold(0.0, (sum, r) => sum + r.amount);
    final totalApproved = allRecords
        .where((r) => r.status == 'approved')
        .fold(0.0, (sum, r) => sum + r.amount);

    final secretaryTotals = <String, double>{};
    final secretaryNames = <String, String>{};
    for (final record in allRecords) {
      secretaryTotals[record.secretaryId] =
          (secretaryTotals[record.secretaryId] ?? 0) + record.amount;
      if (record.secretaryName.isNotEmpty) {
        secretaryNames[record.secretaryId] = record.secretaryName;
      }
    }

    return RemunerationDashboard(
      totalPaid: totalPaid,
      totalPending: totalPending,
      totalApproved: totalApproved,
      totalRecords: allRecords.length,
      secretaryTotals: secretaryTotals,
      secretaryNames: secretaryNames,
      settings: settings,
    );
  }
}
