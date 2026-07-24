import '../models/app_user.dart';
import '../models/member.dart';
import '../models/reminder.dart';
import '../models/secretary_remuneration.dart';
import '../models/user_role.dart';
import 'database_service.dart';
import 'password_hasher.dart';

/// One-click demo data for RS assignment + remuneration flows.
///
/// // NEW ADDITION - Delete this file to revert test data generation.
class TestDataService {
  TestDataService(this._db);

  final DatabaseService _db;

  Future<void> generateTestData() async {
    final now = DateTime.now().toUtc();
    final hash = PasswordHasher.hash('garden2026');

    // Recording secretaries (skip if username already exists)
    final secretaries = [
      (
        id: 'sec_001',
        username: 'jane.smith',
        displayName: 'Jane Smith',
      ),
      (
        id: 'sec_002',
        username: 'bob.johnson',
        displayName: 'Bob Johnson',
      ),
      (
        id: 'sec_003',
        username: 'alice.williams',
        displayName: 'Alice Williams',
      ),
    ];

    for (final s in secretaries) {
      final existing = await _db.getAppUserByUsername(s.username);
      if (existing != null) continue;
      await _db.upsertAppUser(
        AppUser(
          id: s.id,
          username: s.username,
          displayName: s.displayName,
          passwordHash: hash,
          role: UserRole.secretary.storageName,
          permissionsRaw: AppPermission.encodeList(AppPermission.assignable),
          updatedAt: now,
          pendingSync: true,
          active: true,
        ),
      );
    }

    // Known Luhn-valid SA ID used elsewhere in tests: 9001014800089
    // Additional 13-digit IDs for demo (hard validate = length only).
    final members = <Member>[
      Member(
        id: 'mem_rs_001',
        saId: '9001014800089',
        globalRecordNo: 'GR2026001',
        memberName: 'John',
        surname: 'Doe',
        address: '123 Main Street',
        suburb: 'Sandton',
        townCity: 'Johannesburg',
        postalCode: '2196',
        contactNo1: '0821234567',
        emailAddress: 'john.doe@email.com',
        registrationStatus: 'in_progress',
        isEmailVerified: true,
        step1MemberInfoComplete: true,
        step1CompletionDate: now.subtract(const Duration(hours: 2)),
        assignedSecretaryId: 'sec_001',
        assignedSecretaryName: 'Jane Smith',
        assignedDate: now.subtract(const Duration(hours: 2)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
        pendingSync: true,
      ),
      Member(
        id: 'mem_rs_002',
        saId: '8502155800085',
        globalRecordNo: 'GR2026002',
        memberName: 'Mary',
        surname: 'Brown',
        address: '456 Oak Avenue',
        suburb: 'Rosebank',
        townCity: 'Johannesburg',
        postalCode: '2196',
        contactNo1: '0834567890',
        emailAddress: 'mary.brown@email.com',
        registrationStatus: 'in_progress',
        isEmailVerified: true,
        step1MemberInfoComplete: true,
        step2Global528Complete: true,
        step1CompletionDate: now.subtract(const Duration(hours: 6)),
        step2CompletionDate: now.subtract(const Duration(hours: 5)),
        assignedSecretaryId: 'sec_002',
        assignedSecretaryName: 'Bob Johnson',
        assignedDate: now.subtract(const Duration(hours: 5)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now,
        pendingSync: true,
      ),
      Member(
        id: 'mem_rs_003',
        saId: '9005015800088',
        globalRecordNo: 'GR2026003',
        memberName: 'Peter',
        surname: 'Wilson',
        address: '789 Pine Road',
        suburb: 'Melrose',
        townCity: 'Johannesburg',
        postalCode: '2196',
        contactNo1: '0845678901',
        emailAddress: 'peter.wilson@email.com',
        registrationStatus: 'in_progress',
        isEmailVerified: true,
        step1MemberInfoComplete: true,
        step2Global528Complete: true,
        step3Global928Complete: true,
        assignedSecretaryId: 'sec_003',
        assignedSecretaryName: 'Alice Williams',
        assignedDate: now.subtract(const Duration(hours: 8)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now,
        pendingSync: true,
      ),
      Member(
        id: 'mem_rs_004',
        saId: '9506015800082',
        globalRecordNo: 'GR2026004',
        memberName: 'Susan',
        surname: 'Taylor',
        address: '321 Elm Street',
        suburb: 'Bryanston',
        townCity: 'Johannesburg',
        postalCode: '2196',
        contactNo1: '0856789012',
        emailAddress: 'susan.taylor@email.com',
        registrationStatus: 'fully_fledged',
        isEmailVerified: true,
        step1MemberInfoComplete: true,
        step2Global528Complete: true,
        step3Global928Complete: true,
        step4LROComplete: true,
        isLocked: true,
        lockedDate: now.subtract(const Duration(days: 1)),
        lockedBy: 'sec_001',
        assignedSecretaryId: 'sec_001',
        assignedSecretaryName: 'Jane Smith',
        assignedDate: now.subtract(const Duration(days: 5)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
        pendingSync: true,
      ),
    ];

    for (final member in members) {
      final existing = await _db.getMemberById(member.id);
      if (existing != null) continue;
      // Avoid UNIQUE conflicts on saId / globalRecordNo if already present.
      final bySa = await _db.getMemberBySaId(member.saId);
      if (bySa != null) continue;
      await _db.upsertMember(member);
    }

    final reminders = [
      Reminder.createOnboarding(
        memberId: 'mem_rs_001',
        memberName: 'John',
        surname: 'Doe',
        saId: '9001014800089',
        stepNumber: 1,
      ).copyWith(
        id: 'rem_rs_001',
        assignedSecretaryId: 'sec_001',
        assignedSecretaryName: 'Jane Smith',
        assignedDate: now.subtract(const Duration(hours: 2)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Reminder.createOnboarding(
        memberId: 'mem_rs_002',
        memberName: 'Mary',
        surname: 'Brown',
        saId: '8502155800085',
        stepNumber: 2,
      ).copyWith(
        id: 'rem_rs_002',
        assignedSecretaryId: 'sec_002',
        assignedSecretaryName: 'Bob Johnson',
        assignedDate: now.subtract(const Duration(hours: 5)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      Reminder.createOnboarding(
        memberId: 'mem_rs_003',
        memberName: 'Peter',
        surname: 'Wilson',
        saId: '9005015800088',
        stepNumber: 3,
      ).copyWith(
        id: 'rem_rs_003',
        assignedSecretaryId: 'sec_003',
        assignedSecretaryName: 'Alice Williams',
        assignedDate: now.subtract(const Duration(hours: 8)),
        assignmentMethod: 'manual',
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now.subtract(const Duration(hours: 8)),
      ),
    ];

    for (final reminder in reminders) {
      final existing = await _db.getReminderById(reminder.id);
      if (existing != null) continue;
      await _db.upsertReminder(reminder);
    }

    final remunerations = [
      SecretaryRemuneration(
        id: 'remun_rs_001',
        secretaryId: 'sec_001',
        secretaryName: 'Jane Smith',
        memberId: 'mem_rs_002',
        memberName: 'Mary Brown',
        type: 'step2',
        description: 'Global 528 Completion',
        amount: 200,
        status: 'paid',
        dateEarned: now.subtract(const Duration(days: 2)),
        datePaid: now.subtract(const Duration(days: 1)),
        syncStatus: 'pending',
      ),
      SecretaryRemuneration(
        id: 'remun_rs_002',
        secretaryId: 'sec_002',
        secretaryName: 'Bob Johnson',
        memberId: 'mem_rs_003',
        memberName: 'Peter Wilson',
        type: 'step3',
        description: 'Global 928 Completion',
        amount: 300,
        status: 'pending',
        dateEarned: now.subtract(const Duration(days: 1)),
        syncStatus: 'pending',
      ),
      SecretaryRemuneration(
        id: 'remun_rs_003',
        secretaryId: 'sec_003',
        secretaryName: 'Alice Williams',
        memberId: 'mem_rs_004',
        memberName: 'Susan Taylor',
        type: 'step4',
        description: 'LRO Completion',
        amount: 250,
        status: 'pending',
        dateEarned: now.subtract(const Duration(hours: 12)),
        syncStatus: 'pending',
      ),
    ];

    for (final rem in remunerations) {
      final existing = await _db.getRemuneration(rem.id);
      if (existing != null) continue;
      await _db.saveRemuneration(rem);
    }
  }
}
