import '../models/remuneration_settings.dart';
import '../models/secretary_remuneration.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';

/// RS remuneration settings, earnings, approve/pay, dashboard.
///
/// // NEW ADDITION - Delete this file to revert remuneration service.
class RemunerationService {
  RemunerationService(this._db, {ReminderNotificationService? notifications})
      : _notifications = notifications;

  final DatabaseService _db;
  final ReminderNotificationService? _notifications;

  Future<RemunerationSettings> getSettings() => _db.getRemunerationSettings();

  Future<void> saveSettings(RemunerationSettings settings) =>
      _db.saveRemunerationSettings(settings);

  /// Create pending earning when step 2/3/4 completed (idempotent per type).
  Future<SecretaryRemuneration?> calculateStepRemuneration({
    required String memberId,
    required int stepNumber,
    required String secretaryId,
  }) async {
    if (stepNumber < 2 || stepNumber > 4) return null;

    final type = 'step$stepNumber';
    if (await _db.hasStepRemuneration(memberId: memberId, type: type)) {
      return null;
    }

    final settings = await getSettings();
    late final double amount;
    late final String description;
    switch (stepNumber) {
      case 2:
        amount = settings.step2Amount;
        description = 'Global 528 Completion';
      case 3:
        amount = settings.step3Amount;
        description = 'Global 928 Completion';
      case 4:
        amount = settings.step4Amount;
        description = 'LRO Completion';
      default:
        return null;
    }

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

    await _notifications?.notifyRemunerationEarned(
      secretaryId: secretaryId,
      amount: amount,
      description: description,
      memberName: member?.fullName ?? memberId,
    );

    return record;
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
    await _notifications?.notifyRemunerationApproved(
      secretaryId: record.secretaryId,
      amount: record.amount,
      description: record.description,
    );
  }

  Future<void> payRemuneration(
    String remunerationId,
    String adminId,
  ) async {
    final record = await _db.getRemuneration(remunerationId);
    if (record == null) return;
    final updated = record.copyWith(
      status: 'paid',
      datePaid: DateTime.now().toUtc(),
      paidBy: adminId,
      syncStatus: 'pending',
    );
    await _db.updateRemuneration(updated);
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
