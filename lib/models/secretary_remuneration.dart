import 'package:uuid/uuid.dart';

import 'remuneration_settings.dart';

/// Single RS earning record (step completion or extra service).
///
/// // NEW ADDITION - Delete this file to revert RS remuneration records model.
class SecretaryRemuneration {
  final String id;
  final String? firestoreId;
  final String secretaryId;
  final String secretaryName;
  final String memberId;
  final String memberName;

  /// `step2` | `step3` | `step4` | `extra`
  final String type;
  final String description;
  final double amount;
  final String? extraServiceId;

  /// `pending` | `approved` | `paid`
  final String status;
  final DateTime dateEarned;
  final DateTime? dateApproved;
  final DateTime? datePaid;
  final String? notes;
  final String? approvedBy;
  final String? paidBy;
  final String syncStatus;
  final bool isDeleted;

  const SecretaryRemuneration({
    required this.id,
    this.firestoreId,
    required this.secretaryId,
    this.secretaryName = '',
    required this.memberId,
    this.memberName = '',
    required this.type,
    required this.description,
    required this.amount,
    this.extraServiceId,
    this.status = 'pending',
    required this.dateEarned,
    this.dateApproved,
    this.datePaid,
    this.notes,
    this.approvedBy,
    this.paidBy,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  factory SecretaryRemuneration.create({
    required String secretaryId,
    required String secretaryName,
    required String memberId,
    required String memberName,
    required String type,
    required String description,
    required double amount,
    String? extraServiceId,
  }) {
    return SecretaryRemuneration(
      id: const Uuid().v4(),
      secretaryId: secretaryId,
      secretaryName: secretaryName,
      memberId: memberId,
      memberName: memberName,
      type: type,
      description: description,
      amount: amount,
      extraServiceId: extraServiceId,
      status: 'pending',
      dateEarned: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );
  }

  SecretaryRemuneration copyWith({
    String? id,
    String? firestoreId,
    String? secretaryId,
    String? secretaryName,
    String? memberId,
    String? memberName,
    String? type,
    String? description,
    double? amount,
    String? extraServiceId,
    String? status,
    DateTime? dateEarned,
    DateTime? dateApproved,
    DateTime? datePaid,
    String? notes,
    String? approvedBy,
    String? paidBy,
    String? syncStatus,
    bool? isDeleted,
  }) {
    return SecretaryRemuneration(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      secretaryId: secretaryId ?? this.secretaryId,
      secretaryName: secretaryName ?? this.secretaryName,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      type: type ?? this.type,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      extraServiceId: extraServiceId ?? this.extraServiceId,
      status: status ?? this.status,
      dateEarned: dateEarned ?? this.dateEarned,
      dateApproved: dateApproved ?? this.dateApproved,
      datePaid: datePaid ?? this.datePaid,
      notes: notes ?? this.notes,
      approvedBy: approvedBy ?? this.approvedBy,
      paidBy: paidBy ?? this.paidBy,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'secretaryId': secretaryId,
        'secretaryName': secretaryName,
        'memberId': memberId,
        'memberName': memberName,
        'type': type,
        'description': description,
        'amount': amount,
        'extraServiceId': extraServiceId,
        'status': status,
        'dateEarned': dateEarned.toIso8601String(),
        'dateApproved': dateApproved?.toIso8601String(),
        'datePaid': datePaid?.toIso8601String(),
        'notes': notes,
        'approvedBy': approvedBy,
        'paidBy': paidBy,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
      };

  factory SecretaryRemuneration.fromMap(Map<String, dynamic> map) {
    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v == 1;
      return false;
    }

    DateTime? asDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toUtc();
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
      return null;
    }

    return SecretaryRemuneration(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      secretaryId: map['secretaryId'] as String? ?? '',
      secretaryName: map['secretaryName'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      type: map['type'] as String? ?? '',
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      extraServiceId: map['extraServiceId'] as String?,
      status: map['status'] as String? ?? 'pending',
      dateEarned: asDate(map['dateEarned']) ?? DateTime.now().toUtc(),
      dateApproved: asDate(map['dateApproved']),
      datePaid: asDate(map['datePaid']),
      notes: map['notes'] as String?,
      approvedBy: map['approvedBy'] as String?,
      paidBy: map['paidBy'] as String?,
      syncStatus: map['syncStatus'] as String? ?? 'pending',
      isDeleted: asBool(map['isDeleted']),
    );
  }
}

/// Summary totals for one secretary.
///
/// // NEW ADDITION - Delete with secretary_remuneration.dart to revert.
class SecretaryRemunerationSummary {
  final double totalEarned;
  final double pendingAmount;
  final double paidAmount;
  final int recordCount;
  final List<SecretaryRemuneration> records;

  const SecretaryRemunerationSummary({
    required this.totalEarned,
    required this.pendingAmount,
    required this.paidAmount,
    required this.recordCount,
    required this.records,
  });
}

/// Admin dashboard rollup.
///
/// // NEW ADDITION - Delete with secretary_remuneration.dart to revert.
class RemunerationDashboard {
  final double totalPaid;
  final double totalPending;
  final double totalApproved;
  final int totalRecords;
  final Map<String, double> secretaryTotals;
  final Map<String, String> secretaryNames;
  final RemunerationSettings? settings;

  const RemunerationDashboard({
    required this.totalPaid,
    required this.totalPending,
    required this.totalApproved,
    required this.totalRecords,
    required this.secretaryTotals,
    this.secretaryNames = const {},
    this.settings,
  });
}
