import 'package:uuid/uuid.dart';

class LroHistory {
  final String id;
  final String? firestoreId;
  final String entityType; // case | notice
  final String entityId;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String changedBy;
  final String detail;
  final DateTime changedAt;
  final bool pendingSync;

  const LroHistory({
    required this.id,
    this.firestoreId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.fromStatus,
    this.toStatus,
    required this.changedBy,
    this.detail = '',
    required this.changedAt,
    this.pendingSync = true,
  });

  factory LroHistory.create({
    required String entityType,
    required String entityId,
    required String action,
    required String changedBy,
    String? fromStatus,
    String? toStatus,
    String detail = '',
  }) {
    return LroHistory(
      id: const Uuid().v4(),
      entityType: entityType,
      entityId: entityId,
      action: action,
      fromStatus: fromStatus,
      toStatus: toStatus,
      changedBy: changedBy,
      detail: detail,
      changedAt: DateTime.now().toUtc(),
    );
  }

  LroHistory copyWith({
    String? id,
    String? firestoreId,
    String? entityType,
    String? entityId,
    String? action,
    String? fromStatus,
    String? toStatus,
    String? changedBy,
    String? detail,
    DateTime? changedAt,
    bool? pendingSync,
  }) {
    return LroHistory(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      changedBy: changedBy ?? this.changedBy,
      detail: detail ?? this.detail,
      changedAt: changedAt ?? this.changedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'fromStatus': fromStatus,
        'toStatus': toStatus,
        'changedBy': changedBy,
        'detail': detail,
        'changedAt': changedAt.toIso8601String(),
        'pendingSync': pendingSync ? 1 : 0,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'firestoreId': firestoreId ?? id,
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'fromStatus': fromStatus,
        'toStatus': toStatus,
        'changedBy': changedBy,
        'detail': detail,
        'changedAt': changedAt.toIso8601String(),
      };

  factory LroHistory.fromMap(Map<String, dynamic> map) {
    return LroHistory(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      entityType: map['entityType'] as String? ?? 'case',
      entityId: map['entityId'] as String? ?? '',
      action: map['action'] as String? ?? '',
      fromStatus: map['fromStatus'] as String?,
      toStatus: map['toStatus'] as String?,
      changedBy: map['changedBy'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      changedAt: DateTime.tryParse(map['changedAt'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1 ||
          map['pendingSync'] == true,
    );
  }

  factory LroHistory.fromFirestore(Map<String, dynamic> map) {
    return LroHistory.fromMap({...map, 'pendingSync': 0});
  }
}
