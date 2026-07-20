import 'package:uuid/uuid.dart';

class Member {
  final String id;
  final String saId;
  final String globalRecordNo;
  final String memberName;
  final String surname;
  final String address;
  final String suburb;
  final String townCity;
  final String postalCode;
  final String contactNo1;
  final String contactNo2;
  final String emailAddress;
  final String comment;
  final String? photoLocalPath;
  final String? photoUrl;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const Member({
    required this.id,
    required this.saId,
    required this.globalRecordNo,
    required this.memberName,
    required this.surname,
    this.address = '',
    this.suburb = '',
    this.townCity = '',
    this.postalCode = '',
    this.contactNo1 = '',
    this.contactNo2 = '',
    this.emailAddress = '',
    this.comment = '',
    this.photoLocalPath,
    this.photoUrl,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  factory Member.create({
    required String saId,
    required String globalRecordNo,
    required String memberName,
    required String surname,
    String address = '',
    String suburb = '',
    String townCity = '',
    String postalCode = '',
    String contactNo1 = '',
    String contactNo2 = '',
    String emailAddress = '',
    String comment = '',
    String? photoLocalPath,
    String? photoUrl,
  }) {
    return Member(
      id: const Uuid().v4(),
      saId: saId,
      globalRecordNo: globalRecordNo,
      memberName: memberName,
      surname: surname,
      address: address,
      suburb: suburb,
      townCity: townCity,
      postalCode: postalCode,
      contactNo1: contactNo1,
      contactNo2: contactNo2,
      emailAddress: emailAddress,
      comment: comment,
      photoLocalPath: photoLocalPath,
      photoUrl: photoUrl,
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
  }

  Member copyWith({
    String? id,
    String? saId,
    String? globalRecordNo,
    String? memberName,
    String? surname,
    String? address,
    String? suburb,
    String? townCity,
    String? postalCode,
    String? contactNo1,
    String? contactNo2,
    String? emailAddress,
    String? comment,
    String? photoLocalPath,
    String? photoUrl,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool clearPhotoLocalPath = false,
    bool clearPhotoUrl = false,
  }) {
    return Member(
      id: id ?? this.id,
      saId: saId ?? this.saId,
      globalRecordNo: globalRecordNo ?? this.globalRecordNo,
      memberName: memberName ?? this.memberName,
      surname: surname ?? this.surname,
      address: address ?? this.address,
      suburb: suburb ?? this.suburb,
      townCity: townCity ?? this.townCity,
      postalCode: postalCode ?? this.postalCode,
      contactNo1: contactNo1 ?? this.contactNo1,
      contactNo2: contactNo2 ?? this.contactNo2,
      emailAddress: emailAddress ?? this.emailAddress,
      comment: comment ?? this.comment,
      photoLocalPath:
          clearPhotoLocalPath ? null : (photoLocalPath ?? this.photoLocalPath),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  String get fullName => '$memberName $surname'.trim();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saId': saId,
      'globalRecordNo': globalRecordNo,
      'memberName': memberName,
      'surname': surname,
      'address': address,
      'suburb': suburb,
      'townCity': townCity,
      'postalCode': postalCode,
      'contactNo1': contactNo1,
      'contactNo2': contactNo2,
      'emailAddress': emailAddress,
      'comment': comment,
      'photoLocalPath': photoLocalPath,
      'photoUrl': photoUrl,
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    // Never sync huge data-URI photos to Firestore (1 MB doc limit).
    final cloudPhoto = (photoUrl != null && photoUrl!.startsWith('data:'))
        ? null
        : photoUrl;
    return {
      'id': id,
      'saId': saId,
      'globalRecordNo': globalRecordNo,
      'memberName': memberName,
      'surname': surname,
      'address': address,
      'suburb': suburb,
      'townCity': townCity,
      'postalCode': postalCode,
      'contactNo1': contactNo1,
      'contactNo2': contactNo2,
      'emailAddress': emailAddress,
      'comment': comment,
      'photoUrl': cloudPhoto,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      saId: map['saId'] as String? ?? '',
      globalRecordNo: map['globalRecordNo'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      surname: map['surname'] as String? ?? '',
      address: map['address'] as String? ?? '',
      suburb: map['suburb'] as String? ?? '',
      townCity: map['townCity'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      contactNo1: map['contactNo1'] as String? ?? '',
      contactNo2: map['contactNo2'] as String? ?? '',
      emailAddress: map['emailAddress'] as String? ?? '',
      comment: map['comment'] as String? ?? '',
      photoLocalPath: map['photoLocalPath'] as String?,
      photoUrl: map['photoUrl'] as String?,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  factory Member.fromFirestore(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      saId: map['saId'] as String? ?? '',
      globalRecordNo: map['globalRecordNo'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      surname: map['surname'] as String? ?? '',
      address: map['address'] as String? ?? '',
      suburb: map['suburb'] as String? ?? '',
      townCity: map['townCity'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      contactNo1: map['contactNo1'] as String? ?? '',
      contactNo2: map['contactNo2'] as String? ?? '',
      emailAddress: map['emailAddress'] as String? ?? '',
      comment: map['comment'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
    );
  }
}
