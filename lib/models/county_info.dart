/// Persisted Garden Town County identity + reset tracking (single-row table).
///
/// // NEW ADDITION - Delete this file to revert County Information feature.
class CountyInfo {
  static const documentId = 'county_info';

  final String id;
  final String? firestoreId;
  final String countyName;
  final String countyAddress;
  final String countyRegistrationNo;
  final DateTime lastUpdated;
  final String updatedBy;
  final String syncStatus;
  final bool isDeleted;
  final DateTime? lastResetDate;
  final int resetCount;
  final String? resetBy;

  const CountyInfo({
    this.id = documentId,
    this.firestoreId,
    required this.countyName,
    required this.countyAddress,
    required this.countyRegistrationNo,
    required this.lastUpdated,
    required this.updatedBy,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    this.lastResetDate,
    this.resetCount = 0,
    this.resetBy,
  });

  factory CountyInfo.defaults({String updatedBy = 'system'}) {
    return CountyInfo(
      countyName: 'Garden Town County',
      countyAddress: '123 Main Street, Sandton, Johannesburg',
      countyRegistrationNo: 'CT2026-001',
      lastUpdated: DateTime.now().toUtc(),
      updatedBy: updatedBy,
      syncStatus: 'synced',
    );
  }

  CountyInfo copyWith({
    String? id,
    String? firestoreId,
    String? countyName,
    String? countyAddress,
    String? countyRegistrationNo,
    DateTime? lastUpdated,
    String? updatedBy,
    String? syncStatus,
    bool? isDeleted,
    DateTime? lastResetDate,
    int? resetCount,
    String? resetBy,
    bool clearLastResetDate = false,
    bool clearResetBy = false,
    bool clearFirestoreId = false,
  }) {
    return CountyInfo(
      id: id ?? this.id,
      firestoreId: clearFirestoreId ? null : (firestoreId ?? this.firestoreId),
      countyName: countyName ?? this.countyName,
      countyAddress: countyAddress ?? this.countyAddress,
      countyRegistrationNo:
          countyRegistrationNo ?? this.countyRegistrationNo,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      lastResetDate:
          clearLastResetDate ? null : (lastResetDate ?? this.lastResetDate),
      resetCount: resetCount ?? this.resetCount,
      resetBy: clearResetBy ? null : (resetBy ?? this.resetBy),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'countyName': countyName,
        'countyAddress': countyAddress,
        'countyRegistrationNo': countyRegistrationNo,
        'lastUpdated': lastUpdated.toIso8601String(),
        'updatedBy': updatedBy,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
        'lastResetDate': lastResetDate?.toIso8601String(),
        'resetCount': resetCount,
        'resetBy': resetBy,
      };

  factory CountyInfo.fromMap(Map<String, dynamic> map) {
    return CountyInfo(
      id: map['id'] as String? ?? documentId,
      firestoreId: map['firestoreId'] as String?,
      countyName: map['countyName'] as String? ?? 'Garden Town County',
      countyAddress: map['countyAddress'] as String? ?? '',
      countyRegistrationNo: map['countyRegistrationNo'] as String? ?? '',
      lastUpdated: DateTime.tryParse(map['lastUpdated'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedBy: map['updatedBy'] as String? ?? 'system',
      syncStatus: map['syncStatus'] as String? ?? 'pending',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      lastResetDate:
          DateTime.tryParse(map['lastResetDate'] as String? ?? ''),
      resetCount: map['resetCount'] as int? ?? 0,
      resetBy: map['resetBy'] as String?,
    );
  }
}
