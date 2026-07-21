import 'package:uuid/uuid.dart';

/// Audit trail for Admin-granted temporary edit access codes.
class TemporaryAccessLog {
  final String id;
  final String? firestoreId;
  final String memberId;
  final String adminId;
  final String adminName;
  final String secretaryId;
  final String secretaryName;
  final String accessCode;
  final DateTime grantedAt;
  final DateTime expiresAt;
  /// Storage: `1h` | `24h` | `7d`
  final String duration;
  final String? reason;
  final bool isUsed;
  final DateTime? usedAt;
  final bool isRevoked;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String? revokedReason;
  /// Storage: `active` | `used` | `expired` | `revoked`
  final String status;
  final bool pendingSync;
  final bool deleted;

  const TemporaryAccessLog({
    required this.id,
    this.firestoreId,
    required this.memberId,
    required this.adminId,
    this.adminName = '',
    required this.secretaryId,
    this.secretaryName = '',
    required this.accessCode,
    required this.grantedAt,
    required this.expiresAt,
    this.duration = '1h',
    this.reason,
    this.isUsed = false,
    this.usedAt,
    this.isRevoked = false,
    this.revokedAt,
    this.revokedBy,
    this.revokedReason,
    this.status = 'active',
    this.pendingSync = true,
    this.deleted = false,
  });

  /// Legacy alias used by older call sites.
  bool get revoked => isRevoked;

  bool get isExpired => expiresAt.isBefore(DateTime.now().toUtc());

  bool get isActive =>
      status == 'active' && !isRevoked && !isExpired && !deleted;

  String get computedStatus {
    if (isRevoked || status == 'revoked') return 'revoked';
    if (isExpired || status == 'expired') return 'expired';
    if (isUsed || status == 'used') return 'used';
    return 'active';
  }

  factory TemporaryAccessLog.create({
    required String memberId,
    required String adminId,
    required String adminName,
    required String secretaryId,
    required String secretaryName,
    required String accessCode,
    required DateTime expiresAt,
    required String duration,
    String? reason,
  }) {
    final now = DateTime.now().toUtc();
    return TemporaryAccessLog(
      id: const Uuid().v4(),
      memberId: memberId,
      adminId: adminId,
      adminName: adminName,
      secretaryId: secretaryId,
      secretaryName: secretaryName,
      accessCode: accessCode,
      grantedAt: now,
      expiresAt: expiresAt,
      duration: duration,
      reason: reason,
      status: 'active',
      pendingSync: true,
    );
  }

  TemporaryAccessLog copyWith({
    String? id,
    String? firestoreId,
    String? memberId,
    String? adminId,
    String? adminName,
    String? secretaryId,
    String? secretaryName,
    String? accessCode,
    DateTime? grantedAt,
    DateTime? expiresAt,
    String? duration,
    String? reason,
    bool? isUsed,
    DateTime? usedAt,
    bool? isRevoked,
    bool? revoked,
    DateTime? revokedAt,
    String? revokedBy,
    String? revokedReason,
    String? status,
    bool? pendingSync,
    bool? deleted,
  }) {
    return TemporaryAccessLog(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      memberId: memberId ?? this.memberId,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      secretaryId: secretaryId ?? this.secretaryId,
      secretaryName: secretaryName ?? this.secretaryName,
      accessCode: accessCode ?? this.accessCode,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      duration: duration ?? this.duration,
      reason: reason ?? this.reason,
      isUsed: isUsed ?? this.isUsed,
      usedAt: usedAt ?? this.usedAt,
      isRevoked: isRevoked ?? revoked ?? this.isRevoked,
      revokedAt: revokedAt ?? this.revokedAt,
      revokedBy: revokedBy ?? this.revokedBy,
      revokedReason: revokedReason ?? this.revokedReason,
      status: status ?? this.status,
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
      'adminName': adminName,
      'secretaryId': secretaryId,
      'secretaryName': secretaryName,
      'accessCode': accessCode,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'duration': duration,
      'reason': reason,
      'isUsed': isUsed ? 1 : 0,
      'usedAt': usedAt?.toIso8601String(),
      'revoked': isRevoked ? 1 : 0,
      'revokedAt': revokedAt?.toIso8601String(),
      'revokedBy': revokedBy,
      'revokedReason': revokedReason,
      'status': status,
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'memberId': memberId,
      'adminId': adminId,
      'adminName': adminName,
      'secretaryId': secretaryId,
      'secretaryName': secretaryName,
      'accessCode': accessCode,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'duration': duration,
      'reason': reason,
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
      'isRevoked': isRevoked,
      'revokedAt': revokedAt?.toIso8601String(),
      'revokedBy': revokedBy,
      'revokedReason': revokedReason,
      'status': status,
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
      adminName: map['adminName'] as String? ?? '',
      secretaryId: map['secretaryId'] as String? ?? '',
      secretaryName: map['secretaryName'] as String? ?? '',
      accessCode: map['accessCode'] as String? ?? '',
      grantedAt: asDate(map['grantedAt']) ?? DateTime.now().toUtc(),
      expiresAt: asDate(map['expiresAt']) ?? DateTime.now().toUtc(),
      duration: map['duration'] as String? ?? '1h',
      reason: map['reason'] as String?,
      isUsed: asBool(map['isUsed']),
      usedAt: asDate(map['usedAt']),
      isRevoked: asBool(map['revoked']) || asBool(map['isRevoked']),
      revokedAt: asDate(map['revokedAt']),
      revokedBy: map['revokedBy'] as String?,
      revokedReason: map['revokedReason'] as String?,
      status: map['status'] as String? ?? 'active',
      pendingSync: asBool(map['pendingSync']),
      deleted: asBool(map['deleted']),
    );
  }

  factory TemporaryAccessLog.fromFirestore(Map<String, dynamic> map) {
    return TemporaryAccessLog.fromMap({
      ...map,
      'isUsed': map['isUsed'] == true ? 1 : 0,
      'revoked': (map['isRevoked'] == true || map['revoked'] == true) ? 1 : 0,
      'deleted': map['deleted'] == true ? 1 : 0,
      'pendingSync': 0,
    });
  }
}

class TemporaryAccessResult {
  const TemporaryAccessResult({
    required this.code,
    required this.expiresAt,
    required this.logId,
    required this.member,
    required this.secretaryName,
  });

  final String code;
  final DateTime expiresAt;
  final String logId;
  final MemberRef member;
  final String secretaryName;
}

/// Lightweight member identity for result payloads (avoids circular imports).
class MemberRef {
  const MemberRef({required this.id, required this.fullName, required this.saId});
  final String id;
  final String fullName;
  final String saId;
}

class VerificationResult {
  const VerificationResult({
    required this.success,
    required this.message,
    this.isExpired = false,
    this.isValid = false,
    this.revoked = false,
    this.expiresAt,
    this.timeRemaining,
  });

  final bool success;
  final String message;
  final bool isExpired;
  final bool isValid;
  final bool revoked;
  final DateTime? expiresAt;
  final Duration? timeRemaining;
}

class TempAccessStatus {
  const TempAccessStatus({
    required this.isLocked,
    required this.canEdit,
    required this.message,
    this.isAdmin = false,
    this.hasTemporaryAccess = false,
    this.timeRemaining,
    this.code,
    this.expiresAt,
  });

  final bool isLocked;
  final bool canEdit;
  final bool isAdmin;
  final bool hasTemporaryAccess;
  final Duration? timeRemaining;
  final String? code;
  final DateTime? expiresAt;
  final String message;
}
