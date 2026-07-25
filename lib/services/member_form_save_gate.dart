import 'sa_id_validator.dart';

/// Pure rules for when Member Info Save may enable.
///
/// // NEW ADDITION - Delete this file to revert Save-button enable gate.
class MemberFormSaveGate {
  MemberFormSaveGate._();

  static final RegExp _emailLoose = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  /// Labels still empty / invalid for a staff new/edit save.
  ///
  /// Required for Save enable (user spec): SA ID, name, surname, address,
  /// suburb, town, postal, contact1, email. Global Record is optional.
  // MODIFIED - GR optional for enable (Delete requireGlobalRecord:false default)
  static List<String> missingRequiredLabels({
    required String saId,
    required String globalRecordNo,
    required String memberName,
    required String surname,
    required String address,
    required String? suburb,
    required String? townCity,
    required String? postalCode,
    required String contactNo1,
    required String email,
    bool requireGlobalRecord = false,
    String? saIdLiveError,
    String? globalRecordLiveError,
  }) {
    final missing = <String>[];

    final saHard = SaIdValidator.validate(saId);
    if (saHard != null) {
      missing.add('SA ID No.');
    } else if (saIdLiveError != null && saIdLiveError.trim().isNotEmpty) {
      missing.add('SA ID No. (fix duplicate/error)');
    }

    if (requireGlobalRecord) {
      final grHard = GlobalRecordValidator.validate(globalRecordNo);
      if (grHard != null) {
        missing.add('Global Record No.');
      } else if (globalRecordLiveError != null &&
          globalRecordLiveError.trim().isNotEmpty) {
        missing.add('Global Record No. (fix duplicate/error)');
      }
    } else if (globalRecordNo.trim().isNotEmpty &&
        globalRecordLiveError != null &&
        globalRecordLiveError.trim().isNotEmpty) {
      // Only block on GR duplicate/format when a value was entered.
      missing.add('Global Record No. (fix duplicate/error)');
    }

    if (!_filled(memberName)) missing.add('Member Name');
    if (!_filled(surname)) missing.add('Surname');
    if (!_filled(address)) missing.add('Address');
    if (!_filled(suburb)) missing.add('Suburb');
    if (!_filled(townCity)) missing.add('Town / City');
    if (!_filled(postalCode)) missing.add('Postal Code');
    if (!_filled(contactNo1)) missing.add('Contact No. 1');
    if (!_filled(email)) {
      missing.add('Email Address');
    } else if (!_emailLoose.hasMatch(email.trim())) {
      missing.add('Email Address (valid format)');
    }

    return missing;
  }

  static bool canEnableSave({
    required bool isEditing,
    required bool saving,
    required bool formReadOnly,
    required bool fieldsMasked,
    required List<String> missingLabels,
  }) {
    if (!isEditing || saving || formReadOnly || fieldsMasked) return false;
    return missingLabels.isEmpty;
  }

  static bool _filled(String? value) =>
      value != null && value.trim().isNotEmpty;
}
