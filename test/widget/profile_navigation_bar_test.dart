import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/widgets/member_nav/profile_navigation_bar.dart';

Member _member(String id, String name, String surname) {
  final now = DateTime.utc(2026, 1, 1);
  return Member(
    id: id,
    saId: '1234567890123',
    globalRecordNo: 'GR-$id',
    memberName: name,
    surname: surname,
    address: '1 Main',
    suburb: 'Suburb',
    townCity: 'Town',
    postalCode: '0001',
    contactNo1: '000',
    contactNo2: '',
    emailAddress: 'a@b.c',
    comment: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('ProfileNavigationBar shows Previous and Next labels',
      (tester) async {
    var prev = 0;
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileNavigationBar(
            currentMember: _member('2', 'Jane', 'Doe'),
            currentIndex: 1,
            totalMembers: 3,
            previousName: 'Ada Lovelace',
            nextName: 'Zoe Zebra',
            onBack: () {},
            onPrevious: () => prev++,
            onNext: () => next++,
          ),
        ),
      ),
    );

    expect(find.textContaining('Previous'), findsOneWidget);
    expect(find.textContaining('Next'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.textContaining('Jane Doe'), findsOneWidget);

    await tester.tap(find.textContaining('Previous'));
    await tester.tap(find.textContaining('Next'));
    expect(prev, 1);
    expect(next, 1);
  });

  testWidgets('ProfileNavigationBar disables edges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileNavigationBar(
            currentMember: _member('1', 'Ada', 'Lovelace'),
            currentIndex: 0,
            totalMembers: 1,
            onBack: () {},
            onPrevious: () {},
            onNext: () {},
          ),
        ),
      ),
    );

    final prev = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Previous'),
    );
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(prev.onPressed, isNull);
    expect(next.onPressed, isNull);
  });
}
