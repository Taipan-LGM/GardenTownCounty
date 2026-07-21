import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/sa_id_validator.dart';

void main() {
  group('SaIdValidator', () {
    test('rejects empty / non-digits / wrong length', () {
      expect(SaIdValidator.validate(''), isNotNull);
      expect(SaIdValidator.validate('abcdefghijklm'), isNotNull);
      expect(SaIdValidator.validate('123'), isNotNull);
    });

    test('rejects bad month/day/citizenship/type', () {
      expect(SaIdValidator.isValidFormat('8013015009087'), isFalse); // month 13
      expect(SaIdValidator.isValidFormat('8001325009087'), isFalse); // day 32
      expect(SaIdValidator.isValidFormat('8001015009287'), isFalse); // type 2
      expect(SaIdValidator.isValidFormat('8001015009587'), isFalse); // citizen 5
    });

    test('accepts known valid SA ID with Luhn checksum', () {
      const id = '9001014800089';
      expect(SaIdValidator.isValidFormat(id), isTrue);
      expect(SaIdValidator.validateLuhnChecksum(id), isTrue);
      expect(SaIdValidator.validate(id), isNull);
    });

    test('rejects invalid checksum', () {
      const id = '9001014800080'; // last digit wrong
      expect(SaIdValidator.validateLuhnChecksum(id), isFalse);
    });
  });

  group('GlobalRecordValidator', () {
    test('requires digits up to 14', () {
      expect(GlobalRecordValidator.validate(''), isNotNull);
      expect(GlobalRecordValidator.validate('12a'), isNotNull);
      expect(GlobalRecordValidator.validate('123456789012345'), isNotNull);
      expect(GlobalRecordValidator.validate('123'), isNull);
      expect(GlobalRecordValidator.validate('12345678901234'), isNull);
    });
  });
}
