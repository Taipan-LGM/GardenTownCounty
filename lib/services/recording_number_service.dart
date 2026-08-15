import 'dart:math';
import '../models/lro_settings.dart';
import '../models/member.dart';

/// Generates unique 16-digit LRO Recording Numbers and manages the
/// 7-digit uniqueness pool.
class RecordingNumberService {
  static const int _maxRetries = 200;
  static final Random _random = Random.secure();

  /// The three parts that make up a 16-digit Recording Number:
  ///   3-digit county code + 6-digit payment date (ddmmyy) + 7-digit random.
  /// Total = 16 digits.
  ///
  /// [countyUniqueNo] must be exactly 3 digits (e.g. "024").
  /// [paymentDate] is the date the payment was recorded.
  /// [order] is the Admin-selected concatenation order.
  /// [existingNumbers] is a set of all Recording Numbers already in the database
  ///   (used to ensure the 7-digit random part is unique).
  static String generate({
    required String countyUniqueNo,
    required DateTime paymentDate,
    required LroNumberOrder order,
    required Set<String> existingNumbers,
  }) {
    if (countyUniqueNo.trim().length != 3) {
      throw ArgumentError.value(
        countyUniqueNo,
        'countyUniqueNo',
        'Must be exactly 3 digits.',
      );
    }
    final county = countyUniqueNo.trim();
    final date = _formatDateDDMMYY(paymentDate);
    final unique = _generateUniqueSevenDigit(existingNumbers);

    return _assemble(county, date, unique, order);
  }

  /// Generates a 7-digit number that is not present in [existingNumbers].
  /// Retries up to [_maxRetries] times. Throws if no unique number can be found.
  static String _generateUniqueSevenDigit(Set<String> existing) {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final candidate = _random.nextInt(10000000); // 0 .. 9999999
      final padded = candidate.toString().padLeft(7, '0');
      if (!existing.contains(padded)) {
        return padded;
      }
    }
    throw StateError(
      'Could not generate a unique 7-digit number after $_maxRetries attempts. '
      'The Recording Number space may be exhausted.',
    );
  }

  static String _formatDateDDMMYY(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString().substring(2);
    return '$dd$mm$yy';
  }

  static String _assemble(
    String county,
    String date,
    String unique,
    LroNumberOrder order,
  ) {
    switch (order) {
      case LroNumberOrder.countyDateUnique:
        return '$county$date$unique'; // 024 + 150125 + 1234567
      case LroNumberOrder.uniqueDateCounty:
        return '$unique$date$county'; // 1234567 + 150125 + 024
      case LroNumberOrder.dateCountyUnique:
        return '$date$county$unique'; // 150125 + 024 + 1234567
    }
  }

  /// Checks whether a given 16-digit Recording Number already exists.
  static bool isDuplicate(String recordingNumber, Set<String> existing) {
    return existing.contains(recordingNumber);
  }

  /// Validates a 3-digit county unique number.
  static String? validateCountyUniqueNo(String value) {
    final trimmed = value.trim();
    if (trimmed.length != 3) {
      return 'Enter exactly 3 digits (for example, 024).';
    }
    if (!trimmed.contains(RegExp(r'^[0-9]{3}$'))) {
      return 'Use only digits (for example, 024).';
    }
    return null;
  }

  /// Validates that a 16-digit Recording Number is well-formed.
  static String? validateRecordingNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.length != 16) {
      return 'Recording Number must be exactly 16 digits.';
    }
    if (!trimmed.contains(RegExp(r'^[0-9]{16}$'))) {
      return 'Recording Number must contain only digits.';
    }
    return null;
  }
}
