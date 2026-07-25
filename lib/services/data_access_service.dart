import '../models/lro_case.dart';
import '../models/member.dart';
import '../models/reminder.dart';
import '../models/user_role.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Role-scoped data visibility (Admin / Secretary / Member).
///
/// Recording Secretaries only see members assigned to them and related data.
///
/// // NEW ADDITION - Delete this file to revert restricted RS views.
class DataAccessService {
  DataAccessService(this._db);

  final DatabaseService _db;

  Future<List<Member>> getVisibleMembers(AuthUser? user) async {
    if (user == null) return const [];
    if (user.isAdmin) return _db.getAllMembers();

    if (user.isSecretary) {
      return _db.getMembersAssignedToSecretary(user.id);
    }

    if (user.isMemberRole) {
      final memberId = user.memberId;
      if (memberId == null || memberId.isEmpty) return const [];
      final self = await _db.getMemberById(memberId);
      return self == null ? const [] : [self];
    }

    return const [];
  }

  Future<List<Reminder>> getVisibleReminders(AuthUser? user) async {
    if (user == null) return const [];
    if (user.isAdmin) {
      return _db.getActiveOnboardingReminders();
    }

    if (user.isSecretary) {
      return _db.getRemindersForSecretaryAssignedMembers(user.id);
    }

    if (user.isMemberRole) {
      final memberId = user.memberId;
      if (memberId == null || memberId.isEmpty) return const [];
      final all = await _db.getActiveOnboardingReminders();
      return all.where((r) => r.memberId == memberId).toList();
    }

    return const [];
  }

  Future<List<LroCase>> getVisibleLroCases(
    AuthUser? user, {
    String? caseType,
  }) async {
    final all = await _db.getLroCases(caseType: caseType);
    if (user == null) return const [];
    if (user.isAdmin) return all;

    if (user.isSecretary) {
      final assigned = await _db.getMembersAssignedToSecretary(user.id);
      final ids = assigned.map((m) => m.id).toSet();
      return all.where((c) => ids.contains(c.memberId)).toList();
    }

    if (user.isMemberRole) {
      final memberId = user.memberId;
      if (memberId == null || memberId.isEmpty) return const [];
      return all.where((c) => c.memberId == memberId).toList();
    }

    return const [];
  }

  Future<bool> canAccessMember(AuthUser? user, String memberId) async {
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (user.isMemberRole) return user.memberId == memberId;
    if (user.isSecretary) {
      final member = await _db.getMemberById(memberId);
      return member != null &&
          !member.deleted &&
          member.assignedSecretaryId == user.id;
    }
    return false;
  }

  /// Permission check for drawer / modules (Admin always true).
  static bool hasPermission(AuthUser? user, AppPermission permission) {
    if (user == null) return false;
    return user.hasPermission(permission);
  }
}
