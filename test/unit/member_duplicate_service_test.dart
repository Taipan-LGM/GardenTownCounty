import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/exceptions/duplicate_exception.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/member_duplicate_service.dart';

void main() {
  late DatabaseService db;
  late MemberDuplicateService dup;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
    dup = MemberDuplicateService(db);
  });

  tearDown(() async {
    await db.clearAllForTests();
  });

  Member member({
    required String id,
    required String saId,
    required String globalRecord,
  }) {
    return Member.create(
      saId: saId,
      globalRecordNo: globalRecord,
      memberName: 'Test',
      surname: 'User',
    ).copyWith(id: id);
  }

  test('detects local SA ID duplicate excluding self', () async {
    const sa = '9001014800089';
    await db.upsertMember(
      member(id: 'a', saId: sa, globalRecord: '100'),
    );

    final hit = await dup.checkSaId(sa, excludeMemberId: 'b');
    expect(hit.isDuplicate, isTrue);
    expect(hit.existingMember?.id, 'a');

    final self = await dup.checkSaId(sa, excludeMemberId: 'a');
    expect(self.isDuplicate, isFalse);
  });

  test('detects local Global Record duplicate', () async {
    await db.upsertMember(
      member(id: 'a', saId: '9001014800089', globalRecord: '555'),
    );
    final hit = await dup.checkGlobalRecord('555', excludeMemberId: 'x');
    expect(hit.isDuplicate, isTrue);

    final self = await dup.checkGlobalRecord('555', excludeMemberId: 'a');
    expect(self.isDuplicate, isFalse);
  });

  test('upsertMember throws DuplicateException on clash', () async {
    await db.upsertMember(
      member(id: 'a', saId: '9001014800089', globalRecord: '100'),
    );
    expect(
      () => db.upsertMember(
        member(id: 'b', saId: '9001014800089', globalRecord: '200'),
      ),
      throwsA(isA<DuplicateException>()),
    );
  });

  test('assertUnique allows edit of own values', () async {
    final m = member(id: 'a', saId: '9001014800089', globalRecord: '100');
    await db.upsertMember(m);
    await dup.assertUnique(m.copyWith(memberName: 'Updated'));
  });
}
