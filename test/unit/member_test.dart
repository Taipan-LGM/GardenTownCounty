import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';

void main() {
  group('Member', () {
    test('create assigns unique id and pending sync', () {
      final member = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
      );

      expect(member.id, isNotEmpty);
      expect(member.saId.length, lessThanOrEqualTo(13));
      expect(member.globalRecordNo.length, lessThanOrEqualTo(14));
      expect(member.pendingSync, isTrue);
      expect(member.fullName, 'Thabo Ndlovu');
    });

    test('copyWith returns new instance without mutating original', () {
      final original = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
      );
      final updated = original.copyWith(memberName: 'Lerato');

      expect(original.memberName, 'Thabo');
      expect(updated.memberName, 'Lerato');
      expect(updated.id, original.id);
    });

    test('round-trips through map', () {
      final member = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
        suburb: 'Heatherlands',
        townCity: 'George',
        postalCode: '6529',
      );
      final restored = Member.fromMap(member.toMap());

      expect(restored.saId, member.saId);
      expect(restored.suburb, 'Heatherlands');
      expect(restored.townCity, 'George');
      expect(restored.postalCode, '6529');
    });
  });
}
