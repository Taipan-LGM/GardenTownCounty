import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/auth_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('verifies selected Admin or RS without changing the app session', () async {
    final database = DatabaseService.instance;
    await database.initForTests();
    final secretary = AppUser(
      id: 'rs-verification-test',
      username: 'jane.smith',
      displayName: 'Jane Smith',
      passwordHash: PasswordHasher.hash('correct-password'),
      role: UserRole.secretary.storageName,
      updatedAt: DateTime.now().toUtc(),
    );
    await database.upsertAppUser(secretary);
    final admin = AppUser(
      id: 'admin-verification-test',
      username: 'admin.test',
      displayName: 'Admin Test',
      passwordHash: PasswordHasher.hash('admin-password'),
      role: UserRole.admin.storageName,
      updatedAt: DateTime.now().toUtc(),
    );
    await database.upsertAppUser(admin);
    final auth = AuthService(database);

    final verified = await auth.verifyPaymentAssistantCredentials(
      assistantId: secretary.id,
      username: secretary.username,
      password: 'correct-password',
    );
    final verifiedAdmin = await auth.verifyPaymentAssistantCredentials(
      assistantId: admin.id,
      username: admin.username,
      password: 'admin-password',
    );

    expect(verified.id, secretary.id);
    expect(verifiedAdmin.id, admin.id);
    expect(auth.currentUser, isNull);
    await expectLater(
      auth.verifyPaymentAssistantCredentials(
        assistantId: secretary.id,
        username: secretary.username,
        password: 'wrong-password',
      ),
      throwsException,
    );
  });

  test('active Admin can verify with the password used for sign-in', () async {
    SharedPreferences.setMockInitialValues({});
    final database = DatabaseService.instance;
    await database.initForTests();
    final admin = AppUser(
      id: 'active-admin-verification-test',
      username: 'active.admin',
      displayName: 'Active Admin',
      passwordHash: PasswordHasher.hash('correct-password'),
      role: UserRole.admin.storageName,
      updatedAt: DateTime.now().toUtc(),
    );
    await database.upsertAppUser(admin);
    final auth = AuthService(database);
    await auth.signIn(
      usernameOrEmail: admin.username,
      password: 'correct-password',
    );

    await database.upsertAppUser(
      admin.copyWith(passwordHash: PasswordHasher.hash('stale-password')),
    );

    final verified = await auth.verifyPaymentAssistantCredentials(
      assistantId: admin.id,
      username: admin.username,
      password: 'correct-password',
    );

    expect(verified.id, admin.id);
    expect(auth.currentUser?.id, admin.id);
    await expectLater(
      auth.verifyPaymentAssistantCredentials(
        assistantId: admin.id,
        username: admin.username,
        password: 'wrong-password',
      ),
      throwsException,
    );
  });
}