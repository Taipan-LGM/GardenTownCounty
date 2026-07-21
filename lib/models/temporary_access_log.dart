import 'package:uuid/uuid.dart';

/// Audit trail for Admin-granted temporary edit access codes.
class TemporaryAccessLog {
  final String id;
  final String? firestoreId;
  final String memberId;
  final String adminId;
  final String secretaryId;
  final String accessCode;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final bool isUsed;
  final DateTime? usedAt;
  final String? reason;
  final bool revoked;
  final DateTime? revokedAt;
  final bool pendingSync;
  final bool deleted;

  const TemporaryAccessLog({
    required this.id,
    this.firestoreId,
    required this.memberId,
    required this.adminId,
    required this.secretaryId,
    required this.accessCode,
    required this.grantedAt,
    required this.expiresAt,
    this.isUsed = false,
    this.usedAt,
    this.reason,
    this.revoked = false,
    this.revokedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now().toUtc());

  bool get isActive => !revoked && !isExpired;

  factory TemporaryAccessLog.create({
    required String memberId,
    required String adminId,
    required String secretaryId,
    required String accessCode,
    required DateTime expiresAt,
    String? reason,
  }) {
    final now = DateTime.now().toUtc();
    return TemporaryAccessLog(
      id: const Uuid().v4(),
      memberId: memberId,
      adminId: adminId,
      secretaryId: secretaryId,
      accessCode: accessCode,
      grantedAt: now,
      expiresAt: expiresAt,
      reason: reason,
      pendingSync: true,
    );
  }

  TemporaryAccessLog copyWith({
    String? id,
    String? firestoreId,
    String? memberId,
    String? adminId,
    String? secretaryId,
    String? accessCode,
    DateTime? grantedAt,
    DateTime? expiresAt,
    bool? isUsed,
    DateTime? usedAt,
    String? reason,
    bool? revoked,
    DateTime? revokedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return TemporaryAccessLog(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      memberId: memberId ?? this.memberId,
      adminId: adminId ?? this.adminId,
      secretaryId: secretaryId ?? this.secretaryId,
      accessCode: accessCode ?? this.accessCode,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      usedAt: usedAt ?? this.usedAt,
      reason: reason ?? this.reason,
      revoked: revoked ?? this.revoked,
      revokedAt: revokedAt ?? this.revokedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'memberId': memberId,
      'adminId': adminId,
      'secretaryId': secretaryId,
      'accessCode': accessCode,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed ? 1 : 0,
      'usedAt': usedAt?.toIso8601String(),
      'reason': reason,
      'revoked': revoked ? 1 : 0,
      'revokedAt': revokedAt?.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'memberId': memberId,
      'adminId': adminId,
      'secretaryId': secretaryId,
      'accessCode': accessCode,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
      'reason': reason,
      'revoked': revoked,
      'revokedAt': revokedAt?.toIso8601String(),
      'deleted': deleted,
    };
  }

  factory TemporaryAccessLog.fromMap(Map<String, dynamic> map) {
    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is int) return v == 1;
      return false;
    }

    DateTime? asDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
      return null;
    }

    return TemporaryAccessLog(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      memberId: map['memberId'] as String? ?? '',
      adminId: map['adminId'] as String? ?? '',
      secretaryId: map['secretaryId'] as String? ?? '',
      accessCode: map['accessCode'] as String? ?? '',
      grantedAt: asDate(map['grantedAt']) ?? DateTime.now().toUtc(),
      expiresAt: asDate(map['expiresAt']) ?? DateTime.now().toUtc(),
      isUsed: asBool(map['isUsed']),
      usedAt: asDate(map['usedAt']),
      reason: map['reason'] as String?,
      revoked: asBool(map['revoked']),
      revokedAt: asDate(map['revokedAt']),
      pendingSync: asBool(map['pendingSync']),
      deleted: asBool(map['deleted']),
    );
  }

  factory TemporaryAccessLog.fromFirestore(Map<String, dynamic> map) {
    return TemporaryAccessLog.fromMap({
      ...map,
      'isUsed': map['isUsed'] == true ? 1 : 0,
      'revoked': map['revoked'] == true ? 1 : 0,
      'deleted': map['deleted'] == true ? 1 : 0,
      'pendingSync': 0,
    });
  }
}
