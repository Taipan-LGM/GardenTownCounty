import '../models/lro_case.dart';
import '../models/member.dart';
import '../models/reminder.dart';
import '../models/user_role.dart';
import '../core/constants/app_constants.dart';
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

  Future<List<Member>> getVisibleMembers(
    AuthUser? user, {
    int? offset,
    int? limit,
    String? query,
  }) async {
    if (user == null) return const [];

    if (user.isAdmin || user.isSystemAdministrator) {
      if (offset != null || limit != null || (query != null && query.trim().isNotEmpty)) {
        final page = await _db.getMembersPage(
          offset: offset ?? 0,
          limit: limit ?? AppConstants.membersPageSize,
          query: query,
        );
        return page.items;
      }
      return _db.getAllMembers();
    }

    if (user.isSecretary) {
      if (offset != null || limit != null || (query != null && query.trim().isNotEmpty)) {
        final page = await _db.getMembersPage(
          offset: offset ?? 0,
          limit: limit ?? AppConstants.membersPageSize,
          secretaryId: user.id,
          query: query,
        );
        return page.items;
      }
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

  Future<({List<Member> items, int total})> getVisibleMembersPage(
    AuthUser? user, {
    int offset = 0,
    int limit = AppConstants.membersPageSize,
    String? query,
  }) async {
    if (user == null) return (items: <Member>[], total: 0);

    if (user.isAdmin || user.isSystemAdministrator) {
      return _db.getMembersPage(offset: offset, limit: limit, query: query);
    }

    if (user.isSecretary) {
      return _db.getMembersPage(
        offset: offset,
        limit: limit,
        secretaryId: user.id,
        query: query,
      );
    }

    if (user.isMemberRole) {
      final memberId = user.memberId;
      if (memberId == null || memberId.isEmpty) {
        return (items: <Member>[], total: 0);
      }
      final self = await _db.getMemberById(memberId);
      if (self == null) return (items: <Member>[], total: 0);
      final q = query?.trim().toLowerCase();
      if (q != null && q.isNotEmpty) {
        final hay = '${self.memberName} ${self.surname} ${self.saId}'.toLowerCase();
        if (!hay.contains(q)) return (items: <Member>[], total: 0);
      }
      return (items: [self], total: 1);
    }

    return (items: <Member>[], total: 0);
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
