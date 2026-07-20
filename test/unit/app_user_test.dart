import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/role_definition.dart';
import 'package:garden_town_county/services/password_hasher.dart';

void main() {
  group('AppUser', () {
    test('create stores role and username lowercase', () {
      final user = AppUser.create(
        username: 'ManagerOne',
        displayName: 'Manager One',
        passwordHash: PasswordHasher.hash('secret1'),
        role: 'Manager',
      );
      expect(user.username, 'managerone');
      expect(user.role, 'Manager');
      expect(user.isAdmin, isFalse);
      expect(user.toFirestore()['role'], 'Manager');
      expect(user.toFirestore().containsKey('pendingSync'), isFalse);
    });

    test('admin and system administrator flags', () {
      final admin = AppUser(
        id: 'demo-admin',
        username: 'admin',
        displayName: 'County Administrator',
        passwordHash: 'x',
        role: 'Admin',
        updatedAt: DateTime.now().toUtc(),
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isSystemAdministrator, isTrue);
    });
  });

  group('RoleDefinition', () {
    test('admin role detection', () {
      final role = RoleDefinition.create(name: 'Admin', grantsAdmin: true);
      expect(role.isAdminRole, isTrue);
      expect(RoleDefinition.create(name: 'Clerk').isAdminRole, isFalse);
    });
  });
}
