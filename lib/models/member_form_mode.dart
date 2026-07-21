import 'member.dart';
import '../services/auth_service.dart';
import '../services/temporary_access_service.dart';

/// Smart Member Info form modes (single unified form).
enum MemberFormMode {
  /// Pending / in_progress — editable + onboarding checklist.
  newMember,

  /// Unlocked complete — editable, no checklist.
  regularMember,

  /// Locked — secretary read-only + temp access entry.
  lockedSecretary,

  /// Locked — admin editable + temp access management.
  lockedAdmin,

  /// Locked — secretary editable via verified temp access.
  tempAccessActive,
}

extension MemberFormModeX on MemberFormMode {
  bool get canEditFields {
    switch (this) {
      case MemberFormMode.newMember:
      case MemberFormMode.regularMember:
      case MemberFormMode.lockedAdmin:
      case MemberFormMode.tempAccessActive:
        return true;
      case MemberFormMode.lockedSecretary:
        return false;
    }
  }

  bool get showOnboardingChecklist {
    switch (this) {
      case MemberFormMode.newMember:
      case MemberFormMode.lockedAdmin:
        return true;
      case MemberFormMode.regularMember:
      case MemberFormMode.lockedSecretary:
      case MemberFormMode.tempAccessActive:
        return false;
    }
  }

  bool get checklistReadOnly => this == MemberFormMode.lockedAdmin;

  bool get showCompleteButton => this == MemberFormMode.newMember;

  bool get showTempAccessSection {
    switch (this) {
      case MemberFormMode.lockedSecretary:
      case MemberFormMode.lockedAdmin:
      case MemberFormMode.tempAccessActive:
        return true;
      case MemberFormMode.newMember:
      case MemberFormMode.regularMember:
        return false;
    }
  }

  String get statusLabel {
    switch (this) {
      case MemberFormMode.newMember:
        return 'Onboarding';
      case MemberFormMode.regularMember:
        return 'Active';
      case MemberFormMode.lockedSecretary:
      case MemberFormMode.lockedAdmin:
        return 'Locked';
      case MemberFormMode.tempAccessActive:
        return 'Temp Access';
    }
  }
}

/// Resolve which of the 5 smart-form modes applies.
MemberFormMode determineMemberFormMode({
  required Member? member,
  required AuthUser? user,
  required bool sessionVerifiedTempAccess,
}) {
  if (user == null) return MemberFormMode.regularMember;

  // Unsaved draft / new blank form.
  if (member == null) return MemberFormMode.newMember;

  if (user.isAdmin) {
    if (member.isLocked) return MemberFormMode.lockedAdmin;
    if (_isNewRegistration(member)) return MemberFormMode.newMember;
    return MemberFormMode.regularMember;
  }

  // Members (non-staff): view profile only — treat as regular (read-only elsewhere).
  if (user.isMemberRole) {
    return MemberFormMode.regularMember;
  }

  if (member.isLocked) {
    if (sessionVerifiedTempAccess &&
        TemporaryAccessService.isGrantValidFor(member, user.id)) {
      return MemberFormMode.tempAccessActive;
    }
    return MemberFormMode.lockedSecretary;
  }

  if (_isNewRegistration(member)) return MemberFormMode.newMember;
  return MemberFormMode.regularMember;
}

bool _isNewRegistration(Member member) {
  final s = member.registrationStatus;
  return s == 'pending' || s == 'in_progress';
}
