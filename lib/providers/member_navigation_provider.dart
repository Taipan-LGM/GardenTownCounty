import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';
import '../models/member_navigation_state.dart';
import '../services/member_navigation_prefs.dart';

final memberNavigationPrefsProvider = Provider<MemberNavigationPrefs>((ref) {
  return MemberNavigationPrefs();
});

final memberNavigationProvider =
    StateNotifierProvider<MemberNavigationController, MemberNavigationState>(
  (ref) {
    final controller = MemberNavigationController(
      prefs: ref.watch(memberNavigationPrefsProvider),
    );
    controller.hydrate();
    return controller;
  },
);

class MemberNavigationController extends StateNotifier<MemberNavigationState> {
  MemberNavigationController({required MemberNavigationPrefs prefs})
      : _prefs = prefs,
        super(const MemberNavigationState());

  final MemberNavigationPrefs _prefs;
  bool _hydrated = false;

  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final recent = await _prefs.loadRecent();
    final favorites = await _prefs.loadFavorites();
    state = state.copyWith(
      recentlyViewed: recent,
      favoriteIds: favorites,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      currentPage: 0,
      highlightIndex: 0,
    );
  }

  void setFilter(MemberQuickFilter filter) {
    state = state.copyWith(
      selectedFilter: filter,
      currentPage: 0,
      highlightIndex: 0,
    );
  }

  void setSort(MemberSortBy sortBy, {bool? ascending}) {
    state = state.copyWith(
      sortBy: sortBy,
      sortAscending: ascending ??
          (state.sortBy == sortBy ? !state.sortAscending : true),
      currentPage: 0,
    );
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page < 0 ? 0 : page, highlightIndex: 0);
  }

  void nextPage(int totalFiltered) {
    final pages = MemberNavigationLogic.pageCount(
      totalFiltered,
      state.itemsPerPage,
    );
    if (state.currentPage < pages - 1) {
      setPage(state.currentPage + 1);
    }
  }

  void previousPage() {
    if (state.currentPage > 0) setPage(state.currentPage - 1);
  }

  void setHighlightIndex(int index) {
    state = state.copyWith(highlightIndex: index < 0 ? 0 : index);
  }

  List<Member> filtered(List<Member> all) {
    return MemberNavigationLogic.filterAndSort(
      all,
      searchQuery: state.searchQuery,
      filter: state.selectedFilter,
      favoriteIds: state.favoriteIds,
      sortBy: state.sortBy,
      sortAscending: state.sortAscending,
    );
  }

  List<Member> pageMembers(List<Member> all) {
    return MemberNavigationLogic.pageSlice(
      filtered(all),
      page: state.currentPage,
      itemsPerPage: state.itemsPerPage,
    );
  }

  Future<void> openMember(
    Member member, {
    required List<Member> all,
    bool forceEdit = false,
    String action = 'view',
  }) async {
    final list = filtered(all);
    final index = list.indexWhere((m) => m.id == member.id);
    final page = index < 0 ? 0 : index ~/ state.itemsPerPage;
    await _pushRecent(member.id, action: action);
    state = state.copyWith(
      currentView: MemberNavView.profile,
      selectedMemberId: member.id,
      currentIndex: index < 0 ? 0 : index,
      currentPage: page,
      highlightIndex: index < 0 ? 0 : index % state.itemsPerPage,
      forceEdit: forceEdit,
    );
  }

  /// Keep counter / prev-next in sync after external reloads.
  void syncSelection(Member member, List<Member> all) {
    final list = filtered(all);
    final index = list.indexWhere((m) => m.id == member.id);
    if (index < 0) return;
    state = state.copyWith(
      currentView: MemberNavView.profile,
      selectedMemberId: member.id,
      currentIndex: index,
      currentPage: index ~/ state.itemsPerPage,
      highlightIndex: index % state.itemsPerPage,
    );
  }

  Future<void> openAtFilteredIndex(
    int index, {
    required List<Member> all,
    bool forceEdit = false,
  }) async {
    final list = filtered(all);
    if (index < 0 || index >= list.length) return;
    await openMember(list[index], all: all, forceEdit: forceEdit);
  }

  void goBackToList() {
    state = state.copyWith(
      currentView: MemberNavView.list,
      clearSelectedMember: true,
      forceEdit: false,
    );
  }

  void beginNewMember() {
    state = state.copyWith(
      currentView: MemberNavView.profile,
      clearSelectedMember: true,
      currentIndex: -1,
      forceEdit: true,
    );
  }

  Future<void> navigateRelative(
    int delta, {
    required List<Member> all,
  }) async {
    final list = filtered(all);
    if (list.isEmpty) return;
    var idx = state.currentIndex;
    if (idx < 0 && state.selectedMemberId != null) {
      idx = list.indexWhere((m) => m.id == state.selectedMemberId);
    }
    if (idx < 0) idx = 0;
    final next = (idx + delta).clamp(0, list.length - 1);
    if (next == idx && state.selectedMemberId == list[next].id) return;
    await openMember(list[next], all: all);
  }

  Future<void> navigateFirst({required List<Member> all}) =>
      openAtFilteredIndex(0, all: all);

  Future<void> navigateLast({required List<Member> all}) async {
    final list = filtered(all);
    if (list.isEmpty) return;
    await openAtFilteredIndex(list.length - 1, all: all);
  }

  Future<void> toggleFavorite(String memberId) async {
    final next = {...state.favoriteIds};
    if (next.contains(memberId)) {
      next.remove(memberId);
    } else {
      next.add(memberId);
    }
    state = state.copyWith(favoriteIds: next);
    await _prefs.saveFavorites(next);
  }

  Future<void> clearRecent() async {
    state = state.copyWith(recentlyViewed: const []);
    await _prefs.saveRecent(const []);
  }

  Future<void> _pushRecent(String memberId, {required String action}) async {
    final now = DateTime.now().toUtc();
    final next = [
      RecentlyViewedEntry(memberId: memberId, viewedAt: now, action: action),
      ...state.recentlyViewed.where((e) => e.memberId != memberId),
    ];
    final trimmed = next.take(10).toList();
    state = state.copyWith(recentlyViewed: trimmed);
    await _prefs.saveRecent(trimmed);
  }

  void moveListHighlight(int delta, {required int pageLength}) {
    if (pageLength <= 0) return;
    final next = (state.highlightIndex + delta).clamp(0, pageLength - 1);
    state = state.copyWith(highlightIndex: next);
  }

  void clearForceEdit() {
    if (state.forceEdit) {
      state = state.copyWith(forceEdit: false);
    }
  }
}
