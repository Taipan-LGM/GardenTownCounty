import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/reminder.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/reminder_notification_service.dart';
import 'package:garden_town_county/services/reminder_service.dart';
import 'package:garden_town_county/services/sync_engine.dart';

void main() {
  late DatabaseService db;
  late ReminderService service;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
    final sync = SyncEngine(db);
    service = ReminderService(
      db,
      sync,
      ReminderNotificationService(db),
    );
  });

  tearDown(() async {
    await db.clearAllForTests();
  });

  Member member({
    required String id,
    bool step1 = false,
    bool step2 = false,
    bool step3 = false,
    bool step4 = false,
  }) {
    return Member.create(
      saId: '9001014800089',
      globalRecordNo: '1001',
      memberName: 'John',
      surname: 'Doe',
    ).copyWith(
      id: id,
      step1MemberInfoComplete: step1,
      step2Global528Complete: step2,
      step3Global928Complete: step3,
      step4LROComplete: step4,
    );
  }

  test('expectedStepForMember maps flags to steps', () {
    expect(ReminderService.expectedStepForMember(member(id: 'a')), 1);
    expect(
      ReminderService.expectedStepForMember(member(id: 'a', step1: true)),
      2,
    );
    expect(
      ReminderService.expectedStepForMember(
        member(id: 'a', step1: true, step2: true),
      ),
      3,
    );
    expect(
      ReminderService.expectedStepForMember(
        member(id: 'a', step1: true, step2: true, step3: true),
      ),
      4,
    );
    expect(
      ReminderService.expectedStepForMember(
        member(id: 'a', step1: true, step2: true, step3: true, step4: true),
      ),
      isNull,
    );
  });

  test('new member creates step 1 reminder with 24h expiry', () async {
    final m = member(id: 'm1');
    await service.onMemberCreated(m);
    final active = await service.getActiveReminders();
    expect(active, hasLength(1));
    expect(active.first.stepNumber, 1);
    expect(active.first.status, 'active');
    expect(active.first.expiryDate, isNotNull);
    final remaining = active.first.expiryDate!.difference(DateTime.now().toUtc());
    expect(remaining.inHours, inInclusiveRange(23, 24));
  });

  test('step completion advances 1→2→3→4 then removes', () async {
    final m = member(id: 'm1');
    await service.onMemberCreated(m);

    await service.syncFromMember(member(id: 'm1', step1: true));
    expect((await service.getActiveReminders()).single.stepNumber, 2);

    await service.syncFromMember(member(id: 'm1', step1: true, step2: true));
    expect((await service.getActiveReminders()).single.stepNumber, 3);

    await service.syncFromMember(
      member(id: 'm1', step1: true, step2: true, step3: true),
    );
    expect((await service.getActiveReminders()).single.stepNumber, 4);

    await service.syncFromMember(
      member(id: 'm1', step1: true, step2: true, step3: true, step4: true),
    );
    expect(await service.getActiveReminders(), isEmpty);
  });

  test('autoExpireReminders marks expired active reminders', () async {
    final r = Reminder.createOnboarding(
      memberId: 'm1',
      memberName: 'Jane',
      surname: 'Smith',
      saId: '9001014800089',
      stepNumber: 2,
    ).copyWith(
      expiryDate: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      reminderDateTime:
          DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await db.upsertReminder(r);
    await service.autoExpireReminders();
    expect(await service.getActiveReminders(), isEmpty);
    final stored = await db.getReminderById(r.id);
    expect(stored?.status, 'expired');
    expect(stored?.isCompleted, isTrue);
  });

  test('stats count by step', () async {
    await service.onMemberCreated(member(id: 'a'));
    await service.onMemberCreated(
      member(id: 'b').copyWith(globalRecordNo: '1002', saId: '8001015009087'),
    );
    await service.syncFromMember(member(id: 'a', step1: true));
    final stats = await service.getReminderStats();
    expect(stats.total, 2);
    expect(stats.step1, 1);
    expect(stats.step2, 1);
  });
}
