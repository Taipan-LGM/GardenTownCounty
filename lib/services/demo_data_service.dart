import '../models/app_user.dart';
import '../models/activity_log.dart';
import '../models/county_article.dart';
import '../models/county_video.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import '../models/reminder.dart';
import '../models/secretary_remuneration.dart';
import '../models/user_role.dart';
import 'database_service.dart';
import 'password_hasher.dart';

/// Generates demo members, reminders, duplicates, cancellations, Info & Videos.
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

    final duplicatesCreated = await _generateDuplicateMembers(now);
    final cancelledCreated = await _generateCancelledMembers(now);
    membersCreated += await _generatePaymentSummaryMembers(now);
    await _ensurePaymentMemberUsers(now);
    await _generatePaymentSummaryFiles(now);
    await _generatePaymentSummaryRecords(now);
    final articlesCreated = await _generateInfoArticles(now);
    final videosCreated = await _generateVideos(now);

    final auditEvents = [
      ActivityLog(
        id: 'demo_audit_payment',
        userName: 'County Administrator',
        action:
            '[PAY-MANUAL-RECORDED] recorded_manual_payment for Mary Brown amount R 200.00',
        occurredAt: now.subtract(const Duration(minutes: 4)),
      ),
      ActivityLog(
        id: 'demo_audit_pdf_release',
        userName: 'County Administrator',
        action: '[DOC-PDF-RELEASED] pdf_released for Mary Brown',
        occurredAt: now.subtract(const Duration(minutes: 3)),
      ),
      ActivityLog(
        id: 'demo_audit_ai_id',
        userName: 'County Administrator',
        action: '[MEM-AI-ID-GENERATED] ai_id_generated for Mary Brown',
        occurredAt: now.subtract(const Duration(minutes: 2)),
      ),
      ActivityLog(
        id: 'demo_audit_card_issued',
        userName: 'County Administrator',
        action:
            '[CARD-CREDENTIAL-ISSUED] credential_card_issued for Mary Brown',
        occurredAt: now.subtract(const Duration(minutes: 1)),
      ),
    ];
    for (final event in auditEvents) {
      await _db.insertActivity(event);
    }

    return DemoDataResult(
      membersCreated: membersCreated,
      remindersCreated: remindersCreated,
      duplicateMembersCreated: duplicatesCreated,
      cancelledMembersCreated: cancelledCreated,
      articlesCreated: articlesCreated,
      videosCreated: videosCreated,
    );
  }

  Future<int> _generatePaymentSummaryMembers(DateTime now) async {
    const completedSteps = <int>[
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      2,
      2,
      2,
      2,
      2,
      2,
      2,
      2,
      3,
      3,
      3,
      3,
      3,
      3,
      3,
      4,
      4,
      4,
      4,
      4,
      5,
      5,
      5,
    ];
    const stepDurations = <Duration>[
      Duration(hours: 60),
      Duration(hours: 100, minutes: 48),
      Duration(hours: 187, minutes: 12),
      Duration(hours: 74, minutes: 24),
      Duration(hours: 36),
    ];
    var created = 0;

    for (var index = 0; index < completedSteps.length; index++) {
      final sequence = index + 1;
      final id = 'pay_demo_${sequence.toString().padLeft(3, '0')}';
      final existing = await _db.getMemberById(id);
      final saId = '990000${sequence.toString().padLeft(7, '0')}';
      final bySaId = await _db.getMemberBySaId(saId);
      if (existing == null && bySaId != null) continue;
      if (existing != null && existing.createdBy != 'demo') continue;

      final completedStep = completedSteps[index];
      final registrationDate = now.subtract(
        Duration(days: 28 + (sequence % 14)),
      );
      final completionDates = <DateTime>[];
      var completionDate = registrationDate;
      for (final duration in stepDurations) {
        completionDate = completionDate.add(duration);
        completionDates.add(completionDate);
      }
      final secretaryId = switch (sequence) {
        1 || 2 || 33 || 34 => 'sec_001',
        13 || 35 => 'sec_002',
        _ => null,
      };
      final secretaryName = switch (secretaryId) {
        'sec_001' => 'Jane Smith',
        'sec_002' => 'Bob Johnson',
        _ => null,
      };
      final memberUserId = sequence <= 5 ? 'member_user_$sequence' : null;
      final member = existing != null
          ? existing.copyWith(
              registrationStatus: 'in_progress',
              registrationDate: registrationDate,
              userId: memberUserId,
              step1MemberInfoComplete: true,
              step2Global528Complete: completedStep >= 2,
              step3Global928Complete: completedStep >= 3,
              step4LROComplete: completedStep >= 4,
              step5CredentialCardComplete: completedStep >= 5,
              step1CompletionDate: completionDates[0],
              step2CompletionDate: completedStep >= 2
                  ? completionDates[1]
                  : null,
              step3CompletionDate: completedStep >= 3
                  ? completionDates[2]
                  : null,
              step4CompletionDate: completedStep >= 4
                  ? completionDates[3]
                  : null,
              step5CompletionDate: completedStep >= 5
                  ? completionDates[4]
                  : null,
              assignedSecretaryId: secretaryId,
              assignedSecretaryName: secretaryName,
              assignedDate: secretaryId == null ? null : now,
              assignedBy: secretaryId == null ? null : 'demo',
              assignmentMethod: secretaryId == null ? null : 'manual',
              updatedAt: now,
              pendingSync: true,
            )
          : Member(
              id: id,
              saId: saId,
              globalRecordNo: 'GRPAY${sequence.toString().padLeft(3, '0')}',
              memberName: 'Payment Demo',
              surname: sequence.toString().padLeft(3, '0'),
              address: '1 Demo Payment Way',
              suburb: 'Garden Town',
              townCity: 'Garden Town',
              postalCode: '0001',
              contactNo1: '080${sequence.toString().padLeft(7, '0')}',
              emailAddress: 'payment.demo.$sequence@gardentown.local',
              userId: memberUserId,
              registrationStatus: 'in_progress',
              registrationDate: registrationDate,
              isEmailVerified: true,
              step1MemberInfoComplete: true,
              step2Global528Complete: completedStep >= 2,
              step3Global928Complete: completedStep >= 3,
              step4LROComplete: completedStep >= 4,
              step5CredentialCardComplete: completedStep >= 5,
              step1CompletionDate: completionDates[0],
              step2CompletionDate: completedStep >= 2
                  ? completionDates[1]
                  : null,
              step3CompletionDate: completedStep >= 3
                  ? completionDates[2]
                  : null,
              step4CompletionDate: completedStep >= 4
                  ? completionDates[3]
                  : null,
              step5CompletionDate: completedStep >= 5
                  ? completionDates[4]
                  : null,
              assignedSecretaryId: secretaryId,
              assignedSecretaryName: secretaryName,
              assignedDate: secretaryId == null ? null : now,
              assignedBy: secretaryId == null ? null : 'demo',
              assignmentMethod: secretaryId == null ? null : 'manual',
              createdBy: 'demo',
              createdAt: registrationDate,
              updatedAt: now,
              pendingSync: true,
            );
      await _db.upsertMember(member);
      if (existing == null) created++;
    }

    for (
      var sequence = completedSteps.length + 1;
      sequence <= 100;
      sequence++
    ) {
      final id = 'pay_demo_${sequence.toString().padLeft(3, '0')}';
      final obsolete = await _db.getMemberById(id);
      if (obsolete == null || obsolete.createdBy != 'demo') continue;
      await _db.forceUpsertMember(
        obsolete.copyWith(deleted: true, updatedAt: now, pendingSync: true),
      );
    }
    return created;
  }

  Future<void> _generatePaymentSummaryFiles(DateTime now) async {
    for (var sequence = 1; sequence <= 35; sequence++) {
      final memberId = 'pay_demo_${sequence.toString().padLeft(3, '0')}';
      if (await _db.getMemberById(memberId) == null) continue;
      final stepNumber = _paymentDemoStepForSequence(sequence);
      await _db.upsertMemberFile(
        MemberFile(
          id: 'pay_demo_pdf_step_${stepNumber}_$memberId',
          memberId: memberId,
          fileName: 'step_${stepNumber}_completed.pdf',
          description: 'Completed Step $stepNumber PDF',
          uploadedBy: 'Jane Smith',
          uploadedAt: now,
          localPath: 'demo://member_files/$memberId/step_$stepNumber.pdf',
          contentType: 'application/pdf',
          sizeBytes: 1024,
          pendingSync: true,
        ),
      );
    }
  }

  Future<void> _generatePaymentSummaryRecords(DateTime now) async {
    const amountPerMember = <int, double>{
      1: 100,
      2: 200,
      3: 300,
      4: 250,
      5: 250,
    };
    final members = await _db.getAllMembers();
    final desiredIds = <String>{};

    for (final member in members) {
      if (!member.id.startsWith('pay_demo_')) continue;
      final sequence = int.tryParse(member.id.substring('pay_demo_'.length));
      if (sequence == null || sequence < 1 || sequence > 35) continue;
      final stepNumber = _paymentDemoStepForSequence(sequence);
      final paymentDate = now.subtract(Duration(days: sequence % 18));
      final id = 'pay_demo_summary_step_${stepNumber}_${member.id}';
      desiredIds.add(id);
      await _db.saveRemuneration(
        SecretaryRemuneration(
          id: id,
          secretaryId: member.assignedSecretaryId ?? 'sec_003',
          secretaryName: member.assignedSecretaryName ?? 'Alice Williams',
          memberId: member.id,
          memberName: member.fullName,
          type: 'step$stepNumber',
          description: 'Demo payment for Step $stepNumber',
          amount: amountPerMember[stepNumber]!,
          status: 'paid',
          dateEarned: paymentDate,
          datePaid: paymentDate,
          paidBy: 'demo',
          syncStatus: 'pending',
        ),
      );
    }

    final records = await _db.getAllRemunerationRecords();
    for (final record in records) {
      if (!record.id.startsWith('pay_demo_summary_') ||
          desiredIds.contains(record.id)) {
        continue;
      }
      await _db.updateRemuneration(
        record.copyWith(isDeleted: true, syncStatus: 'pending'),
      );
    }
  }

  int _paymentDemoStepForSequence(int sequence) {
    if (sequence <= 12) return 1;
    if (sequence <= 20) return 2;
    if (sequence <= 27) return 3;
    if (sequence <= 32) return 4;
    return 5;
  }

  Future<void> _ensurePaymentMemberUsers(DateTime now) async {
    final hash = PasswordHasher.hash('garden2026');
    for (var sequence = 1; sequence <= 5; sequence++) {
      final id = 'member_user_$sequence';
      final username = 'member$sequence';
      final existing = await _db.getAppUserByUsername(username);
      final user = AppUser(
        id: existing?.id ?? id,
        username: username,
        displayName: 'Payment Demo ${sequence.toString().padLeft(3, '0')}',
        passwordHash: existing?.passwordHash.isNotEmpty == true
            ? existing!.passwordHash
            : hash,
        role: UserRole.member.storageName,
        memberId: 'pay_demo_${sequence.toString().padLeft(3, '0')}',
        updatedAt: now,
        pendingSync: true,
        active: true,
      );
      await _db.upsertAppUser(user);
    }
  }

  /// 3 duplicate pairs (6 members) for Duplicate Manager.
  Future<int> _generateDuplicateMembers(DateTime now) async {
    var created = 0;
    for (final member in _buildDuplicateMembers(now)) {
      if (await _db.getMemberById(member.id) != null) continue;
      await _db.forceUpsertMember(member);
      created++;
    }
    return created;
  }

  /// 5 cancelled members for Cancellations screen.
  Future<int> _generateCancelledMembers(DateTime now) async {
    var created = 0;
    for (final member in _buildCancelledMembers(now)) {
      if (await _db.getMemberById(member.id) != null) continue;
      await _db.forceUpsertMember(member);
      created++;
    }
    return created;
  }

  Future<int> _generateInfoArticles(DateTime now) async {
    var created = 0;
    final existing = await _db.getAllArticles();
    final ids = existing.map((a) => a.id).toSet();
    for (final article in _buildArticles(now)) {
      if (ids.contains(article.id)) continue;
      await _db.upsertArticle(article);
      created++;
    }
    return created;
  }

  Future<int> _generateVideos(DateTime now) async {
    const legacyVideoIds = {
      'vid_001',
      'vid_002',
      'vid_003',
      'vid_004',
      'vid_005',
      'vid_006',
    };
    for (final id in legacyVideoIds) {
      await _db.softDeleteVideo(id);
    }

    var created = 0;
    final existing = await _db.getAllVideos();
    final ids = existing.map((v) => v.id).toSet();
    for (final video in _buildVideos(now)) {
      if (ids.contains(video.id)) continue;
      await _db.upsertVideo(video);
      created++;
    }
    return created;
  }

  List<Member> _buildDuplicateMembers(DateTime now) {
    Member dup({
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
      required bool emailVerified,
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
        isEmailVerified: emailVerified,
        step1MemberInfoComplete: true,
        step2Global528Complete: status == 'complete',
        step3Global928Complete: false,
        step4LROComplete: false,
        createdAt: now.subtract(age),
        updatedAt: now,
        pendingSync: true,
        createdBy: 'demo',
      );
    }

    return [
      dup(
        id: 'dup_001',
        saId: '8111015009087',
        gr: 'GRDUP001',
        name: 'John',
        surname: 'Doe',
        address: '123 Main Street',
        suburb: 'Sandton',
        town: 'Johannesburg',
        postal: '2196',
        c1: '0821234567',
        c2: '0827654321',
        email: 'john.doe@email.com',
        status: 'complete',
        emailVerified: true,
        age: const Duration(days: 10),
      ),
      dup(
        id: 'dup_002',
        saId: '8111015009087',
        gr: 'GRDUP002',
        name: 'Johnathan',
        surname: 'Doherty',
        address: '456 Oak Avenue',
        suburb: 'Rosebank',
        town: 'Johannesburg',
        postal: '2196',
        c1: '0834567890',
        c2: '0830987654',
        email: 'johnathan.doherty@email.com',
        status: 'pending',
        emailVerified: false,
        age: const Duration(days: 5),
      ),
      dup(
        id: 'dup_003',
        saId: '8512012345678',
        gr: 'GRDUP003',
        name: 'Mary',
        surname: 'Brown',
        address: '789 Pine Road',
        suburb: 'Melrose',
        town: 'Johannesburg',
        postal: '2196',
        c1: '0845678901',
        c2: '0841098765',
        email: 'mary.brown@email.com',
        status: 'complete',
        emailVerified: true,
        age: const Duration(days: 15),
      ),
      dup(
        id: 'dup_004',
        saId: '9015017890123',
        gr: 'GRDUP003',
        name: 'Maria',
        surname: 'Browne',
        address: '321 Elm Street',
        suburb: 'Bryanston',
        town: 'Johannesburg',
        postal: '2196',
        c1: '0856789012',
        c2: '0852109876',
        email: 'maria.browne@email.com',
        status: 'in_progress',
        emailVerified: true,
        age: const Duration(days: 3),
      ),
      dup(
        id: 'dup_005',
        saId: '9516019876543',
        gr: 'GRDUP004',
        name: 'Peter',
        surname: 'Wilson',
        address: '789 Maputo Street',
        suburb: 'Norwood',
        town: 'Johannesburg',
        postal: '2192',
        c1: '0867890123',
        c2: '0863210987',
        email: 'peter.wilson@email.com',
        status: 'complete',
        emailVerified: true,
        age: const Duration(days: 20),
      ),
      dup(
        id: 'dup_006',
        saId: '9516019876543',
        gr: 'GRDUP004',
        name: 'Petra',
        surname: 'Wilsonson',
        address: '456 Jazz Avenue',
        suburb: 'Kliptown',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0878901234',
        c2: '0874321098',
        email: 'petra.wilsonson@email.com',
        status: 'pending',
        emailVerified: false,
        age: const Duration(days: 1),
      ),
    ];
  }

  List<Member> _buildCancelledMembers(DateTime now) {
    Member can({
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
      required Duration createdAge,
      required Duration cancelAge,
      required String reason,
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
        registrationStatus: 'cancelled',
        isEmailVerified: true,
        step1MemberInfoComplete: true,
        step2Global528Complete: true,
        step3Global928Complete: true,
        step4LROComplete: false,
        isCancelled: true,
        cancellationDate: now.subtract(cancelAge),
        cancellationReason: reason,
        cancelledBy: 'demo',
        isLocked: false,
        createdAt: now.subtract(createdAge),
        updatedAt: now,
        pendingSync: true,
        createdBy: 'demo',
      );
    }

    return [
      can(
        id: 'can_001',
        saId: '8603012345678',
        gr: 'GRCAN001',
        name: 'Alice',
        surname: 'Johnson',
        address: '123 Freedom Road',
        suburb: 'Mamelodi',
        town: 'Pretoria',
        postal: '0122',
        c1: '0889012345',
        c2: '0885432109',
        email: 'alice.johnson@email.com',
        createdAge: const Duration(days: 90),
        cancelAge: const Duration(days: 60),
        reason: 'Member requested cancellation',
      ),
      can(
        id: 'can_002',
        saId: '8404012345678',
        gr: 'GRCAN002',
        name: 'Robert',
        surname: 'Williams',
        address: '456 Constitution Hill',
        suburb: 'Braamfontein',
        town: 'Johannesburg',
        postal: '2001',
        c1: '0890123456',
        c2: '0896543210',
        email: 'robert.williams@email.com',
        createdAge: const Duration(days: 180),
        cancelAge: const Duration(days: 30),
        reason: 'Inactive for 6 months',
      ),
      can(
        id: 'can_003',
        saId: '8205012345678',
        gr: 'GRCAN003',
        name: 'Sarah',
        surname: 'Jones',
        address: '789 Vilakazi Street',
        suburb: 'Soweto',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0822345678',
        c2: '0828765432',
        email: 'sarah.jones@email.com',
        createdAge: const Duration(days: 120),
        cancelAge: const Duration(days: 45),
        reason: 'Transferred to another county',
      ),
      can(
        id: 'can_004',
        saId: '8906012345678',
        gr: 'GRCAN004',
        name: 'Michael',
        surname: 'Taylor',
        address: '321 Mandela Street',
        suburb: 'Orlando West',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0833456789',
        c2: '0839876543',
        email: 'michael.taylor@email.com',
        createdAge: const Duration(days: 60),
        cancelAge: const Duration(days: 15),
        reason: 'Membership fees not paid',
      ),
      can(
        id: 'can_005',
        saId: '8707012345678',
        gr: 'GRCAN005',
        name: 'Emma',
        surname: 'Davis',
        address: '789 Maponya Street',
        suburb: 'Dube',
        town: 'Johannesburg',
        postal: '1804',
        c1: '0844567890',
        c2: '0841098765',
        email: 'emma.davis@email.com',
        createdAge: const Duration(days: 365),
        cancelAge: const Duration(days: 90),
        reason: 'Deceased member',
      ),
    ];
  }

  List<CountyArticle> _buildArticles(DateTime now) {
    CountyArticle art({
      required String id,
      required String title,
      required String content,
      required String author,
      required String category,
      required Duration age,
    }) {
      return CountyArticle(
        id: id,
        title: title,
        content: content.trim(),
        author: author,
        category: category,
        isPublished: true,
        createdAt: now.subtract(age),
        updatedAt: now.subtract(age),
        createdBy: 'demo',
        syncStatus: 'pending',
      );
    }

    return [
      art(
        id: 'art_001',
        title: 'Welcome to Garden Town County',
        author: 'Admin',
        category: 'general',
        age: const Duration(days: 30),
        content: '''
Garden Town County is a vibrant community dedicated to sustainable living,
community development, and environmental stewardship. Our county spans over
500 hectares of lush gardens, parks, and residential areas.
We pride ourselves on being a model for sustainable urban development in
South Africa. Our community members enjoy access to world-class facilities,
educational programs, and a supportive network of neighbors.
Join us in building a greener, more connected future for generations to come.
''',
      ),
      art(
        id: 'art_002',
        title: 'Community Garden Project Launch',
        author: 'Sarah Johnson',
        category: 'news',
        age: const Duration(days: 20),
        content: '''
We are excited to announce the launch of our new Community Garden Project!
This initiative aims to create sustainable food sources for our residents
while promoting environmental education.
The project will feature:
- 50 community garden plots
- Educational workshops on sustainable farming
- A farmers market every Saturday
- Youth gardening programs
Registration opens on the 1st of August. Please contact the County Office
for more information.
''',
      ),
      art(
        id: 'art_003',
        title: 'Water Conservation Guidelines',
        author: 'Environmental Department',
        category: 'announcement',
        age: const Duration(days: 15),
        content: '''
As part of our commitment to environmental sustainability, Garden Town County
has implemented new water conservation guidelines for all residents.
Key guidelines include:
- Use of rainwater harvesting systems
- Greywater recycling for gardens
- Smart irrigation systems
- Water-wise landscaping requirements
These guidelines will help us reduce water consumption by 30% over the next year.
''',
      ),
      art(
        id: 'art_004',
        title: 'Annual Garden Festival 2026',
        author: 'Events Committee',
        category: 'event',
        age: const Duration(days: 10),
        content: '''
Mark your calendars! The Annual Garden Town County Festival will take place
from December 10-12, 2026.
This year's festival will feature:
- Flower exhibition and competition
- Gardening workshops
- Local food and craft stalls
- Live music and entertainment
- Children's activities
We invite all residents and visitors to join this celebration of our beautiful
county. Volunteers are needed - please sign up at the County Office.
''',
      ),
      art(
        id: 'art_005',
        title: 'New Recycling Program',
        author: 'Sustainability Team',
        category: 'announcement',
        age: const Duration(days: 7),
        content: '''
Garden Town County is proud to announce our new comprehensive recycling program.
This initiative aims to reduce waste and promote a circular economy.
Recycling services now include:
- Weekly curbside collection for recyclables
- Electronic waste drop-off points
- Composting facilities
- Recycling education programs
Together, we can work towards a zero-waste community!
''',
      ),
      art(
        id: 'art_006',
        title: 'Meet Our New County Manager',
        author: 'County Office',
        category: 'news',
        age: const Duration(days: 5),
        content: '''
We are pleased to welcome Dr. Michael Thompson as our new County Manager.
Dr. Thompson brings over 20 years of experience in community development
and sustainable urban planning.
His vision for Garden Town County includes:
- Enhanced community engagement
- Sustainable development initiatives
- Improved public services
- Economic growth and job creation
Please join us in welcoming Dr. Thompson at the next community meeting on
August 15th.
''',
      ),
      art(
        id: 'art_007',
        title: 'Home Gardening Tips for Beginners',
        author: 'Gardening Club',
        category: 'general',
        age: const Duration(days: 3),
        content: '''
Starting your own garden can be a rewarding experience. Here are some tips
to get you started in Garden Town County:
1. Start small with a few easy-to-grow plants
2. Choose native plants that thrive in our climate
3. Use quality soil and compost
4. Water deeply but less frequently
5. Join the community garden club for support
Our gardening experts are available every Saturday at the Community Center
for advice and guidance.
''',
      ),
      art(
        id: 'art_008',
        title: 'County Development Plan 2026-2030',
        author: 'Planning Department',
        category: 'announcement',
        age: const Duration(days: 1),
        content: '''
Garden Town County has unveiled its five-year development plan for 2026-2030.
This comprehensive plan outlines our vision for sustainable growth and
community development.
Key priorities include:
- Infrastructure development and maintenance
- Environmental conservation
- Economic diversification
- Social inclusion and housing
- Digital transformation
The full plan is available for review at the County Office or on our website.
''',
      ),
    ];
  }

  List<CountyVideo> _buildVideos(DateTime now) {
    return [
      CountyVideo(
        id: 'vid_global_family_group',
        title: 'Global family Group',
        description:
            'To understand what the Global Family Group is all about... please watch the following video.',
        videoLocalPath: '',
        videoUrl: 'assets/assets/videos/global_family_group.mp4',
        duration: '14:89',
        category: 'general',
        isActive: true,
        uploadedAt: now.subtract(const Duration(days: 2)),
        uploadedBy: 'demo',
        syncStatus: 'pending',
      ),
      CountyVideo(
        id: 'vid_south_africa_corporation',
        title: 'South Africa is a Corporation',
        description:
            'Did you know that South Africa is not a Republic, but a Corporation?',
        videoLocalPath: '',
        videoUrl: 'assets/assets/videos/south_africa_corporation.mp4',
        duration: '6:22',
        category: 'general',
        isActive: true,
        uploadedAt: now.subtract(const Duration(days: 1)),
        uploadedBy: 'demo',
        syncStatus: 'pending',
      ),
    ];
  }

  Future<String?> _secretaryIdByUsername(String username) async {
    final user = await _db.getAppUserByUsername(username);
    return user?.id;
  }

  Future<void> _ensureSecretaries(DateTime now) async {
    final hash = PasswordHasher.hash('garden2026');
    // Each RS gets a Member row so Admin Member List can show them with RS badge.
    // MODIFIED - link secretary AppUsers to members (Delete memberId/members to revert)
    final secretaries = [
      (
        id: 'sec_001',
        username: 'jane.smith',
        displayName: 'Jane Smith',
        memberId: 'demo_rs_001',
        saId: '8203155800083',
        name: 'Jane',
        surname: 'Smith',
      ),
      (
        id: 'sec_002',
        username: 'bob.johnson',
        displayName: 'Bob Johnson',
        memberId: 'demo_rs_002',
        saId: '7908225009087',
        name: 'Bob',
        surname: 'Johnson',
      ),
      (
        id: 'sec_003',
        username: 'alice.williams',
        displayName: 'Alice Williams',
        memberId: 'demo_rs_003',
        saId: '8801040123089',
        name: 'Alice',
        surname: 'Williams',
      ),
    ];
    for (final s in secretaries) {
      final member = await _db.getMemberById(s.memberId);
      if (member == null) {
        await _db.upsertMember(
          Member(
            id: s.memberId,
            saId: s.saId,
            globalRecordNo: 'GR-RS-${s.memberId}',
            memberName: s.name,
            surname: s.surname,
            address: '1 Assembly Way',
            suburb: 'Garden Town',
            townCity: 'Garden Town',
            postalCode: '0001',
            contactNo1: '0820000000',
            contactNo2: '',
            emailAddress: '${s.username}@gardentown.local',
            registrationStatus: 'complete',
            isEmailVerified: true,
            step1MemberInfoComplete: true,
            step2Global528Complete: true,
            step3Global928Complete: true,
            step4LROComplete: false,
            userId: s.id,
            createdAt: now,
            updatedAt: now,
            pendingSync: true,
          ),
        );
      }

      final existing = await _db.getAppUserByUsername(s.username);
      if (existing == null) {
        await _db.upsertAppUser(
          AppUser(
            id: s.id,
            username: s.username,
            displayName: s.displayName,
            passwordHash: hash,
            role: UserRole.secretary.storageName,
            memberId: s.memberId,
            permissionsRaw: AppPermission.encodeList(
              AppPermission.defaultSecretary,
            ),
            updatedAt: now,
            pendingSync: true,
            active: true,
          ),
        );
      } else if (existing.memberId == null || existing.memberId!.isEmpty) {
        await _db.upsertAppUser(
          existing.copyWith(
            memberId: s.memberId,
            pendingSync: true,
            updatedAt: now,
          ),
        );
      }
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
    this.duplicateMembersCreated = 0,
    this.cancelledMembersCreated = 0,
    this.articlesCreated = 0,
    this.videosCreated = 0,
  });

  final int membersCreated;
  final int remindersCreated;
  final int duplicateMembersCreated;
  final int cancelledMembersCreated;
  final int articlesCreated;
  final int videosCreated;
}
