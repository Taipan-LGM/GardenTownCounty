import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/services/password_hasher.dart';

void main() {
  group('UserRole', () {
    test('admin flag and labels', () {
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.manager.isAdmin, isFalse);
      expect(UserRole.admin.label, 'Admin');
      expect(UserRole.supervisor.label, 'Supervisor');
      expect(UserRoleX.fromStorage('manager'), UserRole.manager);
    });
  });

  group('PasswordHasher', () {
    test('hashes consistently and verifies', () {
      final hash = PasswordHasher.hash('garden2026');
      expect(hash, isNotEmpty);
      expect(PasswordHasher.verify('garden2026', hash), isTrue);
      expect(PasswordHasher.verify('wrong', hash), isFalse);
    });
  });

  group('AppUser', () {
    test('create stores role and username lowercase', () {
      final user = AppUser.create(
        username: 'ManagerOne',
        displayName: 'Manager One',
        passwordHash: PasswordHasher.hash('secret1'),
        role: UserRole.manager,
      );
      expect(user.username, 'managerone');
      expect(user.role, UserRole.manager);
      expect(user.toFirestore()['role'], 'manager');
      expect(user.toFirestore().containsKey('pendingSync'), isFalse);
    });
  });
}
