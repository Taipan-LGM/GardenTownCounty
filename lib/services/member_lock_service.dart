import '../models/member.dart';
import '../models/user_role.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sync_engine.dart';
import 'temporary_access_service.dart';

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
    if (member.isLocked) {
      throw Exception('⚠️ Member is already locked.');
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
      completedBy: actor.id,
      completedDate: now,
      lastModifiedBy: actor.id,
      updatedAt: now,
      pendingSync: true,
    );
    await _db.upsertMember(locked);
    await _activity.record(
      userName: actor.displayName,
      action: '🔒 lock_member ${locked.fullName} (all steps complete)',
      captureGps: false,
    );
    await _activity.record(
      userName: 'System',
      action:
          '✅ ${locked.fullName} completed all requirements. Member is now locked.',
      captureGps: false,
    );
    await _sync.pushPending();
    return locked;
  }

  Future<Member> unlock({
    required Member member,
    required AuthUser actor,
    String? reason,
  }) async {
    if (!actor.isAdmin) {
      throw Exception('Only the System Administrator can unlock members.');
    }
    if (!member.isLocked) {
      throw Exception('⚠️ Member is not locked.');
    }
    final unlocked = member.copyWith(
      clearLock: true,
      clearTemporaryAccess: true,
      registrationStatus: 'complete',
      lastModifiedBy: actor.id,
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await _db.upsertMember(unlocked);
    await _activity.record(
      userName: actor.displayName,
      action:
          '🔓 unlock_member ${member.fullName}${reason != null ? ' — $reason' : ''}',
      captureGps: false,
    );
    await _sync.pushPending();
    return unlocked;
  }

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
