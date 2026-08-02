import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garden_town_county/models/member.dart';
import 'package:garden_town_county/models/remuneration_settings.dart';
import 'package:garden_town_county/providers/providers.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/reminder_service.dart';

void main() {
  group('Five-step onboarding flow', () {
    test(
      'counts five onboarding steps and completes only when step 5 is done',
      () {
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
      },
    );

    test(
      'remuneration settings expose five step amounts and bank particulars',
      () {
        final settings = RemunerationSettings.defaults();
        expect(settings.step1Amount, 100);
        expect(settings.step5Amount, 250);
        expect(settings.bankAccountName, isNotEmpty);
        expect(settings.bankName, isNotEmpty);
      },
    );

    test('custom step names survive persistence mapping', () {
      final original = RemunerationSettings.defaults().copyWith(
        step1Name: 'Welcome Step',
        step2Name: 'Document Review',
        step3Name: 'County Approval',
        step4Name: 'LRO Review',
        step5Name: 'Issue Credential',
      );

      final restored = RemunerationSettings.fromMap(original.toMap());

      expect(restored.stepName(1), 'Welcome Step');
      expect(restored.stepName(2), 'Document Review');
      expect(restored.stepName(3), 'County Approval');
      expect(restored.stepName(4), 'LRO Review');
      expect(restored.stepName(5), 'Issue Credential');
    });

    test('dynamic steps preserve stable numbers through persistence', () {
      final settings = RemunerationSettings.defaults().copyWith(
        steps: const [
          RemunerationStep(number: 1, name: 'Application', amount: 250),
          RemunerationStep(number: 6, name: 'Final Review', amount: 75),
        ],
      );

      final restored = RemunerationSettings.fromMap(settings.toMap());

      expect(restored.configuredSteps.map((step) => step.number), [1, 6]);
      expect(restored.stepName(6), 'Final Review');
      expect(restored.stepAmount(6), 75);
      expect(restored.configuredTotalAmount, 325);
      expect(restored.nextStepNumber, 7);
    });

    test('removed steps retain their historical number and are not reused', () {
      final settings = RemunerationSettings.defaults().copyWith(
        steps: const [
          RemunerationStep(number: 1, name: 'Application', amount: 250),
          RemunerationStep(
            number: 6,
            name: 'Archived Review',
            amount: 75,
            active: false,
          ),
        ],
      );

      final restored = RemunerationSettings.fromMap(settings.toMap());

      expect(restored.configuredSteps.map((step) => step.number), [1]);
      expect(restored.stepName(6), 'Archived Review');
      expect(restored.nextStepNumber, 7);
    });

    test('dynamic completion and reminders follow configured order', () {
      final member = Member(
        id: 'm-dynamic',
        saId: '1234567890123',
        globalRecordNo: 'GR-DYNAMIC',
        memberName: 'Dynamic',
        surname: 'Member',
        step1MemberInfoComplete: true,
        updatedAt: DateTime.utc(2024, 1, 1),
        additionalStepStates: const {6: MemberStepState(complete: false)},
      );

      expect(member.completedStepCountFor([1, 6]), 1);
      expect(member.allStepsCompleteFor([1, 6]), isFalse);
      expect(ReminderService.expectedStepForMember(member, [1, 6]), 6);

      final completed = member.withStepState(
        step: 6,
        complete: true,
        changedAt: DateTime.utc(2024, 1, 2),
        approvedBy: 'admin',
      );
      final restored = Member.fromMap(completed.toMap());

      expect(restored.isStepCompleteAt(6), isTrue);
      expect(restored.allStepsCompleteFor([1, 6]), isTrue);
      expect(ReminderService.expectedStepForMember(restored, [1, 6]), isNull);
    });

    test(
      'saving settings immediately updates active Payments listeners',
      () async {
        final database = DatabaseService.instance;
        await database.initForTests();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        addTearDown(database.clearAllForTests);

        final initial = await container.read(
          remunerationSettingsProvider.future,
        );
        final observed = <RemunerationSettings>[];
        final subscription = container.listen(remunerationSettingsProvider, (
          _,
          next,
        ) {
          final settings = next.valueOrNull;
          if (settings != null) observed.add(settings);
        }, fireImmediately: true);
        addTearDown(subscription.close);

        final updated = initial.copyWith(
          step1Name: 'Updated Payment Step',
          step1Amount: 275,
          steps: [
            for (final step in initial.allSteps)
              step.number == 1
                  ? step.copyWith(name: 'Updated Payment Step', amount: 275)
                  : step,
          ],
        );
        await container
            .read(remunerationSettingsProvider.notifier)
            .save(updated);

        final visible = container
            .read(remunerationSettingsProvider)
            .requireValue;
        final persisted = await database.getRemunerationSettings();
        expect(visible.stepName(1), 'Updated Payment Step');
        expect(visible.stepAmount(1), 275);
        expect(observed.last.stepName(1), 'Updated Payment Step');
        expect(observed.last.stepAmount(1), 275);
        expect(persisted.stepName(1), 'Updated Payment Step');
        expect(persisted.stepAmount(1), 275);
      },
    );
  });
}
