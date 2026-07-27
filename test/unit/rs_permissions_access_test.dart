import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/activity_service.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/data_access_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:garden_town_county/services/promotion_service.dart';
import 'package:garden_town_county/services/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DatabaseService db;
  late AuthService auth;
  late DataAccessService access;
  late PromotionService promotion;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService.instance;
    await db.initForTests();
    auth = AuthService(db);
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
    await auth.signIn(
      usernameOrEmail: AppConstants.demoUsername,
      password: AppConstants.demoPassword,
    );
    promotion = PromotionService(
      auth,
      db,
      ActivityService(db, SyncEngine(db)),
    );
  });

  group('AppPermission secretary defaults', () {
    test('default includes core drawer modules for secretaries', () {
      expect(AppPermission.defaultSecretary, hasLength(11));
      expect(AppPermission.defaultSecretary.contains(AppPermission.sos), isTrue);
      expect(
        AppPermission.defaultSecretary.contains(AppPermission.reminders),
        isTrue,
      );
      expect(
        AppPermission.defaultSecretary.contains(AppPermission.global528Step2),
        isTrue,
      );
      expect(
        AppPermission.defaultSecretary.contains(AppPermission.credentialCard),
        isTrue,
      );
    });

    test('merge strips admin-only and does not force defaults', () {
      final merged = AppPermission.mergeSecretaryPermissions([
        AppPermission.onboarding,
        AppPermission.backupRestore,
      ]);
      expect(merged, contains(AppPermission.onboarding));
      expect(merged, isNot(contains(AppPermission.backupRestore)));
      expect(merged, isNot(contains(AppPermission.search)));
    });

    test('admin can clear a default secretary right', () {
      final merged = AppPermission.mergeSecretaryPermissions([
        AppPermission.search,
        AppPermission.memberInfo,
      ]);
      expect(merged, contains(AppPermission.search));
      expect(merged, contains(AppPermission.memberInfo));
      expect(merged, isNot(contains(AppPermission.sos)));
      expect(merged, isNot(contains(AppPermission.reminders)));
    });
  });

  group('DataAccessService', () {
    test('secretary only sees assigned members', () async {
      final now = DateTime.now().toUtc();
      final member = Member(
        id: 'm_own',
        saId: '9001014800089',
        globalRecordNo: 'G1',
        memberName: 'Own',
        surname: 'One',
        updatedAt: now,
      );
      final other = Member(
        id: 'm_other',
        saId: '8502155800085',
        globalRecordNo: 'G2',
        memberName: 'Other',
        surname: 'Two',
        updatedAt: now,
      );
      await db.upsertMember(member);
      await db.upsertMember(other);

      final secUser = await promotion.promoteToRecordingSecretary(
        member: member,
        admin: auth.currentUser!,
      );
      await db.assignSecretaryToMember(
        memberId: other.id,
        secretaryId: secUser.id,
      );

      // Unassigned member visible only to admin
      final adminVisible = await access.getVisibleMembers(auth.currentUser);
      expect(adminVisible.length, greaterThanOrEqualTo(2));

      final secAuth = AuthUser.fromAppUser(secUser);
      final secVisible = await access.getVisibleMembers(secAuth);
      expect(secVisible.map((m) => m.id), [other.id]);
      expect(secVisible.any((m) => m.id == member.id), isFalse);
    });
  });

  group('PromotionService defaults', () {
    test('promote grants default secretary permissions only', () async {
      final now = DateTime.now().toUtc();
      final member = Member(
        id: 'm_promo2',
        saId: '9101014800087',
        globalRecordNo: 'G3',
        memberName: 'Jane',
        surname: 'Smith',
        updatedAt: now,
      );
      await db.upsertMember(member);
      final user = await promotion.promoteToRecordingSecretary(
        member: member,
        admin: auth.currentUser!,
      );
      expect(user.permissions, AppPermission.defaultSecretary);
      expect(user.hasPermission(AppPermission.sos), isTrue);
      expect(user.hasPermission(AppPermission.memberInfo), isTrue);
      expect(user.hasPermission(AppPermission.backupRestore), isFalse);
    });
  });

  group('AuthService.updateSecretaryPermissions', () {
    test('saves optional rights without memberId link', () async {
      final now = DateTime.now().toUtc();
      final unlinked = AppUser(
        id: 'sec_unlinked',
        username: 'jane.demo',
        displayName: 'Jane Demo',
        passwordHash: PasswordHasher.hash('x'),
        role: UserRole.secretary.storageName,
        permissionsRaw:
            AppPermission.encodeList(AppPermission.defaultSecretary),
        updatedAt: now,
      );
      await db.upsertAppUser(unlinked);

      final saved = await auth.updateSecretaryPermissions(
        userId: unlinked.id,
        permissions: [
          ...AppPermission.defaultSecretary,
          AppPermission.sos,
          AppPermission.activities,
        ],
      );

      expect(saved.permissions, contains(AppPermission.sos));
      expect(saved.permissions, contains(AppPermission.activities));
      expect(saved.permissions, contains(AppPermission.search));
      expect(saved.permissions, isNot(contains(AppPermission.backupRestore)));

      final reloaded = await db.getAppUserById(unlinked.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.permissions, contains(AppPermission.sos));
      expect(reloaded.permissions, contains(AppPermission.activities));
    });

    test('toggling optional off persists after reload', () async {
      final now = DateTime.now().toUtc();
      final withOptional = AppUser(
        id: 'sec_opt',
        username: 'bob.demo',
        displayName: 'Bob Demo',
        passwordHash: PasswordHasher.hash('x'),
        role: UserRole.secretary.storageName,
        permissionsRaw: AppPermission.encodeList(
          AppPermission.mergeSecretaryPermissions([
            ...AppPermission.defaultSecretary,
            AppPermission.onboarding,
          ]),
        ),
        updatedAt: now,
      );
      await db.upsertAppUser(withOptional);

      final saved = await auth.updateSecretaryPermissions(
        userId: withOptional.id,
        permissions: AppPermission.defaultSecretary,
      );
      expect(saved.permissions, isNot(contains(AppPermission.onboarding)));

      final reloaded = await db.getAppUserById(withOptional.id);
      expect(reloaded!.permissions, isNot(contains(AppPermission.onboarding)));
      expect(reloaded.permissions, contains(AppPermission.reminders));
    });
  });
}
