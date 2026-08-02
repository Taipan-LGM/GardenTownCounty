import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/member.dart';
import '../models/remuneration_settings.dart';
import 'standard_buttons.dart';

final _dayFmt = DateFormat('yyyy-MM-dd');

/// 4-step onboarding checklist embedded in Member Info.
class OnboardingChecklistCard extends StatelessWidget {
  const OnboardingChecklistCard({
    super.key,
    required this.member,
    required this.remunerationSettings,
    required this.readOnly,
    required this.onToggleStep,
    this.onComplete,
    this.showCompleteButton = false,
  });

  final Member member;
  final RemunerationSettings remunerationSettings;
  final bool readOnly;
  final Future<void> Function(int step, bool complete) onToggleStep;
  final VoidCallback? onComplete;
  final bool showCompleteButton;

  int get _doneCount {
    var n = 0;
    if (member.step1MemberInfoComplete) n++;
    if (member.step2Global528Complete) n++;
    if (member.step3Global928Complete) n++;
    if (member.step4LROComplete) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _doneCount / 4.0;
    final allDone = member.allStepsComplete;

    return Card(
      color: AppTheme.forestGreen.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '✅ ONBOARDING PROGRESS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.bodyText,
              ),
            ),
            const Divider(),
            const Text(
              'Member must complete 4 steps to become fully fledged:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            _stepRow(
              step: 1,
              label: remunerationSettings.stepName(1),
              done: member.step1MemberInfoComplete,
              date: member.step1CompletionDate,
            ),
            _stepRow(
              step: 2,
              label: remunerationSettings.stepName(2),
              done: member.step2Global528Complete,
              date: member.step2CompletionDate,
            ),
            _stepRow(
              step: 3,
              label: remunerationSettings.stepName(3),
              done: member.step3Global928Complete,
              date: member.step3CompletionDate,
            ),
            _stepRow(
              step: 4,
              label: remunerationSettings.stepName(4),
              done: member.step4LROComplete,
              date: member.step4CompletionDate,
            ),
            const SizedBox(height: 12),
            Text(
              'Overall Progress: ${(_doneCount * 25)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                color: AppTheme.bodyText,
              ),
            ),
            if (showCompleteButton) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SubmitButton(
                  onPressed: allDone && !readOnly ? onComplete : null,
                  text: 'Complete Member',
                  icon: Icons.verified,
                ),
              ),
              if (!allDone)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Complete button enables when all 4 steps are checked.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepRow({
    required int step,
    required String label,
    required bool done,
    required DateTime? date,
  }) {
    final status = done
        ? '✅ Completed${date != null ? ' (${_dayFmt.format(date.toLocal())})' : ''}'
        : '⬜ Pending';
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: done,
      onChanged: readOnly
          ? null
          : (v) {
              onToggleStep(step, v ?? false);
            },
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(status, style: const TextStyle(fontSize: 12)),
    );
  }
}
