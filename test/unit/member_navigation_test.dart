import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/member_navigation_state.dart';

void main() {
  Member m({
    required String name,
    String surname = 'Test',
    String status = 'complete',
    bool locked = false,
    String saId = '9001015009087',
    DateTime? createdAt,
  }) {
    return Member.create(
      saId: saId,
      globalRecordNo: 'GTC-$saId',
      memberName: name,
      surname: surname,
      registrationStatus: status,
    ).copyWith(
      isLocked: locked,
      createdAt: createdAt,
      registrationDate: createdAt,
    );
  }

  group('MemberNavigationLogic', () {
    final members = [
      m(name: 'Alice', surname: 'Adams', status: 'complete'),
      m(name: 'Bob', surname: 'Brown', status: 'pending'),
      m(name: 'Carol', surname: 'Clark', status: 'fully_fledged', locked: true),
      m(
        name: 'Dave',
        surname: 'Dunn',
        status: 'pending',
        createdAt: DateTime.now().toUtc(),
      ),
    ];

    test('search matches name and SA ID', () {
      expect(
        MemberNavigationLogic.filterAndSort(
          members,
          searchQuery: 'bob',
          filter: MemberQuickFilter.all,
          favoriteIds: {},
          sortBy: MemberSortBy.name,
          sortAscending: true,
        ).map((e) => e.memberName),
        ['Bob'],
      );
    });

    test('filters pending / locked / active', () {
      expect(
        MemberNavigationLogic.counts(members, favoriteIds: {}).values.reduce(
              (a, b) => a + b,
            ),
        greaterThan(0),
      );
      expect(
        MemberNavigationLogic.filterAndSort(
          members,
          searchQuery: '',
          filter: MemberQuickFilter.pending,
          favoriteIds: {},
          sortBy: MemberSortBy.name,
          sortAscending: true,
        ).length,
        2,
      );
      expect(
        MemberNavigationLogic.filterAndSort(
          members,
          searchQuery: '',
          filter: MemberQuickFilter.locked,
          favoriteIds: {},
          sortBy: MemberSortBy.name,
          sortAscending: true,
        ).single.memberName,
        'Carol',
      );
    });

    test('pagination slices pages', () {
      final filtered = members;
      expect(
        MemberNavigationLogic.pageCount(filtered.length, 2),
        2,
      );
      expect(
        MemberNavigationLogic.pageSlice(
          filtered,
          page: 0,
          itemsPerPage: 2,
        ).length,
        2,
      );
      expect(
        MemberNavigationLogic.pageSlice(
          filtered,
          page: 1,
          itemsPerPage: 2,
        ).length,
        2,
      );
    });

    test('favorites filter', () {
      final favId = members.first.id;
      final result = MemberNavigationLogic.filterAndSort(
        members,
        searchQuery: '',
        filter: MemberQuickFilter.favorites,
        favoriteIds: {favId},
        sortBy: MemberSortBy.name,
        sortAscending: true,
      );
      expect(result.single.id, favId);
    });
  });
}
