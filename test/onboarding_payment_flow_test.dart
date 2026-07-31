import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/remuneration_settings.dart';

void main() {
  group('Five-step onboarding flow', () {
    test('counts five onboarding steps and completes only when step 5 is done', () {
      final member = Member(
        id: 'm1',
        saId: '1234567890123',
        globalRecordNo: 'GR-001',
        memberName: 'Test',
        surname: 'User',
        updatedAt: DateTime.utc(2024, 1, 1),
      );

      expect(member.totalStepCount, 5);
      expect(member.completedStepCount, 0);

      final partial = member.copyWith(step1MemberInfoComplete: true);
      expect(partial.completedStepCount, 1);
      expect(partial.allStepsComplete, isFalse);

      final complete = partial.copyWith(
        step2Global528Complete: true,
        step3Global928Complete: true,
        step4LROComplete: true,
        step5CredentialCardComplete: true,
      );
      expect(complete.completedStepCount, 5);
      expect(complete.allStepsComplete, isTrue);
    });

    test('remuneration settings expose five step amounts and bank particulars', () {
      final settings = RemunerationSettings.defaults();
      expect(settings.step1Amount, 100);
      expect(settings.step5Amount, 150);
      expect(settings.bankAccountName, isNotEmpty);
      expect(settings.bankName, isNotEmpty);
    });
  });
}
