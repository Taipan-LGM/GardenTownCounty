import '../models/member.dart';

/// Step 1 (Member Info) required-field checks.
///
/// // NEW ADDITION - Delete this file to revert Step 1 auto-activation.
class Step1Validator {
  Step1Validator._();

  static const List<String> requiredFields = [
    'saId',
    'globalRecordNo',
    'lroRecordNo',
    'memberName',
    'surname',
    'address',
    'suburb',
    'townCity',
    'postalCode',
    'contactNo1',
    'contactNo2',
    'emailAddress',
  ];

  static bool _filled(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool isStep1Complete(Member member) {
    return _filled(member.saId) &&
        _filled(member.globalRecordNo) &&
        _filled(member.lroRecordNo) &&
        _filled(member.memberName) &&
        _filled(member.surname) &&
        _filled(member.address) &&
        _filled(member.suburb) &&
        _filled(member.townCity) &&
        _filled(member.postalCode) &&
        _filled(member.contactNo1) &&
        _filled(member.contactNo2) &&
        _filled(member.emailAddress);
  }

  /// Live form values (controllers / dropdowns).
  static bool isFormComplete({
    required String saId,
    required String globalRecordNo,
    required String? lroRecordNo,
    required String memberName,
    required String surname,
    required String address,
    required String? suburb,
    required String? townCity,
    required String? postalCode,
    required String contactNo1,
    required String contactNo2,
    required String emailAddress,
  }) {
    return _filled(saId) &&
        _filled(globalRecordNo) &&
        _filled(lroRecordNo) &&
        _filled(memberName) &&
        _filled(surname) &&
        _filled(address) &&
        _filled(suburb) &&
        _filled(townCity) &&
        _filled(postalCode) &&
        _filled(contactNo1) &&
        _filled(contactNo2) &&
        _filled(emailAddress);
  }
}
