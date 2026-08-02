import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/reminder.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/demo_data_service.dart';
import 'package:garden_town_county/services/smart_auto_assignment_service.dart';

void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
  });

  group('DemoDataService', () {
    test(
      'creates payment summary data, reminders, duplicates, and media',
      () async {
        final result = await DemoDataService(db).generateDemoData();
        expect(result.membersCreated, 37);
        expect(result.remindersCreated, 10);
        expect(result.duplicateMembersCreated, 6);
        expect(result.cancelledMembersCreated, 5);
        expect(result.articlesCreated, 8);
        expect(result.videosCreated, 6);

        final members = await db.getAllMembers();
        expect(members.length, 46);
        expect(
          members.where((m) => RegExp(r'^demo_\d{3}$').hasMatch(m.id)).length,
          10,
        );
        expect(members.where((m) => m.id.startsWith('dup_')).length, 6);
        expect(members.where((m) => m.id.startsWith('pay_demo_')).length, 27);

        final records = await db.getAllRemunerationRecords();
        final memberById = {for (final member in members) member.id: member};
        final stepAmounts = <int, double>{};
        final completedMemberCounts = <int, int>{};
        for (var step = 1; step <= 5; step++) {
          final completedRecords = <dynamic>[];
          for (final record in records) {
            final files = await db.getFilesForMember(record.memberId);
            final hasStepPdf = files.any(
              (file) =>
                  file.contentType == 'application/pdf' &&
                  file.fileName == 'step_${step}_completed.pdf',
            );
            if (record.status == 'paid' &&
                record.type == 'step$step' &&
                (memberById[record.memberId]?.isStepCompleteAt(step) ??
                    false) &&
                (step == 5 || hasStepPdf)) {
              completedRecords.add(record);
            }
          }
          stepAmounts[step] = completedRecords.fold<double>(
            0,
            (total, record) => total + record.amount,
          );
          completedMemberCounts[step] = completedRecords
              .map((record) => record.memberId)
              .toSet()
              .length;
        }

        expect(stepAmounts, {1: 1200, 2: 1600, 3: 2100, 4: 0, 5: 0});
        expect(completedMemberCounts, {1: 12, 2: 8, 3: 7, 4: 0, 5: 0});
        expect(stepAmounts.values.fold<double>(0, (a, b) => a + b), 4900);
        expect(completedMemberCounts.values.fold<int>(0, (a, b) => a + b), 27);
        expect(records.where((record) => record.status == 'paid').length, 27);

        final cancelled = await db.getCancelledMembers();
        expect(cancelled.where((m) => m.id.startsWith('can_')).length, 5);

        final groups = await db.findDuplicateMemberGroups();
        expect(groups.length, greaterThanOrEqualTo(3));

        final articles = await db.getAllArticles();
        expect(articles.where((a) => a.id.startsWith('art_')).length, 8);

        final videos = await db.getAllVideos();
        expect(videos.where((v) => v.id.startsWith('vid_')).length, 6);

        final rem002 = await db.getReminderById('rem_demo_002');
        expect(rem002?.assignedSecretaryId, isNotNull);

        final rem001 = await db.getReminderById('rem_demo_001');
        expect(rem001?.assignedSecretaryId, isNull);

        await DemoDataService(db).generateDemoData();
        expect((await db.getAllMembers()).length, 46);
        expect((await db.getAllRemunerationRecords()).length, 27);
      },
    );
  });

  group('SmartAutoAssignmentService', () {
    test('assigns only unassigned and balances workload', () async {
      final now = DateTime.now().toUtc();
      await db.upsertAppUser(
        AppUser(
          id: 's1',
          username: 'sec1',
          displayName: 'Sec One',
          passwordHash: 'x',
          role: UserRole.secretary.storageName,
          updatedAt: now,
        ),
      );
      await db.upsertAppUser(
        AppUser(
          id: 's2',
          username: 'sec2',
          displayName: 'Sec Two',
          passwordHash: 'x',
          role: UserRole.secretary.storageName,
          updatedAt: now,
        ),
      );

      Future<void> seedReminder({
        required String id,
        required String memberId,
        required int step,
        String? secretaryId,
      }) async {
        await db.upsertMember(
          Member(
            id: memberId,
            saId: '9${memberId.hashCode.abs()}'
                .padRight(13, '0')
                .substring(0, 13),
            globalRecordNo: 'G-$memberId',
            memberName: 'M',
            surname: memberId,
            updatedAt: now,
          ),
        );
        await db.upsertReminder(
          Reminder(
            id: id,
            memberId: memberId,
            createdBy: 'test',
            title: 'Step $step',
            reminderDateTime: now.add(const Duration(hours: 12)),
            createdAt: now,
            updatedAt: now,
            kind: 'onboarding',
            stepNumber: step,
            stepDescription: ReminderStep.getDescription(step),
            expiryDate: now.add(Duration(hours: 24 - step)),
            status: 'active',
            assignedSecretaryId: secretaryId,
            assignedSecretaryName: secretaryId == null ? null : 'Sec',
            assignmentMethod: secretaryId == null ? null : 'manual',
          ),
        );
      }

      await seedReminder(id: 'r1', memberId: 'm1', step: 1, secretaryId: 's1');
      await seedReminder(id: 'r2', memberId: 'm2', step: 3);
      await seedReminder(id: 'r3', memberId: 'm3', step: 1);
      await seedReminder(id: 'r4', memberId: 'm4', step: 2);

      final result = await SmartAutoAssignmentService(db).autoAssignAll();
      expect(result.success, isTrue);
      expect(result.assignedCount, 3);
      expect(result.totalUnassigned, 3);

      final r1 = await db.getReminderById('r1');
      expect(r1?.assignedSecretaryId, 's1'); // untouched manual

      final r2 = await db.getReminderById('r2');
      // Step 3 first → goes to least loaded (s2 has 0)
      expect(r2?.assignedSecretaryId, 's2');

      final counts = <String, int>{};
      for (final id in ['r2', 'r3', 'r4']) {
        final rem = await db.getReminderById(id);
        final sid = rem!.assignedSecretaryId!;
        counts[sid] = (counts[sid] ?? 0) + 1;
      }
      // After auto: s1 had 1 already; 3 new → final loads should be close
      final s1Total = 1 + (counts['s1'] ?? 0);
      final s2Total = counts['s2'] ?? 0;
      expect((s1Total - s2Total).abs() <= 1, isTrue);
    });

    test('returns failure when no secretaries', () async {
      final result = await SmartAutoAssignmentService(db).autoAssignAll();
      expect(result.success, isFalse);
      expect(result.message, contains('No active'));
    });
  });
}
