import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/county_info.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/activity_service.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/county_info_service.dart';
import 'package:garden_town_county/services/county_settings_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:garden_town_county/services/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DatabaseService db;
  late CountyInfoService service;
  late AuthUser admin;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService.instance;
    await db.initForTests();
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
    admin = AuthUser.fromAppUser((await db.getAppUserById('demo-admin'))!);
    final activity = ActivityService(db, SyncEngine(db));
    service = CountyInfoService(db, activity, CountySettingsService());
  });

  tearDown(() async {
    await db.clearAllForTests();
  });

  test('getCountyInfo seeds defaults including contact', () async {
    final info = await service.getCountyInfo();
    expect(info.countyName, 'Garden Town County');
    expect(info.countyContactNo, isNotEmpty);
    expect(info.resetCount, 0);
  });

  test('allFourFieldsDiffer requires all four', () {
    final base = CountyInfo.defaults();
    expect(
      base.allFourFieldsDiffer(
        countyName: 'A',
        countyAddress: 'B',
        countyContactNo: 'C',
        countyRegistrationNo: 'D',
      ),
      isTrue,
    );
    expect(
      base.allFourFieldsDiffer(
        countyName: 'A',
        countyAddress: 'B',
        countyContactNo: base.countyContactNo,
        countyRegistrationNo: 'D',
      ),
      isFalse,
    );
  });

  test('update without reset keeps members', () async {
    await db.upsertMember(
      Member.create(
        saId: '9001014800089',
        globalRecordNo: '100',
        memberName: 'Keep',
        surname: 'Me',
      ).copyWith(id: 'm1'),
    );
    await service.updateCountyInfo(
      countyName: 'Garden Town County Updated',
      countyAddress: '123 Main Street, Sandton, Johannesburg',
      countyContactNo: '011 123 4567',
      countyRegistrationNo: 'CT2026-001',
      admin: admin,
      isNewCounty: false,
    );
    expect((await db.getAllMembers()).length, 1);
    final info = await service.getCountyInfo();
    expect(info.countyName, 'Garden Town County Updated');
    expect(info.resetCount, 0);
  });

  test('new county reset requires all four fields changed', () async {
    await db.upsertMember(
      Member.create(
        saId: '9001014800089',
        globalRecordNo: '100',
        memberName: 'Gone',
        surname: 'Soon',
      ).copyWith(id: 'm1'),
    );

    // Only 3 fields changed → no reset even if isNewCounty true.
    await service.updateCountyInfo(
      countyName: 'Almost New',
      countyAddress: '9 Fresh Ave',
      countyContactNo: '011 123 4567', // same as default
      countyRegistrationNo: 'NH-999',
      admin: admin,
      isNewCounty: true,
    );
    expect((await db.getAllMembers()).length, 1);

    await service.updateCountyInfo(
      countyName: 'New Hope County',
      countyAddress: '9 Fresh Ave, Cape Town',
      countyContactNo: '021 555 0000',
      countyRegistrationNo: 'NH-1000',
      admin: admin,
      isNewCounty: true,
    );

    expect(await db.getAllMembers(), isEmpty);
    expect(await db.getAppUserById('demo-admin'), isNotNull);

    final info = await service.getCountyInfo();
    expect(info.countyName, 'New Hope County');
    expect(info.countyContactNo, '021 555 0000');
    expect(info.resetCount, 1);
    expect(info.lastResetDate, isNotNull);
  });
}
