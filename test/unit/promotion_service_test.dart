import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/activity_service.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:garden_town_county/services/promotion_service.dart';
import 'package:garden_town_county/services/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DatabaseService db;
  late AuthService auth;
  late PromotionService promotion;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService.instance;
    await db.initForTests();
    auth = AuthService(db);
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

  test('promote member creates secretary AppUser; demote blocked if assigned',
      () async {
    final now = DateTime.now().toUtc();
    final member = Member(
      id: 'm_promo',
      saId: '9001014800089',
      globalRecordNo: 'GRP1',
      memberName: 'John',
      surname: 'Doe',
      updatedAt: now,
    );
    await db.upsertMember(member);

    final admin = auth.currentUser!;
    await promotion.promoteToRecordingSecretary(
      member: member,
      admin: admin,
    );

    expect(await promotion.isRecordingSecretary(member), isTrue);
    final user = await db.getAppUserByMemberId(member.id);
    expect(user?.isSecretary, isTrue);

    await db.upsertMember(
      Member(
        id: 'm_other',
        saId: '8502155800085',
        globalRecordNo: 'GRP2',
        memberName: 'Mary',
        surname: 'Brown',
        assignedSecretaryId: user!.id,
        updatedAt: now,
      ),
    );

    expect(
      () => promotion.demoteToMember(member: member, admin: admin),
      throwsA(isA<Exception>()),
    );

    await db.assignSecretaryToMember(
      memberId: 'm_other',
      secretaryId: null,
    );
    await promotion.demoteToMember(member: member, admin: admin);
    expect(await promotion.isRecordingSecretary(member), isFalse);
  });
}
