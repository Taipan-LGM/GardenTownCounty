import 'package:uuid/uuid.dart';

/// Case product type: Status Correction (528) or Emancipation (928).
enum LroCaseType {
  status528('528', '528 Status Correction'),
  emancipation928('928', '928 Emancipation');

  const LroCaseType(this.code, this.label);
  final String code;
  final String label;

  static LroCaseType fromCode(String? code) {
    switch (code) {
      case '928':
        return LroCaseType.emancipation928;
      default:
        return LroCaseType.status528;
    }
  }
}

/// Workflow: Draft → Submitted → Under Review → Processing → Published / Rejected
enum LroCaseStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  underReview('underReview', 'Under Review'),
  processing('processing', 'Processing'),
  published('published', 'Published'),
  rejected('rejected', 'Rejected');

  const LroCaseStatus(this.code, this.label);
  final String code;
  final String label;

  static LroCaseStatus fromCode(String? code) {
    return LroCaseStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => LroCaseStatus.draft,
    );
  }

  static const workflowOrder = [
    draft,
    submitted,
    underReview,
    processing,
    published,
    rejected,
  ];
}

class LroCase {
  final String id;
  final String? firestoreId;
  final String memberId;
  final String caseType; // 528 | 928
  final String caseNumber;
  final String? recordingNumber;
  final String subjectName;
  final String propertyAddress;
  final String propertySize;
  final String zoningType;
  final String status;
  final DateTime? submissionDate;
  final DateTime? approvalDate;
  final DateTime? publishedDate;
  final String assignedOfficer;
  final double? feeAmount;
  final String notes;
  final String rejectionReason;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const LroCase({
    required this.id,
    this.firestoreId,
    required this.memberId,
    required this.caseType,
    required this.caseNumber,
    this.recordingNumber,
    this.subjectName = '',
    this.propertyAddress = '',
    this.propertySize = '',
    this.zoningType = '',
    this.status = 'draft',
    this.submissionDate,
    this.approvalDate,
    this.publishedDate,
    this.assignedOfficer = '',
    this.feeAmount,
    this.notes = '',
    this.rejectionReason = '',
    this.createdBy = '',
    this.updatedBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  LroCaseType get type => LroCaseType.fromCode(caseType);
  LroCaseStatus get statusEnum => LroCaseStatus.fromCode(status);

  factory LroCase.create({
    required String memberId,
    required LroCaseType type,
    required String caseNumber,
    required String createdBy,
    String subjectName = '',
    String propertyAddress = '',
    String propertySize = '',
    String zoningType = '',
    String assignedOfficer = '',
    double? feeAmount,
    String notes = '',
  }) {
    final now = DateTime.now().toUtc();
    return LroCase(
      id: const Uuid().v4(),
      memberId: memberId,
      caseType: type.code,
      caseNumber: caseNumber,
      subjectName: subjectName,
      propertyAddress: propertyAddress,
      propertySize: propertySize,
      zoningType: zoningType,
      status: LroCaseStatus.draft.code,
      submissionDate: now,
      assignedOfficer: assignedOfficer,
      feeAmount: feeAmount,
      notes: notes,
      createdBy: createdBy,
      updatedBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  LroCase copyWith({
    String? id,
    String? firestoreId,
    String? memberId,
    String? caseType,
    String? caseNumber,
    String? recordingNumber,
    String? subjectName,
    String? propertyAddress,
    String? propertySize,
    String? zoningType,
    String? status,
    DateTime? submissionDate,
    DateTime? approvalDate,
    DateTime? publishedDate,
    String? assignedOfficer,
    double? feeAmount,
    String? notes,
    String? rejectionReason,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool clearRecordingNumber = false,
    bool clearSubmissionDate = false,
    bool clearApprovalDate = false,
    bool clearPublishedDate = false,
    bool clearFeeAmount = false,
  }) {
    return LroCase(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      memberId: memberId ?? this.memberId,
      caseType: caseType ?? this.caseType,
      caseNumber: caseNumber ?? this.caseNumber,
      recordingNumber: clearRecordingNumber
          ? null
          : (recordingNumber ?? this.recordingNumber),
      subjectName: subjectName ?? this.subjectName,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      propertySize: propertySize ?? this.propertySize,
      zoningType: zoningType ?? this.zoningType,
      status: status ?? this.status,
      submissionDate: clearSubmissionDate
          ? null
          : (submissionDate ?? this.submissionDate),
      approvalDate:
          clearApprovalDate ? null : (approvalDate ?? this.approvalDate),
      publishedDate:
          clearPublishedDate ? null : (publishedDate ?? this.publishedDate),
      assignedOfficer: assignedOfficer ?? this.assignedOfficer,
      feeAmount: clearFeeAmount ? null : (feeAmount ?? this.feeAmount),
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'memberId': memberId,
        'caseType': caseType,
        'caseNumber': caseNumber,
        'recordingNumber': recordingNumber,
        'subjectName': subjectName,
        'propertyAddress': propertyAddress,
        'propertySize': propertySize,
        'zoningType': zoningType,
        'status': status,
        'submissionDate': submissionDate?.toIso8601String(),
        'approvalDate': approvalDate?.toIso8601String(),
        'publishedDate': publishedDate?.toIso8601String(),
        'assignedOfficer': assignedOfficer,
        'feeAmount': feeAmount,
        'notes': notes,
        'rejectionReason': rejectionReason,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pendingSync': pendingSync ? 1 : 0,
        'deleted': deleted ? 1 : 0,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'firestoreId': firestoreId ?? id,
        'memberId': memberId,
        'caseType': caseType,
        'caseNumber': caseNumber,
        'recordingNumber': recordingNumber,
        'subjectName': subjectName,
        'propertyAddress': propertyAddress,
        'propertySize': propertySize,
        'zoningType': zoningType,
        'status': status,
        'submissionDate': submissionDate?.toIso8601String(),
        'approvalDate': approvalDate?.toIso8601String(),
        'publishedDate': publishedDate?.toIso8601String(),
        'assignedOfficer': assignedOfficer,
        'feeAmount': feeAmount,
        'notes': notes,
        'rejectionReason': rejectionReason,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory LroCase.fromMap(Map<String, dynamic> map) {
    return LroCase(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      memberId: map['memberId'] as String? ?? '',
      caseType: map['caseType'] as String? ?? '528',
      caseNumber: map['caseNumber'] as String? ?? '',
      recordingNumber: map['recordingNumber'] as String?,
      subjectName: map['subjectName'] as String? ?? '',
      propertyAddress: map['propertyAddress'] as String? ?? '',
      propertySize: map['propertySize'] as String? ?? '',
      zoningType: map['zoningType'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      submissionDate: _parseDt(map['submissionDate']),
      approvalDate: _parseDt(map['approvalDate']),
      publishedDate: _parseDt(map['publishedDate']),
      assignedOfficer: map['assignedOfficer'] as String? ?? '',
      feeAmount: (map['feeAmount'] as num?)?.toDouble(),
      notes: map['notes'] as String? ?? '',
      rejectionReason: map['rejectionReason'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      updatedBy: map['updatedBy'] as String? ?? '',
      createdAt: _parseDt(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDt(map['updatedAt']) ?? DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1 ||
          map['pendingSync'] == true,
      deleted: (map['deleted'] as int? ?? 0) == 1 || map['deleted'] == true,
    );
  }

  factory LroCase.fromFirestore(Map<String, dynamic> map) {
    return LroCase.fromMap({
      ...map,
      'pendingSync': 0,
      'deleted': map['deleted'] == true || map['deleted'] == 1 ? 1 : 0,
    });
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }
}
