import 'dart:math';

import '../models/member.dart';
import '../models/temporary_access_log.dart';
import '../models/user_role.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sync_engine.dart';

/// Lock / unlock members once onboarding is complete.
class MemberLockService {
  MemberLockService(this._db, this._sync, this._activity);

  final DatabaseService _db;
  final SyncEngine _sync;
  final ActivityService _activity;

  /// Mark all 4 steps complete and lock the member (Recording Secretary or Admin).
  Future<Member> completeAndLock({
    required Member member,
    required AuthUser actor,
    String? reason,
  }) async {
    if (!actor.isAdmin &&
        !actor.hasPermission(AppPermission.onboarding) &&
        !actor.hasPermission(AppPermission.memberInfo)) {
      throw Exception('You do not have permission to complete members.');
    }

    final now = DateTime.now().toUtc();
    final locked = member.copyWith(
      step1MemberInfoComplete: true,
      step2Global528Complete: true,
      step3Global928Complete: true,
      step4LROComplete: true,
      step1CompletionDate: member.step1CompletionDate ?? now,
      step2CompletionDate: member.step2CompletionDate ?? now,
      step3CompletionDate: member.step3CompletionDate ?? now,
      step4CompletionDate: member.step4CompletionDate ?? now,
      step1ApprovedBy: member.step1ApprovedBy ?? actor.id,
      step2ApprovedBy: member.step2ApprovedBy ?? actor.id,
      step3ApprovedBy: member.step3ApprovedBy ?? actor.id,
      step4ApprovedBy: member.step4ApprovedBy ?? actor.id,
      registrationStatus: 'fully_fledged',
      isLocked: true,
      lockedDate: now,
      lockedBy: actor.id,
      lockedReason: reason ?? 'All requirements completed',
      lastModifiedBy: actor.id,
      updatedAt: now,
      pendingSync: true,
    );
    await _db.upsertMember(locked);
    await _activity.record(
      userName: actor.displayName,
      action: '🔒 Locked member ${locked.fullName} (all steps complete)',
      captureGps: false,
    );
    await _sync.pushPending();
    return locked;
  }

  Future<Member> unlock({
    required Member member,
    required AuthUser actor,
  }) async {
    if (!actor.isAdmin) {
      throw Exception('Only the System Administrator can unlock members.');
    }
    final unlocked = member.copyWith(
      clearLock: true,
      clearTemporaryAccess: true,
      lastModifiedBy: actor.id,
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await _db.upsertMember(unlocked);
    await _activity.record(
      userName: actor.displayName,
      action: '🔓 Unlocked member ${member.fullName}',
      captureGps: false,
    );
    await _sync.pushPending();
    return unlocked;
  }

  /// Whether [user] may edit [member] (Admin always; unlocked + permission;
  /// or locked with verified temporary access).
  bool canEditMember({
    required Member member,
    required AuthUser? user,
    required bool sessionVerifiedTempAccess,
  }) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (!user.hasPermission(AppPermission.memberInfo)) return false;
    if (!member.isLocked) return true;
    return sessionVerifiedTempAccess &&
        TemporaryAccessService.isGrantValidFor(member, user.id);
  }
}

/// Generate / verify / revoke 5-digit temporary edit codes.
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

  Future<({String code, TemporaryAccessLog log, Member member})> grant({
    required Member member,
    required AuthUser admin,
    required String secretaryId,
    required Duration duration,
    String? reason,
  }) async {
    if (!admin.isAdmin) {
      throw Exception('Only Admin can grant temporary access.');
    }
    if (!member.isLocked) {
      throw Exception('Member is not locked. Temporary access is not needed.');
    }
    final secretary = await _db.getAppUserById(secretaryId);
    if (secretary == null || !secretary.isSecretary) {
      throw Exception('Select a Recording Secretary.');
    }

    final code = await _uniqueCode();
    final expiry = DateTime.now().toUtc().add(duration);
    final log = TemporaryAccessLog.create(
      memberId: member.id,
      adminId: admin.id,
      secretaryId: secretaryId,
      accessCode: code,
      expiresAt: expiry,
      reason: reason,
    );
    await _db.upsertTemporaryAccessLog(log);

    final updated = member.copyWith(
      temporaryAccessCode: code,
      temporaryAccessExpiry: expiry,
      temporaryAccessGrantedBy: admin.id,
      temporaryAccessGrantedTo: secretaryId,
      temporaryAccessReason: reason,
      lastModifiedBy: admin.id,
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await _db.upsertMember(updated);

    await _activity.record(
      userName: admin.displayName,
      action:
          '🔑 Temporary access granted to ${secretary.displayName} for ${member.fullName} (Code: $code)',
      captureGps: false,
    );
    await _sync.pushPending();
    return (code: code, log: log, member: updated);
  }

  Future<Member> verify({
    required Member member,
    required AuthUser secretary,
    required String code,
  }) async {
    final trimmed = code.trim();
    if (trimmed.length != 5 || int.tryParse(trimmed) == null) {
      throw Exception('❌ Invalid code. Enter a 5-digit code.');
    }
    if (member.temporaryAccessCode != trimmed) {
      throw Exception('❌ Invalid code. Please try again.');
    }
    if (member.temporaryAccessExpiry == null ||
        member.temporaryAccessExpiry!.isBefore(DateTime.now().toUtc())) {
      throw Exception('❌ Code has expired. Please contact Admin.');
    }
    if (member.temporaryAccessGrantedTo != secretary.id) {
      throw Exception('❌ This code was not assigned to you.');
    }

    final logs = await _db.getTemporaryAccessLogsForMember(member.id);
    TemporaryAccessLog? match;
    for (final log in logs) {
      if (log.accessCode == trimmed &&
          log.secretaryId == secretary.id &&
          log.isActive) {
        match = log;
        break;
      }
    }
    if (match != null) {
      await _db.upsertTemporaryAccessLog(
        match.copyWith(
          isUsed: true,
          usedAt: DateTime.now().toUtc(),
          pendingSync: true,
        ),
      );
    }

    await _activity.record(
      userName: secretary.displayName,
      action: '🔄 Used temporary access code for ${member.fullName}',
      captureGps: false,
    );
    await _sync.pushPending();
    return member;
  }

  Future<Member> revoke({
    required Member member,
    required AuthUser actor,
  }) async {
    if (!actor.isAdmin) {
      throw Exception('Only Admin can revoke temporary access.');
    }
    final logs = await _db.getTemporaryAccessLogsForMember(member.id);
    final now = DateTime.now().toUtc();
    for (final log in logs) {
      if (log.isActive && !log.revoked) {
        await _db.upsertTemporaryAccessLog(
          log.copyWith(revoked: true, revokedAt: now, pendingSync: true),
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
      action: '🔒 Revoked temporary access for ${member.fullName}',
      captureGps: false,
    );
    await _sync.pushPending();
    return cleared;
  }
}
