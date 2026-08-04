import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member_file.dart';
import 'package:garden_town_county/services/database_service.dart';

void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
  });

  tearDown(() async {
    await db.clearAllForTests();
  });

  test('step and confirmation persist through member file storage', () async {
    final file = MemberFile.create(
      memberId: 'member-1',
      fileName: 'proof.pdf',
      description: 'Identity proof',
      uploadedBy: 'RS User',
      stepNumber: 3,
    ).copyWith(uploadConfirmed: true);

    await db.upsertMemberFile(file);
    final stored = (await db.getFilesForMember('member-1')).single;

    expect(stored.stepNumber, 3);
    expect(stored.uploadConfirmed, isTrue);
    expect(MemberFile.fromMap(stored.toMap()).stepNumber, 3);
    expect(
      MemberFile.fromFirestore(stored.toFirestore()).uploadConfirmed,
      isTrue,
    );
  });

  test(
    'shared template edit updates matching uploads for every member',
    () async {
      for (final memberId in ['member-1', 'member-2']) {
        await db.upsertMemberFile(
          MemberFile.create(
            memberId: memberId,
            fileName: '$memberId.pdf',
            description: 'ID Document',
            uploadedBy: 'Admin',
            stepNumber: 1,
          ),
        );
      }
      await db.upsertMemberFile(
        MemberFile.create(
          memberId: 'member-2',
          fileName: 'other.pdf',
          description: 'Other Step',
          uploadedBy: 'Admin',
          stepNumber: 2,
        ),
      );

      await db.updateMemberFileDescriptionsForStep(1, {
        'ID Document': 'Identity Document',
      });

      expect(
        (await db.getFilesForMember('member-1')).single.description,
        'Identity Document',
      );
      final memberTwoFiles = await db.getFilesForMember('member-2');
      expect(
        memberTwoFiles.firstWhere((file) => file.stepNumber == 1).description,
        'Identity Document',
      );
      expect(
        memberTwoFiles.firstWhere((file) => file.stepNumber == 2).description,
        'Other Step',
      );
    },
  );
}
