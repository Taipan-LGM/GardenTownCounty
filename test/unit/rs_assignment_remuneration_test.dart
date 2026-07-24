import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/app_user.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/services/auto_assignment_service.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/remuneration_service.dart';

void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
  });

  group('AutoAssignmentService', () {
    test('picks secretary with fewest assigned members', () async {
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
      await db.upsertMember(
        Member(
          id: 'm1',
          saId: '9001014800089',
          globalRecordNo: 'G1',
          memberName: 'A',
          surname: 'B',
          assignedSecretaryId: 's1',
          updatedAt: now,
        ),
      );

      final best = await AutoAssignmentService(db).findBestSecretary();
      expect(best?.id, 's2');
    });
  });

  group('RemunerationService', () {
    test('creates pending step2 earning once', () async {
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
      await db.upsertMember(
        Member(
          id: 'm1',
          saId: '9001014800089',
          globalRecordNo: 'G1',
          memberName: 'John',
          surname: 'Doe',
          assignedSecretaryId: 's1',
          updatedAt: now,
        ),
      );

      final service = RemunerationService(db);
      final first = await service.calculateStepRemuneration(
        memberId: 'm1',
        stepNumber: 2,
        secretaryId: 's1',
      );
      final second = await service.calculateStepRemuneration(
        memberId: 'm1',
        stepNumber: 2,
        secretaryId: 's1',
      );

      expect(first, isNotNull);
      expect(first!.amount, 200);
      expect(first.status, 'pending');
      expect(second, isNull);

      final summary = await service.getSecretarySummary('s1');
      expect(summary.recordCount, 1);
      expect(summary.pendingAmount, 200);
    });
  });
}
