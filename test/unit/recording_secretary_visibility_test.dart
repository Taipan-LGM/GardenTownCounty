import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/app_user.dart';
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
}
