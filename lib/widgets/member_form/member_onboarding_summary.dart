import 'package:flutter/material.dart';

import '../../models/member.dart';
import '../standard_buttons.dart';

class MemberOnboardingSummary extends StatelessWidget {
  const MemberOnboardingSummary({
    super.key,
    required this.member,
    required this.readOnly,
    required this.showCompleteButton,
    required this.onToggleStep,
    required this.onComplete,
  });

  final Member member;
  final bool readOnly;
  final bool showCompleteButton;
  final Future<void> Function(int step, bool complete) onToggleStep;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
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
                SubmitButton(
                  onPressed: onComplete,
                  text: 'Complete',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Steps completed: ${member.completedStepCount}/${member.totalStepCount}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStepChip(context, 1, 'Profile', member.step1MemberInfoComplete, readOnly, onToggleStep),
              _buildStepChip(context, 2, 'Global 528', member.step2Global528Complete, readOnly, onToggleStep),
              _buildStepChip(context, 3, 'Global 928', member.step3Global928Complete, readOnly, onToggleStep),
              _buildStepChip(context, 4, 'LRO', member.step4LROComplete, readOnly, onToggleStep),
              _buildStepChip(context, 5, 'Credential Card', member.step5CredentialCardComplete, readOnly, onToggleStep),
            ],
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
