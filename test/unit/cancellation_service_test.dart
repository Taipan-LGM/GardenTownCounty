import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/activity_service.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/cancellation_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:garden_town_county/services/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DatabaseService db;
  late CancellationService cancellation;
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
    admin = const AuthUser(
      id: 'demo-admin',
      displayName: 'Admin',
      username: 'admin',
      role: 'Admin',
    );
    cancellation = CancellationService(
      db,
      ActivityService(db, SyncEngine(db)),
    );
  });

  test('cancel removes from active list and reinstate restores', () async {
    final member = Member.create(
      saId: '9001015009087',
      globalRecordNo: '5555555555',
      memberName: 'Cancel',
      surname: 'Me',
    );
    await db.upsertMember(member);

    final cancelled = await cancellation.cancelMembership(
      memberId: member.id,
      admin: admin,
      reason: 'Resigned',
    );
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.cancellationReason, 'Resigned');
    expect(cancelled.registrationStatus, 'cancelled');

    final active = await db.getAllMembers();
    expect(active.any((m) => m.id == member.id), isFalse);

    final cancelledList = await db.getCancelledMembers();
    expect(cancelledList.any((m) => m.id == member.id), isTrue);

    final reinstated = await cancellation.reinstateMembership(
      memberId: member.id,
      admin: admin,
    );
    expect(reinstated.isCancelled, isFalse);
    expect(reinstated.reinstatedBy, admin.id);

    final activeAgain = await db.getAllMembers();
    expect(activeAgain.any((m) => m.id == member.id), isTrue);
  });
}
