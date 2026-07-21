import '../models/member.dart';

/// List vs profile view in Member Info.
enum MemberNavView { list, profile }

/// Quick filter for the left panel / chip bar.
enum MemberQuickFilter {
  all,
  active,
  pending,
  locked,
  newMembers,
  favorites,
}

extension MemberQuickFilterX on MemberQuickFilter {
  String get label {
    switch (this) {
      case MemberQuickFilter.all:
        return 'All';
      case MemberQuickFilter.active:
        return 'Active';
      case MemberQuickFilter.pending:
        return 'Pending';
      case MemberQuickFilter.locked:
        return 'Locked';
      case MemberQuickFilter.newMembers:
        return 'New';
      case MemberQuickFilter.favorites:
        return 'Favorites';
    }
  }

  String get iconLabel {
    switch (this) {
      case MemberQuickFilter.all:
        return '🟢';
      case MemberQuickFilter.active:
        return '🟢';
      case MemberQuickFilter.pending:
        return '🟡';
      case MemberQuickFilter.locked:
        return '🔒';
      case MemberQuickFilter.newMembers:
        return '📌';
      case MemberQuickFilter.favorites:
        return '⭐';
    }
  }
}

enum MemberSortBy { name, surname, saId, date }

/// One entry in recently-viewed history.
class RecentlyViewedEntry {
  const RecentlyViewedEntry({
    required this.memberId,
    required this.viewedAt,
    this.action = 'view',
  });

  final String memberId;
  final DateTime viewedAt;
  final String action;

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'viewedAt': viewedAt.toIso8601String(),
        'action': action,
      };

  factory RecentlyViewedEntry.fromJson(Map<String, dynamic> json) {
    return RecentlyViewedEntry(
      memberId: json['memberId'] as String? ?? '',
      viewedAt: DateTime.tryParse(json['viewedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      action: json['action'] as String? ?? 'view',
    );
  }
}

/// Immutable navigation state for Member Info browsing.
class MemberNavigationState {
  const MemberNavigationState({
    this.currentView = MemberNavView.list,
    this.currentPage = 0,
    this.itemsPerPage = 25,
    this.searchQuery = '',
    this.selectedFilter = MemberQuickFilter.all,
    this.sortBy = MemberSortBy.name,
    this.sortAscending = true,
    this.selectedMemberId,
    this.currentIndex = -1,
    this.highlightIndex = 0,
    this.recentlyViewed = const [],
    this.favoriteIds = const {},
    this.forceEdit = false,
  });

  final MemberNavView currentView;
  final int currentPage;
  final int itemsPerPage;
  final String searchQuery;
  final MemberQuickFilter selectedFilter;
  final MemberSortBy sortBy;
  final bool sortAscending;
  final String? selectedMemberId;
  /// Index within the full filtered list (not just current page).
  final int currentIndex;
  /// Keyboard highlight index within the current page.
  final int highlightIndex;
  final List<RecentlyViewedEntry> recentlyViewed;
  final Set<String> favoriteIds;
  final bool forceEdit;

  MemberNavigationState copyWith({
    MemberNavView? currentView,
    int? currentPage,
    int? itemsPerPage,
    String? searchQuery,
    MemberQuickFilter? selectedFilter,
    MemberSortBy? sortBy,
    bool? sortAscending,
    String? selectedMemberId,
    bool clearSelectedMember = false,
    int? currentIndex,
    int? highlightIndex,
    List<RecentlyViewedEntry>? recentlyViewed,
    Set<String>? favoriteIds,
    bool? forceEdit,
  }) {
    return MemberNavigationState(
      currentView: currentView ?? this.currentView,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      selectedMemberId: clearSelectedMember
          ? null
          : (selectedMemberId ?? this.selectedMemberId),
      currentIndex: currentIndex ?? this.currentIndex,
      highlightIndex: highlightIndex ?? this.highlightIndex,
      recentlyViewed: recentlyViewed ?? this.recentlyViewed,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      forceEdit: forceEdit ?? this.forceEdit,
    );
  }
}

/// Pure filter / sort / page helpers (easy to unit-test).
class MemberNavigationLogic {
  static bool matchesSearch(Member m, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return m.memberName.toLowerCase().contains(q) ||
        m.surname.toLowerCase().contains(q) ||
        m.fullName.toLowerCase().contains(q) ||
        m.saId.toLowerCase().contains(q) ||
        m.globalRecordNo.toLowerCase().contains(q) ||
        m.emailAddress.toLowerCase().contains(q);
  }

  static bool matchesFilter(
    Member m, {
    required MemberQuickFilter filter,
    required Set<String> favoriteIds,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    switch (filter) {
      case MemberQuickFilter.all:
        return true;
      case MemberQuickFilter.active:
        return !m.isLocked &&
            (m.registrationStatus == 'complete' ||
                m.registrationStatus == 'fully_fledged');
      case MemberQuickFilter.pending:
        return m.registrationStatus == 'pending' ||
            m.registrationStatus == 'in_progress';
      case MemberQuickFilter.locked:
        return m.isLocked;
      case MemberQuickFilter.newMembers:
        final created = m.createdAt ?? m.registrationDate;
        if (created == null) return false;
        return clock.difference(created).inDays <= 14;
      case MemberQuickFilter.favorites:
        return favoriteIds.contains(m.id);
    }
  }

  static int compare(Member a, Member b, MemberSortBy sortBy, bool asc) {
    int c;
    switch (sortBy) {
      case MemberSortBy.name:
        c = a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
        if (c == 0) {
          c = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
        }
      case MemberSortBy.surname:
        c = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
        if (c == 0) {
          c = a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
        }
      case MemberSortBy.saId:
        c = a.saId.compareTo(b.saId);
      case MemberSortBy.date:
        final da = a.updatedAt;
        final db = b.updatedAt;
        c = da.compareTo(db);
    }
    return asc ? c : -c;
  }

  static List<Member> filterAndSort(
    List<Member> source, {
    required String searchQuery,
    required MemberQuickFilter filter,
    required Set<String> favoriteIds,
    required MemberSortBy sortBy,
    required bool sortAscending,
  }) {
    final filtered = source
        .where(
          (m) =>
              matchesSearch(m, searchQuery) &&
              matchesFilter(m, filter: filter, favoriteIds: favoriteIds),
        )
        .toList()
      ..sort((a, b) => compare(a, b, sortBy, sortAscending));
    return filtered;
  }

  static int pageCount(int total, int itemsPerPage) {
    if (total <= 0 || itemsPerPage <= 0) return 1;
    return ((total - 1) ~/ itemsPerPage) + 1;
  }

  static List<Member> pageSlice(
    List<Member> filtered, {
    required int page,
    required int itemsPerPage,
  }) {
    if (filtered.isEmpty) return const [];
    final start = page * itemsPerPage;
    if (start >= filtered.length) return const [];
    final end = (start + itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  static Map<MemberQuickFilter, int> counts(
    List<Member> source, {
    required Set<String> favoriteIds,
  }) {
    final map = <MemberQuickFilter, int>{};
    for (final f in MemberQuickFilter.values) {
      map[f] = source
          .where((m) => matchesFilter(m, filter: f, favoriteIds: favoriteIds))
          .length;
    }
    return map;
  }

  static String statusLabel(Member m) {
    if (m.isLocked) return 'Locked';
    if (m.registrationStatus == 'pending' ||
        m.registrationStatus == 'in_progress') {
      return 'Pending';
    }
    return 'Active';
  }
}
