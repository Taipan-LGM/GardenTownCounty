import 'dart:math';

import '../models/member.dart';
import '../models/temporary_access_log.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sync_engine.dart';

/// Generate / verify / revoke / auto-expire 5-digit temporary edit codes.
class TemporaryAccessService {
  TemporaryAccessService(this._db, this._sync, this._activity);

  final DatabaseService _db;
  final SyncEngine _sync;
  final ActivityService _activity;
  final _random = Random.secure();

  static bool isGrantValidFor(Member member, String secretaryId) {
    if (!member.isLocked) return false;
    if (!member.hasActiveTemporaryAccess) return false;
    return member.temporaryAccessGrantedTo == secretaryId;
  }

  static Duration parseDurationLabel(String duration) {
    switch (duration) {
      case '24h':
        return const Duration(hours: 24);
      case '7d':
        return const Duration(days: 7);
      case '1h':
      default:
        return const Duration(hours: 1);
    }
  }

  static String durationLabel(Duration d) {
    if (d.inDays >= 7) return '7d';
    if (d.inHours >= 24) return '24h';
    return '1h';
  }

  String generate5DigitCode() {
    final buf = StringBuffer();
    for (var i = 0; i < 5; i++) {
      buf.write(_random.nextInt(10));
    }
    return buf.toString();
  }

  Future<String> _uniqueCode() async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final code = generate5DigitCode();
      if (!await _db.temporaryAccessCodeExists(code)) return code;
    }
    throw Exception('Unable to generate a unique access code. Try again.');
  }

  Future<TemporaryAccessResult> grant({
    required Member member,
    required AuthUser admin,
    required String secretaryId,
    required String duration,
    required String reason,
  }) async {
    if (!admin.isAdmin) {
      throw Exception('❌ Only Admin can grant temporary access.');
    }
    if (!member.isLocked) {
      throw Exception(
        '❌ Member is not locked. Temporary access is not needed.',
      );
    }
    if (reason.trim().isEmpty) {
      throw Exception('⚠️ Please provide a reason for access.');
    }
    final secretary = await _db.getAppUserById(secretaryId);
    if (secretary == null || !secretary.isSecretary) {
      throw Exception('❌ Select a Recording Secretary.');
    }

    final code = await _uniqueCode();
    final expiry = DateTime.now().toUtc().add(parseDurationLabel(duration));
    final log = TemporaryAccessLog.create(
      memberId: member.id,
      adminId: admin.id,
      adminName: admin.displayName,
      secretaryId: secretaryId,
      secretaryName: secretary.displayName,
      accessCode: code,
      expiresAt: expiry,
      duration: duration,
      reason: reason.trim(),
    );
    await _db.upsertTemporaryAccessLog(log);

    final updated = member.copyWith(
      temporaryAccessCode: code,
      temporaryAccessExpiry: expiry,
      temporaryAccessGrantedBy: admin.id,
      temporaryAccessGrantedTo: secretaryId,
      temporaryAccessReason: reason.trim(),
      lastModifiedBy: admin.id,
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await _db.upsertMember(updated);

    await _activity.record(
      userName: admin.displayName,
      action:
          '🔑 grant_temp_access ${member.fullName} → ${secretary.displayName} '
          '(Code: $code, $duration)',
      captureGps: false,
    );
    await _activity.record(
      userName: 'System',
      action:
          '🔑 Notify ${secretary.displayName}: temp access for ${member.fullName}. '
          'Code: $code',
      captureGps: false,
    );
    await _sync.pushPending();

    return TemporaryAccessResult(
      code: code,
      expiresAt: expiry,
      logId: log.id,
      member: MemberRef(
        id: member.id,
        fullName: member.fullName,
        saId: member.saId,
      ),
      secretaryName: secretary.displayName,
    );
  }

  Future<VerificationResult> verify({
    required Member member,
    required AuthUser secretary,
    required String code,
  }) async {
    final trimmed = code.trim();

    if (!member.isLocked) {
      return const VerificationResult(
        success: false,
        message: '❌ This member is not locked. Access not required.',
      );
    }
    if (trimmed.length != 5 || int.tryParse(trimmed) == null) {
      await _logFailedAttempt(member, secretary, trimmed, 'invalid_format');
      return const VerificationResult(
        success: false,
        message: '❌ Invalid code. Enter a 5-digit code.',
      );
    }
    if (member.temporaryAccessCode != trimmed) {
      await _logFailedAttempt(member, secretary, trimmed, 'invalid_code');
      return const VerificationResult(
        success: false,
        message: '❌ Invalid code. Please check and try again.',
      );
    }
    if (member.temporaryAccessExpiry == null ||
        member.temporaryAccessExpiry!.isBefore(DateTime.now().toUtc())) {
      await _logFailedAttempt(member, secretary, trimmed, 'expired');
      return const VerificationResult(
        success: false,
        message: '❌ Code has expired. Please contact the Administrator.',
        isExpired: true,
      );
    }
    if (member.temporaryAccessGrantedTo != secretary.id) {
      await _logFailedAttempt(member, secretary, trimmed, 'wrong_user');
      return const VerificationResult(
        success: false,
        message: '❌ This code was not assigned to you.',
      );
    }

    final logs = await _db.getTemporaryAccessLogsForMember(member.id);
    TemporaryAccessLog? match;
    for (final log in logs) {
      if (log.accessCode == trimmed && log.secretaryId == secretary.id) {
        match = log;
        break;
      }
    }
    if (match != null && match.isRevoked) {
      return const VerificationResult(
        success: false,
        message:
            '❌ This code has been revoked. Please contact the Administrator.',
        revoked: true,
      );
    }

    if (match != null) {
      await _db.upsertTemporaryAccessLog(
        match.copyWith(
          isUsed: true,
          usedAt: DateTime.now().toUtc(),
          status: 'used',
          pendingSync: true,
        ),
      );
    }

    await _activity.record(
      userName: secretary.displayName,
      action: '🔄 use_temp_access ${member.fullName} (Code: $trimmed)',
      captureGps: false,
    );
    await _activity.record(
      userName: 'System',
      action:
          '🔄 Notify Admin: ${secretary.displayName} used temp code for ${member.fullName}',
      captureGps: false,
    );
    await _sync.pushPending();

    final remaining =
        member.temporaryAccessExpiry!.difference(DateTime.now().toUtc());
    return VerificationResult(
      success: true,
      message: '✅ Access granted! You can now edit this member temporarily.',
      isValid: true,
      expiresAt: member.temporaryAccessExpiry,
      timeRemaining: remaining,
    );
  }

  Future<Member> revoke({
    required Member member,
    required AuthUser actor,
    String? reason,
  }) async {
    if (!actor.isAdmin) {
      throw Exception('❌ Only Admin can revoke temporary access.');
    }
    if (member.temporaryAccessCode == null) {
      throw Exception('❌ No active temporary access to revoke.');
    }

    final code = member.temporaryAccessCode!;
    final secretaryId = member.temporaryAccessGrantedTo;
    final logs = await _db.getTemporaryAccessLogsForMember(member.id);
    final now = DateTime.now().toUtc();
    for (final log in logs) {
      if (log.accessCode == code && !log.isRevoked) {
        await _db.upsertTemporaryAccessLog(
          log.copyWith(
            isRevoked: true,
            revokedAt: now,
            revokedBy: actor.id,
            revokedReason: reason ?? 'Revoked by Administrator',
            status: 'revoked',
            pendingSync: true,
          ),
        );
      }
    }

    final cleared = member.copyWith(
      clearTemporaryAccess: true,
      lastModifiedBy: actor.id,
      updatedAt: now,
      pendingSync: true,
    );
    await _db.upsertMember(cleared);

    await _activity.record(
      userName: actor.displayName,
      action: '❌ revoke_temp_access ${member.fullName} (Code: $code)',
      captureGps: false,
    );
    if (secretaryId != null) {
      final sec = await _db.getAppUserById(secretaryId);
      await _activity.record(
        userName: 'System',
        action:
            '❌ Notify ${sec?.displayName ?? secretaryId}: temp access to '
            '${member.fullName} revoked',
        captureGps: false,
      );
    }
    await _sync.pushPending();
    return cleared;
  }

  Future<TempAccessStatus> checkTemporaryAccessStatus({
    required Member member,
    required AuthUser user,
    required bool sessionVerified,
  }) async {
    if (!member.isLocked) {
      return const TempAccessStatus(
        isLocked: false,
        canEdit: true,
        message: 'Member is not locked. No temporary access needed.',
      );
    }
    if (user.isAdmin) {
      return const TempAccessStatus(
        isLocked: true,
        canEdit: true,
        isAdmin: true,
        message: 'Admin has full access.',
      );
    }
    if (sessionVerified && isGrantValidFor(member, user.id)) {
      final remaining =
          member.temporaryAccessExpiry!.difference(DateTime.now().toUtc());
      return TempAccessStatus(
        isLocked: true,
        canEdit: true,
        hasTemporaryAccess: true,
        timeRemaining: remaining,
        code: member.temporaryAccessCode,
        expiresAt: member.temporaryAccessExpiry,
        message:
            '✅ Temporary access active. ${remaining.inMinutes} minutes remaining.',
      );
    }
    return const TempAccessStatus(
      isLocked: true,
      canEdit: false,
      message: '🔒 Member is locked. Contact Admin for temporary access.',
    );
  }

  /// Clear expired temp-access grants. Safe to call every minute.
  Future<int> autoExpireTemporaryAccess() async {
    final members = await _db.getMembersWithTempAccess();
    var expiredCount = 0;
    final now = DateTime.now().toUtc();

    for (final member in members) {
      final expiry = member.temporaryAccessExpiry;
      if (expiry == null || expiry.isAfter(now)) continue;

      final code = member.temporaryAccessCode ?? '';
      final secretaryId = member.temporaryAccessGrantedTo;

      final logs = await _db.getTemporaryAccessLogsForMember(member.id);
      for (final log in logs) {
        if (log.accessCode == code && log.status != 'revoked') {
          await _db.upsertTemporaryAccessLog(
            log.copyWith(status: 'expired', pendingSync: true),
          );
        }
      }

      await _db.upsertMember(
        member.copyWith(
          clearTemporaryAccess: true,
          updatedAt: now,
          pendingSync: true,
        ),
      );

      await _activity.record(
        userName: 'System',
        action: '⏰ temp_access_expired ${member.fullName} (Code: $code)',
        captureGps: false,
      );
      if (secretaryId != null) {
        final sec = await _db.getAppUserById(secretaryId);
        await _activity.record(
          userName: 'System',
          action:
              '⏰ Notify ${sec?.displayName ?? secretaryId}: temp access to '
              '${member.fullName} expired',
          captureGps: false,
        );
      }
      expiredCount++;
    }

    if (expiredCount > 0) {
      await _sync.pushPending();
    }
    return expiredCount;
  }

  Future<void> _logFailedAttempt(
    Member member,
    AuthUser secretary,
    String code,
    String reason,
  ) async {
    await _activity.record(
      userName: secretary.displayName,
      action:
          '⚠️ temp_access_failed ${member.fullName} ($reason, code: $code)',
      captureGps: false,
    );
  }
}
