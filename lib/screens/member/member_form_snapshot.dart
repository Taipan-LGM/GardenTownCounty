/// Immutable copy of the member form fields, used to restore values when the
/// user cancels out of Edit Mode.
class MemberFormSnapshot {
  const MemberFormSnapshot({
    required this.saId,
    required this.globalRecordNo,
    required this.lroRecordNo,
    required this.memberName,
    required this.surname,
    required this.address,
    required this.suburb,
    required this.townCity,
    required this.postalCode,
    required this.contactNo1,
    required this.contactNo2,
    required this.email,
    required this.comment,
    required this.photoLocalPath,
    required this.photoUrl,
  });

  final String saId;
  final String globalRecordNo;
  final String lroRecordNo;
  final String memberName;
  final String surname;
  final String address;
  final String? suburb;
  final String? townCity;
  final String? postalCode;
  final String contactNo1;
  final String contactNo2;
  final String email;
  final String comment;
  final String? photoLocalPath;
  final String? photoUrl;
}
