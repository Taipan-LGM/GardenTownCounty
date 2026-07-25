import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/services/activity_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/reminder_notification_service.dart';
import 'package:garden_town_county/services/reminder_service.dart';
import 'package:garden_town_county/services/step1_validator.dart';
import 'package:garden_town_county/services/step_activation_service.dart';
import 'package:garden_town_county/services/sync_engine.dart';

Member _completeMember({bool step1Done = false}) {
  final now = DateTime.now().toUtc();
  return Member(
    id: 'm_step1',
    saId: '9001014800089',
    globalRecordNo: '1234567890',
    lroRecordNo: 'LRO2026-001',
    memberName: 'Thabo',
    surname: 'Ndlovu',
    address: '1 Main Rd',
    suburb: 'Heatherlands',
    townCity: 'George',
    postalCode: '6529',
    contactNo1: '0821111111',
    contactNo2: '0822222222',
    emailAddress: 'thabo@example.com',
    step1MemberInfoComplete: step1Done,
    registrationStatus: 'pending',
    updatedAt: now,
  );
}

void main() {
  group('Step1Validator', () {
    test('requires all fields including LRO Record No.', () {
      expect(Step1Validator.isStep1Complete(_completeMember()), isTrue);

      final missingLro = _completeMember().copyWith(clearLroRecordNo: true);
      expect(Step1Validator.isStep1Complete(missingLro), isFalse);

      final missingEmail =
          _completeMember().copyWith(emailAddress: '');
      expect(Step1Validator.isStep1Complete(missingEmail), isFalse);
    });
  });

  group('StepActivationService', () {
    late DatabaseService db;
    late StepActivationService service;

    setUp(() async {
      db = DatabaseService.instance;
      await db.initForTests();
      final sync = SyncEngine(db);
      service = StepActivationService(
        db,
        ReminderService(
          db,
          sync,
          ReminderNotificationService(db),
          activityService: ActivityService(db, sync),
        ),
        ActivityService(db, sync),
        notifications: ReminderNotificationService(db),
      );
    });

    test('auto-activates step 1 when fields complete', () async {
      final member = _completeMember();
      await db.upsertMember(member);

      final updated = await service.checkAndActivateStep1(member);
      expect(updated.step1MemberInfoComplete, isTrue);
      expect(updated.step1ApprovedBy, 'system');
      expect(updated.registrationStatus, 'in_progress');

      final stored = await db.getMemberById(member.id);
      expect(stored?.step1MemberInfoComplete, isTrue);
    });

    test('no-op when already complete or incomplete', () async {
      final incomplete =
          _completeMember().copyWith(emailAddress: '');
      await db.upsertMember(incomplete);
      final still = await service.checkAndActivateStep1(incomplete);
      expect(still.step1MemberInfoComplete, isFalse);

      final done = _completeMember(step1Done: true);
      await db.upsertMember(done);
      final again = await service.checkAndActivateStep1(done);
      expect(again.step1MemberInfoComplete, isTrue);
      expect(again.step1ApprovedBy, isNull); // unchanged from create
    });
  });
}
