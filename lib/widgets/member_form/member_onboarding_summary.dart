import 'package:flutter/material.dart';

import '../../models/member.dart';
import '../../models/remuneration_settings.dart';
import '../standard_buttons.dart';

class MemberOnboardingSummary extends StatelessWidget {
  const MemberOnboardingSummary({
    super.key,
    required this.member,
    required this.remunerationSettings,
    required this.readOnly,
    required this.showCompleteButton,
    required this.onToggleStep,
    required this.onComplete,
  });

  final Member member;
  final RemunerationSettings remunerationSettings;
  final bool readOnly;
  final bool showCompleteButton;
  final Future<void> Function(int step, bool complete) onToggleStep;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final configuredSteps = remunerationSettings.configuredSteps;
    final stepNumbers = configuredSteps.map((step) => step.number);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Onboarding progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showCompleteButton)
                SubmitButton(onPressed: onComplete, text: 'Complete'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Steps completed: ${member.completedStepCountFor(stepNumbers)}/${configuredSteps.length}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: configuredSteps
                .map(
                  (step) => _buildStepChip(
                    context,
                    step.number,
                    '${step.name} · R ${step.amount.toStringAsFixed(2)}',
                    member.isStepCompleteAt(step.number),
                    readOnly,
                    onToggleStep,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(
    BuildContext context,
    int step,
    String label,
    bool complete,
    bool readOnly,
    Future<void> Function(int step, bool complete) onToggleStep,
  ) {
    final isDone = complete;
    return FilterChip(
      selected: isDone,
      label: Text(label),
      onSelected: readOnly ? null : (value) => onToggleStep(step, value),
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green.shade800,
    );
  }
}
