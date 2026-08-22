import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Member profile with registration, lock, and temporary-access fields.
class Member {
  final String id;
  final String saId;
  final String globalRecordNo;

  /// NEW ADDITION - LRO Record No. (max 14). Delete field + usages to revert.
  final String? lroRecordNo;
  /// NEW ADDITION - Personalized LRO Public Notice image (data URI) saved
  /// to the right of the Member's photo as a permanent record.
  final String? lroNoticeImageBase64;
  /// NEW ADDITION - When the Personal Public Notice was published via the
  /// "LRO Publication" button (null until published).
  final DateTime? lroPublicationDate;
  /// NEW ADDITION - The Recording Secretary / Admin who published the notice.
  final String? lroPublishedBy;
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
  final String
  registrationStatus; // pending | in_progress | complete | fully_fledged
  final bool isEmailVerified;
  final DateTime? emailVerifiedDate;
  final DateTime? registrationDate;

  // 5-step onboarding completion
  final bool step1MemberInfoComplete;
  final bool step2Global528Complete;
  final bool step3Global928Complete;
  final bool step4LROComplete;
  final bool step5CredentialCardComplete;
  final DateTime? step1CompletionDate;
  final DateTime? step2CompletionDate;
  final DateTime? step3CompletionDate;
  final DateTime? step4CompletionDate;
  final DateTime? step5CompletionDate;
  final String? step1ApprovedBy;
  final String? step2ApprovedBy;
  final String? step3ApprovedBy;
  final String? step4ApprovedBy;
  final String? step5ApprovedBy;
  final Map<int, MemberStepState> additionalStepStates;

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

  // NEW ADDITION - soft cancellation (no permanent delete)
  final bool isCancelled;
  final DateTime? cancellationDate;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime? reinstatedDate;
  final String? reinstatedBy;

  // NEW ADDITION - RS assignment (Delete fields + usages to revert)
  final String? assignedSecretaryId;
  final String? assignedSecretaryName;
  final DateTime? assignedDate;
  final String? assignedBy;
  final String? assignmentMethod; // manual | auto

  // Audit
  final String? createdBy;
  final String? lastModifiedBy;
  final DateTime? createdAt;

  /// Multi-county tenancy: every member belongs to exactly one county.
  final String countyId;

  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const Member({
    required this.id,
    required this.saId,
    required this.globalRecordNo,
    this.lroRecordNo,
    this.lroNoticeImageBase64,
    this.lroPublicationDate,
    this.lroPublishedBy,
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
    this.step5CredentialCardComplete = false,
    this.step1CompletionDate,
    this.step2CompletionDate,
    this.step3CompletionDate,
    this.step4CompletionDate,
    this.step5CompletionDate,
    this.step1ApprovedBy,
    this.step2ApprovedBy,
    this.step3ApprovedBy,
    this.step4ApprovedBy,
    this.step5ApprovedBy,
    this.additionalStepStates = const {},
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
    this.isCancelled = false,
    this.cancellationDate,
    this.cancelledBy,
    this.cancellationReason,
    this.reinstatedDate,
    this.reinstatedBy,
    // NEW ADDITION - RS assignment
    this.assignedSecretaryId,
    this.assignedSecretaryName,
    this.assignedDate,
    this.assignedBy,
    this.assignmentMethod,
    this.createdBy,
    this.lastModifiedBy,
    this.createdAt,
    this.countyId = '',
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  int get totalStepCount => 5 + additionalStepStates.length;

  int get completedStepCount =>
      [
        step1MemberInfoComplete,
        step2Global528Complete,
        step3Global928Complete,
        step4LROComplete,
        step5CredentialCardComplete,
      ].where((value) => value).length +
      additionalStepStates.values.where((state) => state.complete).length;

  bool get allStepsComplete =>
      step1MemberInfoComplete &&
      step2Global528Complete &&
      step3Global928Complete &&
      step4LROComplete &&
      step5CredentialCardComplete;

  bool isStepCompleteAt(int step) => switch (step) {
    1 => step1MemberInfoComplete,
    2 => step2Global528Complete,
    3 => step3Global928Complete,
    4 => step4LROComplete,
    5 => step5CredentialCardComplete,
    _ => additionalStepStates[step]?.complete ?? false,
  };

  int completedStepCountFor(Iterable<int> stepNumbers) =>
      stepNumbers.where(isStepCompleteAt).length;

  bool allStepsCompleteFor(Iterable<int> stepNumbers) {
    final numbers = stepNumbers.toList();
    return numbers.isNotEmpty && numbers.every(isStepCompleteAt);
  }

  Member withStepState({
    required int step,
    required bool complete,
    required DateTime changedAt,
    required String approvedBy,
  }) {
    if (step <= 5) {
      return copyWith(
        step1MemberInfoComplete: step == 1 ? complete : null,
        step2Global528Complete: step == 2 ? complete : null,
        step3Global928Complete: step == 3 ? complete : null,
        step4LROComplete: step == 4 ? complete : null,
        step5CredentialCardComplete: step == 5 ? complete : null,
        step1CompletionDate: step == 1 && complete ? changedAt : null,
        step2CompletionDate: step == 2 && complete ? changedAt : null,
        step3CompletionDate: step == 3 && complete ? changedAt : null,
        step4CompletionDate: step == 4 && complete ? changedAt : null,
        step5CompletionDate: step == 5 && complete ? changedAt : null,
        step1ApprovedBy: step == 1 && complete ? approvedBy : null,
        step2ApprovedBy: step == 2 && complete ? approvedBy : null,
        step3ApprovedBy: step == 3 && complete ? approvedBy : null,
        step4ApprovedBy: step == 4 && complete ? approvedBy : null,
        step5ApprovedBy: step == 5 && complete ? approvedBy : null,
      );
    }
    return copyWith(
      additionalStepStates: {
        ...additionalStepStates,
        step: MemberStepState(
          complete: complete,
          completionDate: complete ? changedAt : null,
          approvedBy: complete ? approvedBy : null,
        ),
      },
    );
  }

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
    String? lroRecordNo,
    String? lroNoticeImageBase64,
    String registrationStatus = 'pending',
    String countyId = '',
  }) {
    final now = DateTime.now().toUtc();
    return Member(
      id: const Uuid().v4(),
      saId: saId,
      globalRecordNo: globalRecordNo,
      lroRecordNo: lroRecordNo,
      lroNoticeImageBase64: lroNoticeImageBase64,
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
      countyId: countyId,
      updatedAt: now,
      pendingSync: true,
    );
  }

  Member copyWith({
    String? id,
    String? saId,
    String? globalRecordNo,
    String? lroRecordNo,
    String? lroNoticeImageBase64,
    DateTime? lroPublicationDate,
    String? lroPublishedBy,
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
    bool? step5CredentialCardComplete,
    DateTime? step1CompletionDate,
    DateTime? step2CompletionDate,
    DateTime? step3CompletionDate,
    DateTime? step4CompletionDate,
    DateTime? step5CompletionDate,
    String? step1ApprovedBy,
    String? step2ApprovedBy,
    String? step3ApprovedBy,
    String? step4ApprovedBy,
    String? step5ApprovedBy,
    Map<int, MemberStepState>? additionalStepStates,
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
    bool? isCancelled,
    DateTime? cancellationDate,
    String? cancelledBy,
    String? cancellationReason,
    DateTime? reinstatedDate,
    String? reinstatedBy,
    // NEW ADDITION - RS assignment
    String? assignedSecretaryId,
    String? assignedSecretaryName,
    DateTime? assignedDate,
    String? assignedBy,
    String? assignmentMethod,
    String? createdBy,
    String? lastModifiedBy,
    DateTime? createdAt,
    String? countyId,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool clearPhotoLocalPath = false,
    bool clearPhotoUrl = false,
    bool clearUserId = false,
    bool clearTemporaryAccess = false,
    bool clearLock = false,
    bool clearSecretaryAssignment = false,
    bool clearLroRecordNo = false,
    bool clearLroNoticeImage = false,
    bool clearLroPublication = false,
    bool clearCancellation = false,
  }) {
    return Member(
      id: id ?? this.id,
      saId: saId ?? this.saId,
      globalRecordNo: globalRecordNo ?? this.globalRecordNo,
      lroRecordNo: clearLroRecordNo ? null : (lroRecordNo ?? this.lroRecordNo),
      lroNoticeImageBase64:
          clearLroNoticeImage ? null : (lroNoticeImageBase64 ?? this.lroNoticeImageBase64),
      lroPublicationDate: clearLroPublication
          ? null
          : (lroPublicationDate ?? this.lroPublicationDate),
      lroPublishedBy:
          clearLroPublication ? null : (lroPublishedBy ?? this.lroPublishedBy),
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
      photoLocalPath: clearPhotoLocalPath
          ? null
          : (photoLocalPath ?? this.photoLocalPath),
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
      step5CredentialCardComplete:
          step5CredentialCardComplete ?? this.step5CredentialCardComplete,
      step1CompletionDate: step1CompletionDate ?? this.step1CompletionDate,
      step2CompletionDate: step2CompletionDate ?? this.step2CompletionDate,
      step3CompletionDate: step3CompletionDate ?? this.step3CompletionDate,
      step4CompletionDate: step4CompletionDate ?? this.step4CompletionDate,
      step5CompletionDate: step5CompletionDate ?? this.step5CompletionDate,
      step1ApprovedBy: step1ApprovedBy ?? this.step1ApprovedBy,
      step2ApprovedBy: step2ApprovedBy ?? this.step2ApprovedBy,
      step3ApprovedBy: step3ApprovedBy ?? this.step3ApprovedBy,
      step4ApprovedBy: step4ApprovedBy ?? this.step4ApprovedBy,
      step5ApprovedBy: step5ApprovedBy ?? this.step5ApprovedBy,
      additionalStepStates: additionalStepStates ?? this.additionalStepStates,
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
      isCancelled: clearCancellation
          ? false
          : (isCancelled ?? this.isCancelled),
      cancellationDate: clearCancellation
          ? null
          : (cancellationDate ?? this.cancellationDate),
      cancelledBy: clearCancellation ? null : (cancelledBy ?? this.cancelledBy),
      cancellationReason: clearCancellation
          ? null
          : (cancellationReason ?? this.cancellationReason),
      reinstatedDate: reinstatedDate ?? this.reinstatedDate,
      reinstatedBy: reinstatedBy ?? this.reinstatedBy,
      // NEW ADDITION - RS assignment
      assignedSecretaryId: clearSecretaryAssignment
          ? null
          : (assignedSecretaryId ?? this.assignedSecretaryId),
      assignedSecretaryName: clearSecretaryAssignment
          ? null
          : (assignedSecretaryName ?? this.assignedSecretaryName),
      assignedDate: clearSecretaryAssignment
          ? null
          : (assignedDate ?? this.assignedDate),
      assignedBy: clearSecretaryAssignment
          ? null
          : (assignedBy ?? this.assignedBy),
      assignmentMethod: clearSecretaryAssignment
          ? null
          : (assignmentMethod ?? this.assignmentMethod),
      createdBy: createdBy ?? this.createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      countyId: countyId ?? this.countyId,
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
      'lroRecordNo': lroRecordNo,
      'lroNoticeImageBase64': lroNoticeImageBase64,
      'lroPublicationDate': lroPublicationDate?.toIso8601String(),
      'lroPublishedBy': lroPublishedBy,
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
      'step5CredentialCardComplete': step5CredentialCardComplete ? 1 : 0,
      'step1CompletionDate': step1CompletionDate?.toIso8601String(),
      'step2CompletionDate': step2CompletionDate?.toIso8601String(),
      'step3CompletionDate': step3CompletionDate?.toIso8601String(),
      'step4CompletionDate': step4CompletionDate?.toIso8601String(),
      'step5CompletionDate': step5CompletionDate?.toIso8601String(),
      'step1ApprovedBy': step1ApprovedBy,
      'step2ApprovedBy': step2ApprovedBy,
      'step3ApprovedBy': step3ApprovedBy,
      'step4ApprovedBy': step4ApprovedBy,
      'step5ApprovedBy': step5ApprovedBy,
      'memberStepsJson': MemberStepState.encodeMap(additionalStepStates),
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
      'isCancelled': isCancelled ? 1 : 0,
      'cancellationDate': cancellationDate?.toIso8601String(),
      'cancelledBy': cancelledBy,
      'cancellationReason': cancellationReason,
      'reinstatedDate': reinstatedDate?.toIso8601String(),
      'reinstatedBy': reinstatedBy,
      // NEW ADDITION - RS assignment
      'assignedSecretaryId': assignedSecretaryId,
      'assignedSecretaryName': assignedSecretaryName,
      'assignedDate': assignedDate?.toIso8601String(),
      'assignedBy': assignedBy,
      'assignmentMethod': assignmentMethod,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'countyId': countyId,
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
      'lroRecordNo': lroRecordNo,
      'lroNoticeImageBase64': lroNoticeImageBase64,
      'lroPublicationDate': lroPublicationDate?.toIso8601String(),
      'lroPublishedBy': lroPublishedBy,
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
      'step5CredentialCardComplete': step5CredentialCardComplete,
      'step1CompletionDate': step1CompletionDate?.toIso8601String(),
      'step2CompletionDate': step2CompletionDate?.toIso8601String(),
      'step3CompletionDate': step3CompletionDate?.toIso8601String(),
      'step4CompletionDate': step4CompletionDate?.toIso8601String(),
      'step5CompletionDate': step5CompletionDate?.toIso8601String(),
      'step1ApprovedBy': step1ApprovedBy,
      'step2ApprovedBy': step2ApprovedBy,
      'step3ApprovedBy': step3ApprovedBy,
      'step4ApprovedBy': step4ApprovedBy,
      'step5ApprovedBy': step5ApprovedBy,
      'memberStepsJson': MemberStepState.encodeMap(additionalStepStates),
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
      'isCancelled': isCancelled,
      'cancellationDate': cancellationDate?.toIso8601String(),
      'cancelledBy': cancelledBy,
      'cancellationReason': cancellationReason,
      'reinstatedDate': reinstatedDate?.toIso8601String(),
      'reinstatedBy': reinstatedBy,
      // NEW ADDITION - RS assignment
      'assignedSecretaryId': assignedSecretaryId,
      'assignedSecretaryName': assignedSecretaryName,
      'assignedDate': assignedDate?.toIso8601String(),
      'assignedBy': assignedBy,
      'assignmentMethod': assignmentMethod,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'countyId': countyId,
      'deleted': deleted,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      saId: map['saId'] as String? ?? '',
      globalRecordNo: map['globalRecordNo'] as String? ?? '',
      lroRecordNo: map['lroRecordNo'] as String?,
      lroNoticeImageBase64: map['lroNoticeImageBase64'] as String?,
      lroPublicationDate: _asDate(map['lroPublicationDate']),
      lroPublishedBy: map['lroPublishedBy'] as String?,
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
      registrationStatus: map['registrationStatus'] as String? ?? 'pending',
      isEmailVerified: _asBool(map['isEmailVerified']),
      emailVerifiedDate: _asDate(map['emailVerifiedDate']),
      registrationDate: _asDate(map['registrationDate']),
      step1MemberInfoComplete: _asBool(map['step1MemberInfoComplete']),
      step2Global528Complete: _asBool(map['step2Global528Complete']),
      step3Global928Complete: _asBool(map['step3Global928Complete']),
      step4LROComplete: _asBool(map['step4LROComplete']),
      step5CredentialCardComplete: _asBool(map['step5CredentialCardComplete']),
      step1CompletionDate: _asDate(map['step1CompletionDate']),
      step2CompletionDate: _asDate(map['step2CompletionDate']),
      step3CompletionDate: _asDate(map['step3CompletionDate']),
      step4CompletionDate: _asDate(map['step4CompletionDate']),
      step5CompletionDate: _asDate(map['step5CompletionDate']),
      step1ApprovedBy: map['step1ApprovedBy'] as String?,
      step2ApprovedBy: map['step2ApprovedBy'] as String?,
      step3ApprovedBy: map['step3ApprovedBy'] as String?,
      step4ApprovedBy: map['step4ApprovedBy'] as String?,
      step5ApprovedBy: map['step5ApprovedBy'] as String?,
      additionalStepStates: MemberStepState.decodeMap(
        map['memberStepsJson'] as String? ?? '{}',
      ),
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
      isCancelled: _asBool(map['isCancelled']),
      cancellationDate: _asDate(map['cancellationDate']),
      cancelledBy: map['cancelledBy'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      reinstatedDate: _asDate(map['reinstatedDate']),
      reinstatedBy: map['reinstatedBy'] as String?,
      // NEW ADDITION - RS assignment
      assignedSecretaryId: map['assignedSecretaryId'] as String?,
      assignedSecretaryName: map['assignedSecretaryName'] as String?,
      assignedDate: _asDate(map['assignedDate']),
      assignedBy: map['assignedBy'] as String?,
      assignmentMethod: map['assignmentMethod'] as String?,
      createdBy: map['createdBy'] as String?,
      lastModifiedBy: map['lastModifiedBy'] as String?,
      createdAt: _asDate(map['createdAt']),
      countyId: map['countyId'] as String? ?? '',
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
      'step1MemberInfoComplete': map['step1MemberInfoComplete'] == true ? 1 : 0,
      'step2Global528Complete': map['step2Global528Complete'] == true ? 1 : 0,
      'step3Global928Complete': map['step3Global928Complete'] == true ? 1 : 0,
      'step4LROComplete': map['step4LROComplete'] == true ? 1 : 0,
      'step5CredentialCardComplete': map['step5CredentialCardComplete'] == true
          ? 1
          : 0,
      'isLocked': map['isLocked'] == true ? 1 : 0,
      'isCancelled': map['isCancelled'] == true ? 1 : 0,
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

class MemberStepState {
  const MemberStepState({
    required this.complete,
    this.completionDate,
    this.approvedBy,
  });

  final bool complete;
  final DateTime? completionDate;
  final String? approvedBy;

  Map<String, dynamic> toJson() => {
    'complete': complete,
    'completionDate': completionDate?.toIso8601String(),
    'approvedBy': approvedBy,
  };

  static String encodeMap(Map<int, MemberStepState> states) => jsonEncode(
    states.map((number, state) => MapEntry('$number', state.toJson())),
  );

  static Map<int, MemberStepState> decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((number, value) {
        final json = value as Map<String, dynamic>;
        return MapEntry(
          int.parse(number),
          MemberStepState(
            complete: json['complete'] == true,
            completionDate: DateTime.tryParse(
              json['completionDate'] as String? ?? '',
            )?.toUtc(),
            approvedBy: json['approvedBy'] as String?,
          ),
        );
      });
    } catch (_) {
      return const {};
    }
  }
}
