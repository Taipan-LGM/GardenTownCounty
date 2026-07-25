import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/member_form_save_gate.dart';

void main() {
  group('MemberFormSaveGate', () {
    Map<String, Object?> filled({
      String saId = '9001015009087',
      String globalRecordNo = '1234567890',
      String memberName = 'Thabo',
      String surname = 'Ndlovu',
      String address = '1 Main Rd',
      String? suburb = 'Gardens',
      String? townCity = 'Cape Town',
      String? postalCode = '8001',
      String contactNo1 = '0215551234',
      String email = 'thabo@example.com',
      bool requireGlobalRecord = false,
      String? saIdLiveError,
      String? globalRecordLiveError,
    }) {
      return {
        'saId': saId,
        'globalRecordNo': globalRecordNo,
        'memberName': memberName,
        'surname': surname,
        'address': address,
        'suburb': suburb,
        'townCity': townCity,
        'postalCode': postalCode,
        'contactNo1': contactNo1,
        'email': email,
        'requireGlobalRecord': requireGlobalRecord,
        'saIdLiveError': saIdLiveError,
        'globalRecordLiveError': globalRecordLiveError,
      };
    }

    List<String> missingOf(Map<String, Object?> args) {
      return MemberFormSaveGate.missingRequiredLabels(
        saId: args['saId'] as String,
        globalRecordNo: args['globalRecordNo'] as String,
        memberName: args['memberName'] as String,
        surname: args['surname'] as String,
        address: args['address'] as String,
        suburb: args['suburb'] as String?,
        townCity: args['townCity'] as String?,
        postalCode: args['postalCode'] as String?,
        contactNo1: args['contactNo1'] as String,
        email: args['email'] as String,
        requireGlobalRecord: args['requireGlobalRecord'] as bool,
        saIdLiveError: args['saIdLiveError'] as String?,
        globalRecordLiveError: args['globalRecordLiveError'] as String?,
      );
    }

    test('complete staff form → no missing labels', () {
      expect(missingOf(filled()), isEmpty);
    });

    test('empty required fields listed', () {
      final missing = missingOf(
        filled(
          saId: '',
          globalRecordNo: '',
          memberName: '',
          surname: '',
          address: '',
          suburb: null,
          townCity: null,
          postalCode: null,
          contactNo1: '',
          email: '',
        ),
      );
      expect(missing, contains('SA ID No.'));
      expect(missing, isNot(contains('Global Record No.')));
      expect(missing, contains('Member Name'));
      expect(missing, contains('Surname'));
      expect(missing, contains('Address'));
      expect(missing, contains('Suburb'));
      expect(missing, contains('Town / City'));
      expect(missing, contains('Postal Code'));
      expect(missing, contains('Contact No. 1'));
      expect(missing, contains('Email Address'));
    });

    test('empty Global Record does not block Save enable', () {
      final missing = missingOf(filled(globalRecordNo: ''));
      expect(missing, isEmpty);
    });

    test('requireGlobalRecord true still lists empty GR', () {
      final missing = missingOf(
        filled(globalRecordNo: '', requireGlobalRecord: true),
      );
      expect(missing, contains('Global Record No.'));
    });

    test('invalid SA ID length blocks save', () {
      final missing = missingOf(filled(saId: '12345'));
      expect(missing, contains('SA ID No.'));
    });

    test('duplicate live error blocks save', () {
      final missing = missingOf(
        filled(saIdLiveError: '❌ This SA ID is already registered'),
      );
      expect(missing, contains('SA ID No. (fix duplicate/error)'));
    });

    test('invalid email format blocks save', () {
      final missing = missingOf(filled(email: 'not-an-email'));
      expect(missing, contains('Email Address (valid format)'));
    });

    test('member role can omit Global Record', () {
      final missing = missingOf(
        filled(globalRecordNo: '', requireGlobalRecord: false),
      );
      expect(missing, isNot(contains('Global Record No.')));
    });

    test('canEnableSave requires edit mode and empty missing list', () {
      expect(
        MemberFormSaveGate.canEnableSave(
          isEditing: true,
          saving: false,
          formReadOnly: false,
          fieldsMasked: false,
          missingLabels: const [],
        ),
        isTrue,
      );
      expect(
        MemberFormSaveGate.canEnableSave(
          isEditing: true,
          saving: false,
          formReadOnly: false,
          fieldsMasked: false,
          missingLabels: const ['Suburb'],
        ),
        isFalse,
      );
      expect(
        MemberFormSaveGate.canEnableSave(
          isEditing: false,
          saving: false,
          formReadOnly: true,
          fieldsMasked: false,
          missingLabels: const [],
        ),
        isFalse,
      );
    });
  });
}
