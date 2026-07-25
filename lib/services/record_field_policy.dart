/// Visibility / edit rules for Global Record No. and LRO Record No.
///
/// // NEW ADDITION - Delete this file to revert record-field policy.
class RecordFieldPolicy {
  RecordFieldPolicy._();

  static bool hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// Admin/Secretary: always show. Member: only when a value exists.
  static bool shouldShow({
    required bool isAdmin,
    required bool isSecretary,
    required String? value,
  }) {
    if (isAdmin || isSecretary) return true;
    return hasValue(value);
  }

  /// Admin: always editable (when form allows).
  /// Secretary: editable only until a persisted value exists.
  /// Member: always read-only for these fields.
  static bool isReadOnly({
    required bool isAdmin,
    required bool isSecretary,
    required String? persistedValue,
    required bool formReadOnly,
  }) {
    if (formReadOnly) return true;
    if (isAdmin) return false;
    if (isSecretary) return hasValue(persistedValue);
    return true;
  }

  /// Non-admin cannot change a field once a persisted value exists.
  static void assertCanSave({
    required bool isAdmin,
    required String? existingGlobalRecordNo,
    required String nextGlobalRecordNo,
    required String? existingLroRecordNo,
    required String? nextLroRecordNo,
  }) {
    if (isAdmin) return;

    final existingGr = (existingGlobalRecordNo ?? '').trim();
    final nextGr = nextGlobalRecordNo.trim();
    if (existingGr.isNotEmpty && existingGr != nextGr) {
      throw Exception(
        'Global Record No. cannot be changed. Only Admin can edit this field.',
      );
    }

    final existingLro = (existingLroRecordNo ?? '').trim();
    final nextLro = (nextLroRecordNo ?? '').trim();
    if (existingLro.isNotEmpty && existingLro != nextLro) {
      throw Exception(
        'LRO Record No. cannot be changed. Only Admin can edit this field.',
      );
    }
  }

  /// Human-readable audit lines for record-number create/change.
  static List<String> auditLines({
    required String memberName,
    required String? oldGlobal,
    required String newGlobal,
    required String? oldLro,
    required String? newLro,
  }) {
    final lines = <String>[];
    final og = (oldGlobal ?? '').trim();
    final ng = newGlobal.trim();
    if (og != ng) {
      if (og.isEmpty && ng.isNotEmpty) {
        lines.add('Entered Global Record No. for $memberName: $ng');
      } else if (og.isNotEmpty && ng.isEmpty) {
        lines.add('Cleared Global Record No. for $memberName (was $og)');
      } else {
        lines.add('Changed Global Record No. for $memberName: $og → $ng');
      }
    }

    final ol = (oldLro ?? '').trim();
    final nl = (newLro ?? '').trim();
    if (ol != nl) {
      if (ol.isEmpty && nl.isNotEmpty) {
        lines.add('Entered LRO Record No. for $memberName: $nl');
      } else if (ol.isNotEmpty && nl.isEmpty) {
        lines.add('Cleared LRO Record No. for $memberName (was $ol)');
      } else {
        lines.add('Changed LRO Record No. for $memberName: $ol → $nl');
      }
    }
    return lines;
  }
}
