import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/services/record_field_policy.dart';
import 'package:garden_town_county/services/sa_id_validator.dart';

void main() {
  group('RecordFieldPolicy.shouldShow', () {
    test('admin and secretary always see field', () {
      expect(
        RecordFieldPolicy.shouldShow(
          isAdmin: true,
          isSecretary: false,
          value: null,
        ),
        isTrue,
      );
      expect(
        RecordFieldPolicy.shouldShow(
          isAdmin: false,
          isSecretary: true,
          value: '',
        ),
        isTrue,
      );
    });

    test('member sees only when value entered', () {
      expect(
        RecordFieldPolicy.shouldShow(
          isAdmin: false,
          isSecretary: false,
          value: null,
        ),
        isFalse,
      );
      expect(
        RecordFieldPolicy.shouldShow(
          isAdmin: false,
          isSecretary: false,
          value: 'LRO2026-001',
        ),
        isTrue,
      );
    });
  });

  group('RecordFieldPolicy.isReadOnly', () {
    test('admin never locked by policy when form editable', () {
      expect(
        RecordFieldPolicy.isReadOnly(
          isAdmin: true,
          isSecretary: false,
          persistedValue: '123',
          formReadOnly: false,
        ),
        isFalse,
      );
    });

    test('secretary locked after persisted entry', () {
      expect(
        RecordFieldPolicy.isReadOnly(
          isAdmin: false,
          isSecretary: true,
          persistedValue: null,
          formReadOnly: false,
        ),
        isFalse,
      );
      expect(
        RecordFieldPolicy.isReadOnly(
          isAdmin: false,
          isSecretary: true,
          persistedValue: '123456',
          formReadOnly: false,
        ),
        isTrue,
      );
    });

    test('member always read-only for record fields', () {
      expect(
        RecordFieldPolicy.isReadOnly(
          isAdmin: false,
          isSecretary: false,
          persistedValue: null,
          formReadOnly: false,
        ),
        isTrue,
      );
    });
  });

  group('RecordFieldPolicy.assertCanSave', () {
    test('blocks non-admin change of existing LRO', () {
      expect(
        () => RecordFieldPolicy.assertCanSave(
          isAdmin: false,
          existingGlobalRecordNo: '111',
          nextGlobalRecordNo: '111',
          existingLroRecordNo: 'LRO-1',
          nextLroRecordNo: 'LRO-2',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('allows secretary first entry of LRO', () {
      expect(
        () => RecordFieldPolicy.assertCanSave(
          isAdmin: false,
          existingGlobalRecordNo: '111',
          nextGlobalRecordNo: '111',
          existingLroRecordNo: null,
          nextLroRecordNo: 'LRO2026-001',
        ),
        returnsNormally,
      );
    });

    test('admin may change either field', () {
      expect(
        () => RecordFieldPolicy.assertCanSave(
          isAdmin: true,
          existingGlobalRecordNo: '111',
          nextGlobalRecordNo: '222',
          existingLroRecordNo: 'A',
          nextLroRecordNo: 'B',
        ),
        returnsNormally,
      );
    });
  });

  group('LroRecordValidator', () {
    test('allows empty and valid values', () {
      expect(LroRecordValidator.validate(''), isNull);
      expect(LroRecordValidator.validate('LRO2026-001'), isNull);
    });

    test('rejects overlength and bad chars', () {
      expect(LroRecordValidator.validate('123456789012345'), isNotNull);
      expect(LroRecordValidator.validate('LRO 001'), isNotNull);
    });
  });

  group('Member.lroRecordNo', () {
    test('round-trips through map', () {
      final member = Member.create(
        saId: '9001015009087',
        globalRecordNo: '1234567890',
        memberName: 'Thabo',
        surname: 'Ndlovu',
        lroRecordNo: 'LRO2026-001',
      );
      final restored = Member.fromMap(member.toMap());
      expect(restored.lroRecordNo, 'LRO2026-001');
      expect(restored.toFirestore()['lroRecordNo'], 'LRO2026-001');
    });
  });
}
