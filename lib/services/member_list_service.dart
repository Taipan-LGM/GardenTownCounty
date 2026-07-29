import '../core/constants/app_constants.dart';
import '../models/member.dart';
import 'auth_service.dart';
import 'data_access_service.dart';

/// Paginated member list for UI (avoids loading the full roster into memory).
class MemberListService {
  MemberListService(this._access);

  final DataAccessService _access;

  Future<MemberPage> loadPage(
    AuthUser? user, {
    int page = 0,
    int pageSize = AppConstants.membersPageSize,
    String? query,
  }) async {
    final offset = page < 0 ? 0 : page * pageSize;
    final result = await _access.getVisibleMembersPage(
      user,
      offset: offset,
      limit: pageSize,
      query: query,
    );
    final totalPages =
        result.total == 0 ? 0 : ((result.total + pageSize - 1) ~/ pageSize);
    return MemberPage(
      items: result.items,
      total: result.total,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
    );
  }
}

class MemberPage {
  const MemberPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<Member> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasNext => page + 1 < totalPages;
  bool get hasPrevious => page > 0;
}
