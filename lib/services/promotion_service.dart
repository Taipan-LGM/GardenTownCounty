import '../models/app_user.dart';
import '../models/member.dart';
import '../models/user_role.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'reminder_notification_service.dart';

/// Promote / demote Member ↔ Recording Secretary (Admin).
///
/// Uses existing [AuthService.assignMemberAccess] / [AuthService.removeMemberAccess].
/// Role lives on AppUser (linked via memberId) — no Member.role column required.
///
/// // NEW ADDITION - Delete this file to revert promotion service.
class PromotionService {
  PromotionService(
    this._auth,
    this._db,
    this._activity, {
    ReminderNotificationService? notifications,
  }) : _notifications = notifications;

  final AuthService _auth;
  final DatabaseService _db;
  final ActivityService _activity;
  final ReminderNotificationService? _notifications;

  Future<AppUser?> linkedUserForMember(String memberId) =>
      _db.getAppUserByMemberId(memberId);

  Future<bool> isRecordingSecretary(Member member) async {
    final user = await linkedUserForMember(member.id);
    return user != null && !user.deleted && user.isSecretary;
  }

  Future<AppUser> promoteToRecordingSecretary({
    required Member member,
    required AuthUser admin,
    List<AppPermission>? permissions,
  }) async {
    final existing = await linkedUserForMember(member.id);
    if (existing != null && !existing.deleted && existing.isSecretary) {
      throw Exception(
        '${member.fullName} is already a Recording Secretary.',
      );
    }

    final user = await _auth.assignMemberAccess(
      memberId: member.id,
      saId: member.saId,
      memberName: member.memberName,
      surname: member.surname,
      role: UserRole.secretary.storageName,
      permissions: permissions ?? AppPermission.assignable,
    );

    await _activity.record(
      userName: admin.displayName,
      action: 'promote_to_secretary ${member.fullName}',
      captureGps: false,
    );

    await _notifications?.notifyPromotionToSecretary(
      memberName: member.fullName,
      adminName: admin.displayName,
    );

    return user;
  }

  Future<void> demoteToMember({
    required Member member,
    required AuthUser admin,
  }) async {
    final existing = await linkedUserForMember(member.id);
    if (existing == null || existing.deleted || !existing.isSecretary) {
      throw Exception('${member.fullName} is not a Recording Secretary.');
    }

    // Assignments are keyed by AppUser id (secretaryId).
    final activeAssignments = await _db.countAssignedMembers(existing.id);
    if (activeAssignments > 0) {
      throw Exception(
        '${member.fullName} has $activeAssignments active member assignment(s). '
        'Reassign them first.',
      );
    }

    await _auth.removeMemberAccess(existing.id);

    await _activity.record(
      userName: admin.displayName,
      action: 'demote_to_member ${member.fullName}',
      captureGps: false,
    );

    await _notifications?.notifyDemotionToMember(
      memberName: member.fullName,
      adminName: admin.displayName,
    );
  }
}
