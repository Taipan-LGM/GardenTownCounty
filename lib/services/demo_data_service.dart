import '../models/app_user.dart';
import '../models/member.dart';
import '../models/reminder.dart';
import '../models/user_role.dart';
import 'database_service.dart';
import 'password_hasher.dart';

/// Generates 10 South African leader demo members + onboarding reminders.
///
/// // NEW ADDITION - Delete this file to revert drawer Demo Data generation.
class DemoDataService {
  DemoDataService(this._db);

  final DatabaseService _db;

  /// Ensures 3 active Recording Secretaries exist, then creates demo members/reminders.
  Future<DemoDataResult> generateDemoData() async {
    final now = DateTime.now().toUtc();
    await _ensureSecretaries(now);

    var membersCreated = 0;
    var remindersCreated = 0;

    final members = _buildMembers(now);
    for (final member in members) {
      final existing = await _db.getMemberById(member.id);
      if (existing != null) continue;
      final bySa = await _db.getMemberBySaId(member.saId);
      if (bySa != null) continue;
      await _db.upsertMember(member);
      membersCreated++;
    }

    final reminders = _buildReminders(now);
    for (final reminder in reminders) {
      final existing = await _db.getReminderById(reminder.id);
      if (existing != null) continue;
      await _db.upsertReminder(reminder);
      remindersCreated++;
    }

    // Manual assignments for a few (leave rest for Auto-Assign All)
    final janeId = await _secretaryIdByUsername('jane.smith');
    final bobId = await _secretaryIdByUsername('bob.johnson');
    if (janeId != null) {
      await _db.assignSecretaryToMember(
        memberId: 'demo_002',
        secretaryId: janeId,
        assignmentMethod: 'manual',
      );
      await _db.assignSecretaryToReminder(
        reminderId: 'rem_demo_002',
        secretaryId: janeId,
        assignmentMethod: 'manual',
      );
    }
    if (bobId != null) {
      await _db.assignSecretaryToMember(
        memberId: 'demo_003',
        secretaryId: bobId,
        assignmentMethod: 'manual',
      );
      await _db.assignSecretaryToReminder(
        reminderId: 'rem_demo_003',
        secretaryId: bobId,
        assignmentMethod: 'manual',
      );
    }

    return DemoDataResult(
      membersCreated: membersCreated,
      remindersCreated: remindersCreated,
    );
  }

  Future<String?> _secretaryIdByUsername(String username) async {
    final user = await _db.getAppUserByUsername(username);
    return user?.id;
  }

  Future<void> _ensureSecretaries(DateTime now) async {
    final hash = PasswordHasher.hash('garden2026');
    final secretaries = [
      (id: 'sec_001', username: 'jane.smith', displayName: 'Jane Smith'),
      (id: 'sec_002', username: 'bob.johnson', displayName: 'Bob Johnson'),
      (id: 'sec_003', username: 'alice.williams', displayName: 'Alice Williams'),
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
          permissionsRaw:
              AppPermission.encodeList(AppPermission.defaultSecretary),
          updatedAt: now,
          pendingSync: true,
          active: true,
        ),
      );
    }
  }

  List<Member> _buildMembers(DateTime now) {
    Member m({
      required String id,
      required String saId,
      required String gr,
      required String name,
      required String surname,
      required String address,
      required String suburb,
      required String town,
      required String postal,
      required String c1,
      required String c2,
      required String email,
      required String status,
      required bool s1,
      required bool s2,
      required bool s3,
      required Duration age,
    }) {
      return Member(
        id: id,
        saId: saId,
        globalRecordNo: gr,
        memberName: name,
        surname: surname,
        address: address,
        suburb: suburb,
        townCity: town,
        postalCode: postal,
        contactNo1: c1,
        contactNo2: c2,
        emailAddress: email,
        registrationStatus: status,
        isEmailVerified: true,
        step1MemberInfoComplete: s1,
        step2Global528Complete: s2,
        step3Global928Complete: s3,
        step4LROComplete: false,
        createdAt: now.subtract(age),
        updatedAt: now,
        pendingSync: true,
      );
    }

    return [
      m(
        id: 'demo_001',
        saId: '8001015009087',
        gr: 'GR2026001',
        name: 'Thabo',
        surname: 'Mbeki',
        address: '123 Government Avenue',
        suburb: 'Pretoria Central',
        town: 'Pretoria',
        postal: '0001',
        c1: '0821234567',
        c2: '0827654321',
        email: 'thabo.mbeki@email.com',
        status: 'in_progress',
        s1: true,
        s2: false,
        s3: false,
        age: const Duration(hours: 1),
      ),
      m(
        id: 'demo_002',
        saId: '8502012345678',
        gr: 'GR2026002',
        name: 'Nelson',
        surname: 'Mandela',
        address: '4666 Vilakazi Street',
        suburb: 'Soweto',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0834567890',
        c2: '0830987654',
        email: 'nelson.mandela@email.com',
        status: 'in_progress',
        s1: true,
        s2: true,
        s3: false,
        age: const Duration(hours: 3),
      ),
      m(
        id: 'demo_003',
        saId: '9005017890123',
        gr: 'GR2026003',
        name: 'Winnie',
        surname: 'Madikizela-Mandela',
        address: '8028 Mandela Street',
        suburb: 'Orlando West',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0845678901',
        c2: '0841098765',
        email: 'winnie.mandela@email.com',
        status: 'in_progress',
        s1: true,
        s2: true,
        s3: true,
        age: const Duration(hours: 6),
      ),
      m(
        id: 'demo_004',
        saId: '9506019876543',
        gr: 'GR2026004',
        name: 'Desmond',
        surname: 'Tutu',
        address: '19a Bree Street',
        suburb: 'Cape Town City Centre',
        town: 'Cape Town',
        postal: '8001',
        c1: '0856789012',
        c2: '0852109876',
        email: 'desmond.tutu@email.com',
        status: 'in_progress',
        s1: true,
        s2: false,
        s3: false,
        age: const Duration(hours: 8),
      ),
      m(
        id: 'demo_005',
        saId: '7302013456789',
        gr: 'GR2026005',
        name: 'Albertina',
        surname: 'Sisulu',
        address: '7298 Maponya Street',
        suburb: 'Dube',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0867890123',
        c2: '0863210987',
        email: 'albertina.sisulu@email.com',
        status: 'pending',
        s1: false,
        s2: false,
        s3: false,
        age: const Duration(hours: 12),
      ),
      m(
        id: 'demo_006',
        saId: '8203014567890',
        gr: 'GR2026006',
        name: 'Chris',
        surname: 'Hani',
        address: '123 Molefe Street',
        suburb: 'Boksburg',
        town: 'Johannesburg',
        postal: '1459',
        c1: '0878901234',
        c2: '0874321098',
        email: 'chris.hani@email.com',
        status: 'pending',
        s1: false,
        s2: false,
        s3: false,
        age: const Duration(hours: 18),
      ),
      m(
        id: 'demo_007',
        saId: '9102015678901',
        gr: 'GR2026007',
        name: 'Miriam',
        surname: 'Makeba',
        address: '456 Jazz Avenue',
        suburb: 'Kliptown',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0889012345',
        c2: '0885432109',
        email: 'miriam.makeba@email.com',
        status: 'pending',
        s1: false,
        s2: false,
        s3: false,
        age: const Duration(hours: 24),
      ),
      m(
        id: 'demo_008',
        saId: '8402016789012',
        gr: 'GR2026008',
        name: 'Oliver',
        surname: 'Tambo',
        address: '789 Freedom Road',
        suburb: 'Mamelodi',
        town: 'Pretoria',
        postal: '0122',
        c1: '0890123456',
        c2: '0896543210',
        email: 'oliver.tambo@email.com',
        status: 'in_progress',
        s1: true,
        s2: false,
        s3: false,
        age: const Duration(hours: 30),
      ),
      m(
        id: 'demo_009',
        saId: '8602017890123',
        gr: 'GR2026009',
        name: 'Kgalema',
        surname: 'Motlanthe',
        address: '321 Constitution Hill',
        suburb: 'Braamfontein',
        town: 'Johannesburg',
        postal: '2001',
        c1: '0822345678',
        c2: '0828765432',
        email: 'kgalema.motlanthe@email.com',
        status: 'in_progress',
        s1: true,
        s2: true,
        s3: false,
        age: const Duration(hours: 36),
      ),
      m(
        id: 'demo_010',
        saId: '9202018901234',
        gr: 'GR2026010',
        name: 'Graca',
        surname: 'Machel',
        address: '789 Maputo Street',
        suburb: 'Norwood',
        town: 'Johannesburg',
        postal: '2192',
        c1: '0833456789',
        c2: '0839876543',
        email: 'graca.machel@email.com',
        status: 'in_progress',
        s1: true,
        s2: true,
        s3: true,
        age: const Duration(hours: 48),
      ),
    ];
  }

  List<Reminder> _buildReminders(DateTime now) {
    Reminder r({
      required String id,
      required String memberId,
      required String name,
      required String surname,
      required String saId,
      required int step,
      required Duration age,
      required Duration expiryOffset,
      required String status,
    }) {
      final created = now.subtract(age);
      final expiry = now.add(expiryOffset);
      final desc = ReminderStep.getDescription(step);
      return Reminder(
        id: id,
        memberId: memberId,
        createdBy: 'demo',
        title: 'Step $step: $desc',
        description: 'Demo onboarding reminder — $desc',
        reminderDateTime: expiry,
        priority: step == 1 ? 'High' : 'Medium',
        createdAt: created,
        updatedAt: created,
        kind: 'onboarding',
        stepNumber: step,
        stepDescription: desc,
        memberName: name,
        surname: surname,
        saId: saId,
        expiryDate: expiry,
        status: status,
        isCompleted: status == 'completed',
        pendingSync: true,
      );
    }

    return [
      r(
        id: 'rem_demo_001',
        memberId: 'demo_001',
        name: 'Thabo',
        surname: 'Mbeki',
        saId: '8001015009087',
        step: 1,
        age: const Duration(hours: 1),
        expiryOffset: const Duration(hours: 23),
        status: 'active',
      ),
      r(
        id: 'rem_demo_002',
        memberId: 'demo_002',
        name: 'Nelson',
        surname: 'Mandela',
        saId: '8502012345678',
        step: 2,
        age: const Duration(hours: 3),
        expiryOffset: const Duration(hours: 21),
        status: 'active',
      ),
      r(
        id: 'rem_demo_003',
        memberId: 'demo_003',
        name: 'Winnie',
        surname: 'Madikizela-Mandela',
        saId: '9005017890123',
        step: 3,
        age: const Duration(hours: 6),
        expiryOffset: const Duration(hours: 18),
        status: 'active',
      ),
      r(
        id: 'rem_demo_004',
        memberId: 'demo_004',
        name: 'Desmond',
        surname: 'Tutu',
        saId: '9506019876543',
        step: 1,
        age: const Duration(hours: 8),
        expiryOffset: const Duration(hours: 16),
        status: 'active',
      ),
      r(
        id: 'rem_demo_005',
        memberId: 'demo_005',
        name: 'Albertina',
        surname: 'Sisulu',
        saId: '7302013456789',
        step: 1,
        age: const Duration(hours: 12),
        expiryOffset: const Duration(hours: 12),
        status: 'active',
      ),
      r(
        id: 'rem_demo_006',
        memberId: 'demo_006',
        name: 'Chris',
        surname: 'Hani',
        saId: '8203014567890',
        step: 1,
        age: const Duration(hours: 18),
        expiryOffset: const Duration(hours: 6),
        status: 'active',
      ),
      r(
        id: 'rem_demo_007',
        memberId: 'demo_007',
        name: 'Miriam',
        surname: 'Makeba',
        saId: '9102015678901',
        step: 1,
        age: const Duration(hours: 24),
        expiryOffset: Duration.zero,
        status: 'active',
      ),
      r(
        id: 'rem_demo_008',
        memberId: 'demo_008',
        name: 'Oliver',
        surname: 'Tambo',
        saId: '8402016789012',
        step: 1,
        age: const Duration(hours: 30),
        expiryOffset: const Duration(hours: -6),
        status: 'expired',
      ),
      r(
        id: 'rem_demo_009',
        memberId: 'demo_009',
        name: 'Kgalema',
        surname: 'Motlanthe',
        saId: '8602017890123',
        step: 2,
        age: const Duration(hours: 36),
        expiryOffset: const Duration(hours: -12),
        status: 'expired',
      ),
      r(
        id: 'rem_demo_010',
        memberId: 'demo_010',
        name: 'Graca',
        surname: 'Machel',
        saId: '9202018901234',
        step: 3,
        age: const Duration(hours: 48),
        expiryOffset: const Duration(hours: -24),
        status: 'expired',
      ),
    ];
  }
}

class DemoDataResult {
  const DemoDataResult({
    required this.membersCreated,
    required this.remindersCreated,
  });

  final int membersCreated;
  final int remindersCreated;
}
