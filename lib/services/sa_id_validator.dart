import '../core/constants/app_constants.dart';

/// South African ID (13-digit) format + Luhn checksum helpers.
class SaIdValidator {
  SaIdValidator._();

  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// Returns null if valid; otherwise an error message.
  static String? validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'SA ID is required';
    if (!_digitsOnly.hasMatch(value)) {
      return 'SA ID must contain only numbers';
    }
    if (value.length != AppConstants.saIdMaxLength) {
      return 'SA ID must be exactly 13 digits';
    }
    if (!isValidFormat(value)) return 'Invalid SA ID format';
    if (!validateLuhnChecksum(value)) return 'Invalid SA ID checksum';
    return null;
  }

  /// YYMMDD + gender + citizenship (0/1) + id type (8/9) + checksum structure.
  static bool isValidFormat(String saId) {
    if (saId.length != 13 || !_digitsOnly.hasMatch(saId)) return false;

    final month = int.tryParse(saId.substring(2, 4)) ?? -1;
    final day = int.tryParse(saId.substring(4, 6)) ?? -1;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    final citizenship = saId.substring(10, 11);
    if (citizenship != '0' && citizenship != '1') return false;

    final idType = saId.substring(11, 12);
    if (idType != '8' && idType != '9') return false;

    return true;
  }

  /// Luhn checksum for SA ID (last digit is check digit).
  static bool validateLuhnChecksum(String id) {
    if (id.length != 13 || !_digitsOnly.hasMatch(id)) return false;
    var sum = 0;
    var doubleDigit = false;
    for (var i = id.length - 1; i >= 0; i--) {
      var digit = int.parse(id[i]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }
}

/// Global Record No. format helpers (1–14 digits).
class GlobalRecordValidator {
  GlobalRecordValidator._();

  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// Returns null if valid; otherwise an error message.
  static String? validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Global Record No. is required';
    if (!_digitsOnly.hasMatch(value)) {
      return 'Global Record No. must contain only numbers';
    }
    if (value.length > AppConstants.globalRecordNoMaxLength) {
      return 'Global Record No. cannot exceed 14 digits';
    }
    return null;
  }
}
