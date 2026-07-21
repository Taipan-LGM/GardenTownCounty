import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/member_lock_service.dart';

void main() {
  group('Member lock & temporary access', () {
    test('create defaults unlocked with pending registration', () {
      final member = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
      );
      expect(member.isLocked, isFalse);
      expect(member.registrationStatus, 'pending');
      expect(member.hasActiveTemporaryAccess, isFalse);
    });

    test('round-trips lock fields through map', () {
      final now = DateTime.now().toUtc();
      final member = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
      ).copyWith(
        isLocked: true,
        lockedDate: now,
        lockedBy: 'demo-admin',
        temporaryAccessCode: '83742',
        temporaryAccessExpiry: now.add(const Duration(hours: 1)),
        temporaryAccessGrantedTo: 'sec-1',
        step1MemberInfoComplete: true,
        step2Global528Complete: true,
        step3Global928Complete: true,
        step4LROComplete: true,
        registrationStatus: 'fully_fledged',
      );
      final restored = Member.fromMap(member.toMap());
      expect(restored.isLocked, isTrue);
      expect(restored.temporaryAccessCode, '83742');
      expect(restored.allStepsComplete, isTrue);
      expect(restored.hasActiveTemporaryAccess, isTrue);
      expect(restored.toFirestore()['isLocked'], isTrue);
    });

    test('TemporaryAccessService.isGrantValidFor checks assignee + expiry', () {
      final member = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
      ).copyWith(
        isLocked: true,
        temporaryAccessCode: '12345',
        temporaryAccessExpiry:
            DateTime.now().toUtc().add(const Duration(hours: 1)),
        temporaryAccessGrantedTo: 'sec-1',
      );
      expect(TemporaryAccessService.isGrantValidFor(member, 'sec-1'), isTrue);
      expect(TemporaryAccessService.isGrantValidFor(member, 'other'), isFalse);

      final expired = member.copyWith(
        temporaryAccessExpiry:
            DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      expect(TemporaryAccessService.isGrantValidFor(expired, 'sec-1'), isFalse);
    });

    test('canEditMember pure rules for admin / lock / temp session', () {
      final unlocked = Member.create(
        saId: '9001015009087',
        globalRecordNo: 'GTC-0000000001',
        memberName: 'Thabo',
        surname: 'Ndlovu',
      );
      final locked = unlocked.copyWith(
        isLocked: true,
        temporaryAccessCode: '12345',
        temporaryAccessExpiry:
            DateTime.now().toUtc().add(const Duration(hours: 1)),
        temporaryAccessGrantedTo: 'sec-1',
      );

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

      bool canEdit({
        required Member member,
        required AuthUser? user,
        required bool sessionVerifiedTempAccess,
      }) {
        if (user == null) return false;
        if (user.isAdmin) return true;
        if (!user.hasPermission(AppPermission.memberInfo)) return false;
        if (!member.isLocked) return true;
        return sessionVerifiedTempAccess &&
            TemporaryAccessService.isGrantValidFor(member, user.id);
      }

      expect(
        canEdit(
          member: unlocked,
          user: secretary,
          sessionVerifiedTempAccess: false,
        ),
        isTrue,
      );
      expect(
        canEdit(
          member: locked,
          user: secretary,
          sessionVerifiedTempAccess: false,
        ),
        isFalse,
      );
      expect(
        canEdit(
          member: locked,
          user: secretary,
          sessionVerifiedTempAccess: true,
        ),
        isTrue,
      );
      expect(
        canEdit(
          member: locked,
          user: admin,
          sessionVerifiedTempAccess: false,
        ),
        isTrue,
      );
    });
  });
}
