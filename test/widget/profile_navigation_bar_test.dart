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
  testWidgets('ProfileNavigationBar shows New Edit Upload Cancel Close',
      (tester) async {
    var created = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileNavigationBar(
            currentMember: _member('2', 'Jane', 'Doe'),
            currentIndex: 1,
            totalMembers: 3,
            onBack: () {},
            onPrevious: () {},
            onNext: () {},
            onFirst: () {},
            onLast: () {},
            onNew: () => created++,
            onEdit: () {},
            onUpload: () {},
            onCancelMembership: () => cancelled++,
            canCancelMembership: true,
          ),
        ),
      ),
    );

    expect(find.text('New'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.textContaining('Previous'), findsOneWidget);
    expect(find.textContaining('Next'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);

    await tester.tap(find.text('New'));
    expect(created, 1);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
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
            onFirst: () {},
            onLast: () {},
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
