/// Thrown when SA ID or Global Record No. collides with another member.
class DuplicateException implements Exception {
  DuplicateException(this.message, {this.field, this.value, this.existingMemberId});

  final String message;
  final String? field;
  final String? value;
  final String? existingMemberId;

  @override
  String toString() => 'DuplicateException: $message';
}
