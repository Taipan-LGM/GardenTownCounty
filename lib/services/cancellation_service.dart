import '../models/member.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Soft-cancel / reinstate membership (never permanently deletes member data).
///
/// // NEW ADDITION - Delete this file to revert cancellation system.
class CancellationService {
  CancellationService(this._db, this._activity);

  final DatabaseService _db;
  final ActivityService _activity;

  Future<Member> cancelMembership({
    required String memberId,
    required AuthUser admin,
    String? reason,
  }) async {
    if (!admin.isAdmin) {
      throw Exception('Only Admin can cancel memberships.');
    }
    final member = await _db.getMemberById(memberId);
    if (member == null) {
      throw Exception('Member not found.');
    }
    if (member.isCancelled) {
      throw Exception('${member.fullName} is already cancelled.');
    }

    final now = DateTime.now().toUtc();
    final updated = member.copyWith(
      isCancelled: true,
      cancellationDate: now,
      cancelledBy: admin.id,
      cancellationReason:
          (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
      registrationStatus: 'cancelled',
      pendingSync: true,
      updatedAt: now,
      lastModifiedBy: admin.id,
    );
    await _db.upsertMember(updated);

    await _activity.record(
      userName: admin.displayName,
      action:
          'cancel_membership ${updated.fullName}'
          '${updated.cancellationReason == null ? '' : ': ${updated.cancellationReason}'}',
      captureGps: false,
    );
    return updated;
  }

  Future<Member> reinstateMembership({
    required String memberId,
    required AuthUser admin,
  }) async {
    if (!admin.isAdmin) {
      throw Exception('Only Admin can reinstate memberships.');
    }
    final member = await _db.getMemberById(memberId);
    if (member == null) {
      throw Exception('Member not found.');
    }
    if (!member.isCancelled) {
      throw Exception('${member.fullName} is not cancelled.');
    }

    final now = DateTime.now().toUtc();
    final updated = member.copyWith(
      clearCancellation: true,
      reinstatedDate: now,
      reinstatedBy: admin.id,
      registrationStatus: 'in_progress',
      pendingSync: true,
      updatedAt: now,
      lastModifiedBy: admin.id,
    );
    await _db.upsertMember(updated);

    await _activity.record(
      userName: admin.displayName,
      action: 'reinstate_membership ${updated.fullName}',
      captureGps: false,
    );
    return updated;
  }
}
