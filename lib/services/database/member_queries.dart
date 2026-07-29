/// Extracted member pagination helpers — keeps list queries off the UI layer.
///
/// Prefer [MemberListService] / [membersPageProvider] for screens that can
/// page; [DataAccessService.getVisibleMembers] remains for flows that need
/// the full visible set (e.g. member form prev/next).
library;

export '../member_list_service.dart';
export '../data_access_service.dart';
