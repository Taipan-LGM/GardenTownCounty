import 'package:uuid/uuid.dart';

/// Member profile with registration, lock, and temporary-access fields.
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
  /// Link to AppUser when Member has assigned access (User Management).
  final String? userId;

  // Registration & onboarding
  final String registrationStatus; // pending | in_progress | complete | fully_fledged
  final bool isEmailVerified;
  final DateTime? emailVerifiedDate;
  final DateTime? registrationDate;

  // 4-step completion
  final bool step1MemberInfoComplete;
  final bool step2Global528Complete;
  final bool step3Global928Complete;
  final bool step4LROComplete;
  final DateTime? step1CompletionDate;
  final DateTime? step2CompletionDate;
  final DateTime? step3CompletionDate;
  final DateTime? step4CompletionDate;
  final String? step1ApprovedBy;
  final String? step2ApprovedBy;
  final String? step3ApprovedBy;
  final String? step4ApprovedBy;

  // View-only lock
  final bool isLocked;
  final DateTime? lockedDate;
  final String? lockedBy;
  final String? lockedReason;
  final String? completedBy;
  final DateTime? completedDate;

  // Temporary access (5-digit code)
  final String? temporaryAccessCode;
  final DateTime? temporaryAccessExpiry;
  final String? temporaryAccessGrantedBy;
  final String? temporaryAccessGrantedTo;
  final String? temporaryAccessReason;

  // Audit
  final String? createdBy;
  final String? lastModifiedBy;
  final DateTime? createdAt;

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
    this.userId,
    this.registrationStatus = 'pending',
    this.isEmailVerified = false,
    this.emailVerifiedDate,
    this.registrationDate,
    this.step1MemberInfoComplete = false,
    this.step2Global528Complete = false,
    this.step3Global928Complete = false,
    this.step4LROComplete = false,
    this.step1CompletionDate,
    this.step2CompletionDate,
    this.step3CompletionDate,
    this.step4CompletionDate,
    this.step1ApprovedBy,
    this.step2ApprovedBy,
    this.step3ApprovedBy,
    this.step4ApprovedBy,
    this.isLocked = false,
    this.lockedDate,
    this.lockedBy,
    this.lockedReason,
    this.completedBy,
    this.completedDate,
    this.temporaryAccessCode,
    this.temporaryAccessExpiry,
    this.temporaryAccessGrantedBy,
    this.temporaryAccessGrantedTo,
    this.temporaryAccessReason,
    this.createdBy,
    this.lastModifiedBy,
    this.createdAt,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  bool get allStepsComplete =>
      step1MemberInfoComplete &&
      step2Global528Complete &&
      step3Global928Complete &&
      step4LROComplete;

  bool get hasActiveTemporaryAccess {
    final code = temporaryAccessCode;
    final expiry = temporaryAccessExpiry;
    if (code == null || code.isEmpty || expiry == null) return false;
    return expiry.isAfter(DateTime.now().toUtc());
  }

  /// Spec convenience flag — same as [hasActiveTemporaryAccess].
  bool get isTemporaryAccessActive => hasActiveTemporaryAccess;

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
    String? createdBy,
    String registrationStatus = 'pending',
  }) {
    final now = DateTime.now().toUtc();
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
      registrationStatus: registrationStatus,
      registrationDate: now,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
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
    String? userId,
    String? registrationStatus,
    bool? isEmailVerified,
    DateTime? emailVerifiedDate,
    DateTime? registrationDate,
    bool? step1MemberInfoComplete,
    bool? step2Global528Complete,
    bool? step3Global928Complete,
    bool? step4LROComplete,
    DateTime? step1CompletionDate,
    DateTime? step2CompletionDate,
    DateTime? step3CompletionDate,
    DateTime? step4CompletionDate,
    String? step1ApprovedBy,
    String? step2ApprovedBy,
    String? step3ApprovedBy,
    String? step4ApprovedBy,
    bool? isLocked,
    DateTime? lockedDate,
    String? lockedBy,
    String? lockedReason,
    String? completedBy,
    DateTime? completedDate,
    String? temporaryAccessCode,
    DateTime? temporaryAccessExpiry,
    String? temporaryAccessGrantedBy,
    String? temporaryAccessGrantedTo,
    String? temporaryAccessReason,
    String? createdBy,
    String? lastModifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool clearPhotoLocalPath = false,
    bool clearPhotoUrl = false,
    bool clearUserId = false,
    bool clearTemporaryAccess = false,
    bool clearLock = false,
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
      userId: clearUserId ? null : (userId ?? this.userId),
      registrationStatus: registrationStatus ?? this.registrationStatus,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      emailVerifiedDate: emailVerifiedDate ?? this.emailVerifiedDate,
      registrationDate: registrationDate ?? this.registrationDate,
      step1MemberInfoComplete:
          step1MemberInfoComplete ?? this.step1MemberInfoComplete,
      step2Global528Complete:
          step2Global528Complete ?? this.step2Global528Complete,
      step3Global928Complete:
          step3Global928Complete ?? this.step3Global928Complete,
      step4LROComplete: step4LROComplete ?? this.step4LROComplete,
      step1CompletionDate: step1CompletionDate ?? this.step1CompletionDate,
      step2CompletionDate: step2CompletionDate ?? this.step2CompletionDate,
      step3CompletionDate: step3CompletionDate ?? this.step3CompletionDate,
      step4CompletionDate: step4CompletionDate ?? this.step4CompletionDate,
      step1ApprovedBy: step1ApprovedBy ?? this.step1ApprovedBy,
      step2ApprovedBy: step2ApprovedBy ?? this.step2ApprovedBy,
      step3ApprovedBy: step3ApprovedBy ?? this.step3ApprovedBy,
      step4ApprovedBy: step4ApprovedBy ?? this.step4ApprovedBy,
      isLocked: clearLock ? false : (isLocked ?? this.isLocked),
      lockedDate: clearLock ? null : (lockedDate ?? this.lockedDate),
      lockedBy: clearLock ? null : (lockedBy ?? this.lockedBy),
      lockedReason: clearLock ? null : (lockedReason ?? this.lockedReason),
      completedBy: completedBy ?? this.completedBy,
      completedDate: completedDate ?? this.completedDate,
      temporaryAccessCode: clearTemporaryAccess
          ? null
          : (temporaryAccessCode ?? this.temporaryAccessCode),
      temporaryAccessExpiry: clearTemporaryAccess
          ? null
          : (temporaryAccessExpiry ?? this.temporaryAccessExpiry),
      temporaryAccessGrantedBy: clearTemporaryAccess
          ? null
          : (temporaryAccessGrantedBy ?? this.temporaryAccessGrantedBy),
      temporaryAccessGrantedTo: clearTemporaryAccess
          ? null
          : (temporaryAccessGrantedTo ?? this.temporaryAccessGrantedTo),
      temporaryAccessReason: clearTemporaryAccess
          ? null
          : (temporaryAccessReason ?? this.temporaryAccessReason),
      createdBy: createdBy ?? this.createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
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
      'userId': userId,
      'registrationStatus': registrationStatus,
      'isEmailVerified': isEmailVerified ? 1 : 0,
      'emailVerifiedDate': emailVerifiedDate?.toIso8601String(),
      'registrationDate': registrationDate?.toIso8601String(),
      'step1MemberInfoComplete': step1MemberInfoComplete ? 1 : 0,
      'step2Global528Complete': step2Global528Complete ? 1 : 0,
      'step3Global928Complete': step3Global928Complete ? 1 : 0,
      'step4LROComplete': step4LROComplete ? 1 : 0,
      'step1CompletionDate': step1CompletionDate?.toIso8601String(),
      'step2CompletionDate': step2CompletionDate?.toIso8601String(),
      'step3CompletionDate': step3CompletionDate?.toIso8601String(),
      'step4CompletionDate': step4CompletionDate?.toIso8601String(),
      'step1ApprovedBy': step1ApprovedBy,
      'step2ApprovedBy': step2ApprovedBy,
      'step3ApprovedBy': step3ApprovedBy,
      'step4ApprovedBy': step4ApprovedBy,
      'isLocked': isLocked ? 1 : 0,
      'lockedDate': lockedDate?.toIso8601String(),
      'lockedBy': lockedBy,
      'lockedReason': lockedReason,
      'completedBy': completedBy,
      'completedDate': completedDate?.toIso8601String(),
      'temporaryAccessCode': temporaryAccessCode,
      'temporaryAccessExpiry': temporaryAccessExpiry?.toIso8601String(),
      'temporaryAccessGrantedBy': temporaryAccessGrantedBy,
      'temporaryAccessGrantedTo': temporaryAccessGrantedTo,
      'temporaryAccessReason': temporaryAccessReason,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
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
      'userId': userId,
      'registrationStatus': registrationStatus,
      'isEmailVerified': isEmailVerified,
      'emailVerifiedDate': emailVerifiedDate?.toIso8601String(),
      'registrationDate': registrationDate?.toIso8601String(),
      'step1MemberInfoComplete': step1MemberInfoComplete,
      'step2Global528Complete': step2Global528Complete,
      'step3Global928Complete': step3Global928Complete,
      'step4LROComplete': step4LROComplete,
      'step1CompletionDate': step1CompletionDate?.toIso8601String(),
      'step2CompletionDate': step2CompletionDate?.toIso8601String(),
      'step3CompletionDate': step3CompletionDate?.toIso8601String(),
      'step4CompletionDate': step4CompletionDate?.toIso8601String(),
      'step1ApprovedBy': step1ApprovedBy,
      'step2ApprovedBy': step2ApprovedBy,
      'step3ApprovedBy': step3ApprovedBy,
      'step4ApprovedBy': step4ApprovedBy,
      'isLocked': isLocked,
      'lockedDate': lockedDate?.toIso8601String(),
      'lockedBy': lockedBy,
      'lockedReason': lockedReason,
      'completedBy': completedBy,
      'completedDate': completedDate?.toIso8601String(),
      'temporaryAccessCode': temporaryAccessCode,
      'temporaryAccessExpiry': temporaryAccessExpiry?.toIso8601String(),
      'temporaryAccessGrantedBy': temporaryAccessGrantedBy,
      'temporaryAccessGrantedTo': temporaryAccessGrantedTo,
      'temporaryAccessReason': temporaryAccessReason,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'createdAt': createdAt?.toIso8601String(),
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
      userId: map['userId'] as String?,
      registrationStatus:
          map['registrationStatus'] as String? ?? 'pending',
      isEmailVerified: _asBool(map['isEmailVerified']),
      emailVerifiedDate: _asDate(map['emailVerifiedDate']),
      registrationDate: _asDate(map['registrationDate']),
      step1MemberInfoComplete: _asBool(map['step1MemberInfoComplete']),
      step2Global528Complete: _asBool(map['step2Global528Complete']),
      step3Global928Complete: _asBool(map['step3Global928Complete']),
      step4LROComplete: _asBool(map['step4LROComplete']),
      step1CompletionDate: _asDate(map['step1CompletionDate']),
      step2CompletionDate: _asDate(map['step2CompletionDate']),
      step3CompletionDate: _asDate(map['step3CompletionDate']),
      step4CompletionDate: _asDate(map['step4CompletionDate']),
      step1ApprovedBy: map['step1ApprovedBy'] as String?,
      step2ApprovedBy: map['step2ApprovedBy'] as String?,
      step3ApprovedBy: map['step3ApprovedBy'] as String?,
      step4ApprovedBy: map['step4ApprovedBy'] as String?,
      isLocked: _asBool(map['isLocked']),
      lockedDate: _asDate(map['lockedDate']),
      lockedBy: map['lockedBy'] as String?,
      lockedReason: map['lockedReason'] as String?,
      completedBy: map['completedBy'] as String?,
      completedDate: _asDate(map['completedDate']),
      temporaryAccessCode: map['temporaryAccessCode'] as String?,
      temporaryAccessExpiry: _asDate(map['temporaryAccessExpiry']),
      temporaryAccessGrantedBy: map['temporaryAccessGrantedBy'] as String?,
      temporaryAccessGrantedTo: map['temporaryAccessGrantedTo'] as String?,
      temporaryAccessReason: map['temporaryAccessReason'] as String?,
      createdBy: map['createdBy'] as String?,
      lastModifiedBy: map['lastModifiedBy'] as String?,
      createdAt: _asDate(map['createdAt']),
      updatedAt: _asDate(map['updatedAt']) ?? DateTime.now().toUtc(),
      pendingSync: _asBool(map['pendingSync']),
      deleted: _asBool(map['deleted']),
    );
  }

  factory Member.fromFirestore(Map<String, dynamic> map) {
    return Member.fromMap({
      ...map,
      'pendingSync': 0,
      'isEmailVerified': map['isEmailVerified'] == true ? 1 : 0,
      'step1MemberInfoComplete':
          map['step1MemberInfoComplete'] == true ? 1 : 0,
      'step2Global528Complete': map['step2Global528Complete'] == true ? 1 : 0,
      'step3Global928Complete': map['step3Global928Complete'] == true ? 1 : 0,
      'step4LROComplete': map['step4LROComplete'] == true ? 1 : 0,
      'isLocked': map['isLocked'] == true ? 1 : 0,
      'deleted': map['deleted'] == true ? 1 : 0,
    });
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      return v == '1' || v.toLowerCase() == 'true';
    }
    return false;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
    return null;
  }
}
