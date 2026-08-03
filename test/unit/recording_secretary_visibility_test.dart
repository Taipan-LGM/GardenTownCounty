import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/data_access_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DatabaseService db;
  late DataAccessService access;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService.instance;
    await db.initForTests();
    access = DataAccessService(db);
    await db.upsertAppUser(
      AppUser(
        id: 'demo-admin',
        username: AppConstants.demoUsername,
        displayName: 'Admin',
        passwordHash: PasswordHasher.hash(AppConstants.demoPassword),
        role: UserRole.admin.storageName,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  });

  test('Admin sees Recording Secretary members after link ensure', () async {
    await db.upsertAppUser(
      AppUser(
        id: 'sec_orphan',
        username: 'orphan.rs',
        displayName: 'Orphan Secretary',
        passwordHash: PasswordHasher.hash('garden2026'),
        role: UserRole.secretary.storageName,
        permissionsRaw:
            AppPermission.encodeList(AppPermission.defaultSecretary),
        updatedAt: DateTime.now().toUtc(),
        active: true,
      ),
    );

    await db.ensureRecordingSecretaryMemberLinks();

    final admin = AuthUser.fromAppUser(
      (await db.getAppUserById('demo-admin'))!,
    );
    final visible = await access.getVisibleMembers(admin);
    final linked = await db.getAppUserById('sec_orphan');

    expect(linked?.memberId, isNotNull);
    expect(linked!.memberId, isNotEmpty);
    expect(
      visible.any((m) => m.id == linked.memberId),
      isTrue,
      reason: 'Admin Member List must include RS-linked members',
    );
  });

  test('role visibility enforces self, assignment, and Step 5 cutoff', () async {
    final now = DateTime.now().toUtc();
    for (final member in [
      Member(
        id: 'rs-own',
        saId: '9000000000001',
        globalRecordNo: 'RS-OWN',
        memberName: 'Jane',
        surname: 'Secretary',
        userId: 'rs-user',
        updatedAt: now,
      ),
      Member(
        id: 'assigned-active',
        saId: '9000000000002',
        globalRecordNo: 'ASSIGNED-ACTIVE',
        memberName: 'Active',
        surname: 'Member',
        assignedSecretaryId: 'rs-user',
        updatedAt: now,
      ),
      Member(
        id: 'assigned-complete',
        saId: '9000000000003',
        globalRecordNo: 'ASSIGNED-COMPLETE',
        memberName: 'Completed',
        surname: 'Member',
        assignedSecretaryId: 'rs-user',
        step5CredentialCardComplete: true,
        updatedAt: now,
      ),
      Member(
        id: 'member-own',
        saId: '9000000000004',
        globalRecordNo: 'MEMBER-OWN',
        memberName: 'Ordinary',
        surname: 'Member',
        userId: 'member-user',
        updatedAt: now,
      ),
    ]) {
      await db.upsertMember(member);
    }

    const secretary = AuthUser(
      id: 'rs-user',
      username: 'rs',
      displayName: 'Jane Secretary',
      role: 'Recording Secretary',
      memberId: 'rs-own',
    );
    const memberUser = AuthUser(
      id: 'member-user',
      username: 'member',
      displayName: 'Ordinary Member',
      role: 'Member',
      memberId: 'member-own',
    );
    final admin = AuthUser.fromAppUser(
      (await db.getAppUserById('demo-admin'))!,
    );

    expect(
      (await access.getVisibleMembers(secretary)).map((member) => member.id),
      containsAll(['rs-own', 'assigned-active']),
    );
    expect(
      (await access.getVisibleMembers(secretary)).map((member) => member.id),
      isNot(contains('assigned-complete')),
    );
    expect(await access.canAccessMember(secretary, 'assigned-complete'), isFalse);
    expect(await access.canAccessMember(secretary, 'rs-own'), isTrue);
    expect(
      (await access.getVisibleMembers(memberUser)).map((member) => member.id),
      ['member-own'],
    );
    expect(memberUser.hasPermission(AppPermission.memberInfo), isTrue);
    expect(memberUser.hasPermission(AppPermission.global528), isTrue);
    expect(memberUser.hasPermission(AppPermission.activities), isFalse);
    expect(
      (await access.getVisibleMembers(admin)).map((member) => member.id),
      contains('assigned-complete'),
    );
  });
}
