import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/live_view_data.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/secretary_remuneration.dart';

void main() {
  test('rolls up demo steps, finances, members, and bottlenecks', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final members = List.generate(35, (index) {
      final sequence = index + 1;
      final step = sequence <= 12
          ? 1
          : sequence <= 20
          ? 2
          : sequence <= 27
          ? 3
          : sequence <= 32
          ? 4
          : 5;
      return _member(sequence, step, now);
    });
    final amounts = <int, double>{1: 100, 2: 200, 3: 300, 4: 250, 5: 250};
    final records = members.map((member) {
      final step = member.completedStepCount;
      return SecretaryRemuneration(
        id: 'record-${member.id}',
        secretaryId: step.isEven ? 'rs-2' : 'rs-1',
        secretaryName: step.isEven ? 'Bob Johnson' : 'Jane Smith',
        memberId: member.id,
        memberName: member.memberName,
        type: 'step$step',
        description: 'Demo Step $step',
        amount: amounts[step]!,
        status: 'paid',
        dateEarned: now,
      );
    }).toList();
    final data = LiveViewData(
      members: members,
      remunerationRecords: records,
      activities: const [],
      generatedAt: now,
    );

    expect(data.totalMembers, 35);
    expect(data.newMembers, 35);
    expect(data.membersByStep, {1: 12, 2: 8, 3: 7, 4: 5, 5: 3});
    expect(data.trackedNewMembers, 35);
    expect(data.totalEarned, 6900);
    expect(data.totalPaid, 6900);
    expect(data.totalOutstanding, 0);
    expect(
      data.secretaryMetrics.fold<double>(
        0,
        (sum, item) => sum + item.totalEarned,
      ),
      6900,
    );
    expect(data.stepMetrics[2].averageDays, closeTo(7.8, 0.001));
    expect(data.stepMetrics[2].status, 'Bottleneck');
  });
}

Member _member(int sequence, int step, DateTime now) {
  final created = now.subtract(const Duration(days: 20));
  final dates = <DateTime>[
    created.add(const Duration(hours: 60)),
    created.add(const Duration(hours: 160, minutes: 48)),
    created.add(const Duration(hours: 348)),
    created.add(const Duration(hours: 422, minutes: 24)),
    created.add(const Duration(hours: 458, minutes: 24)),
  ];
  return Member(
    id: 'member-$sequence',
    saId: '$sequence',
    globalRecordNo: 'GR$sequence',
    memberName: 'Member $sequence',
    surname: 'Demo',
    registrationStatus: 'in_progress',
    registrationDate: created,
    createdAt: created,
    step1MemberInfoComplete: step >= 1,
    step2Global528Complete: step >= 2,
    step3Global928Complete: step >= 3,
    step4LROComplete: step >= 4,
    step5CredentialCardComplete: step >= 5,
    step1CompletionDate: step >= 1 ? dates[0] : null,
    step2CompletionDate: step >= 2 ? dates[1] : null,
    step3CompletionDate: step >= 3 ? dates[2] : null,
    step4CompletionDate: step >= 4 ? dates[3] : null,
    step5CompletionDate: step >= 5 ? dates[4] : null,
    updatedAt: now,
  );
}
