import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/member_form_mode.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/auth_service.dart';

void main() {
  Member member({
    String status = 'pending',
    bool locked = false,
    String? grantedTo,
    DateTime? expiry,
  }) {
    return Member.create(
      saId: '9001015009087',
      globalRecordNo: 'GTC-0000000001',
      memberName: 'Thabo',
      surname: 'Ndlovu',
      registrationStatus: status,
    ).copyWith(
      isLocked: locked,
      temporaryAccessCode: grantedTo == null ? null : '12345',
      temporaryAccessExpiry: expiry,
      temporaryAccessGrantedTo: grantedTo,
    );
  }

  const admin = AuthUser(
    id: 'demo-admin',
    displayName: 'Admin',
    username: 'admin',
    role: 'Admin',
  );
  const secretary = AuthUser(
    id: 'sec-1',
    displayName: 'Jane',
    username: 'jane',
    role: 'Recording Secretary',
    permissions: [AppPermission.memberInfo],
  );
  const memberUser = AuthUser(
    id: 'mem-1',
    displayName: 'Member',
    username: 'member',
    role: 'Member',
  );

  group('determineMemberFormMode', () {
    test('admin + pending → newMember', () {
      expect(
        determineMemberFormMode(
          member: member(),
          user: admin,
          sessionVerifiedTempAccess: false,
        ),
        MemberFormMode.newMember,
      );
    });

    test('admin + locked → lockedAdmin', () {
      expect(
        determineMemberFormMode(
          member: member(status: 'fully_fledged', locked: true),
          user: admin,
          sessionVerifiedTempAccess: false,
        ),
        MemberFormMode.lockedAdmin,
      );
    });

    test('admin + complete unlocked → regularMember', () {
      expect(
        determineMemberFormMode(
          member: member(status: 'complete'),
          user: admin,
          sessionVerifiedTempAccess: false,
        ),
        MemberFormMode.regularMember,
      );
    });

    test('secretary + locked without session → lockedSecretary', () {
      expect(
        determineMemberFormMode(
          member: member(status: 'fully_fledged', locked: true),
          user: secretary,
          sessionVerifiedTempAccess: false,
        ),
        MemberFormMode.lockedSecretary,
      );
    });

    test('secretary + locked with valid temp session → tempAccessActive', () {
      final m = member(
        status: 'fully_fledged',
        locked: true,
        grantedTo: 'sec-1',
        expiry: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      expect(
        determineMemberFormMode(
          member: m,
          user: secretary,
          sessionVerifiedTempAccess: true,
        ),
        MemberFormMode.tempAccessActive,
      );
    });

    test('member role → regularMember (read-only enforced elsewhere)', () {
      expect(
        determineMemberFormMode(
          member: member(status: 'complete'),
          user: memberUser,
          sessionVerifiedTempAccess: false,
        ),
        MemberFormMode.regularMember,
      );
    });

    test('null member draft → newMember', () {
      expect(
        determineMemberFormMode(
          member: null,
          user: secretary,
          sessionVerifiedTempAccess: false,
        ),
        MemberFormMode.newMember,
      );
    });

    test('mode flags for checklist / edit', () {
      expect(MemberFormMode.newMember.showOnboardingChecklist, isTrue);
      expect(MemberFormMode.newMember.showCompleteButton, isTrue);
      expect(MemberFormMode.regularMember.showOnboardingChecklist, isFalse);
      expect(MemberFormMode.lockedSecretary.canEditFields, isFalse);
      expect(MemberFormMode.lockedAdmin.canEditFields, isTrue);
      expect(MemberFormMode.lockedAdmin.checklistReadOnly, isTrue);
      expect(MemberFormMode.tempAccessActive.canEditFields, isTrue);
    });
  });
}
