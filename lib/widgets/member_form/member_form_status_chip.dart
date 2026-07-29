import 'package:flutter/material.dart';

import '../../models/member.dart';
import '../../models/member_form_mode.dart';

/// Chip summarising the form mode and the member's registration status.
class MemberFormStatusChip extends StatelessWidget {
  const MemberFormStatusChip({
    super.key,
    required this.mode,
    required this.member,
  });

  final MemberFormMode mode;
  final Member? member;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (mode) {
      case MemberFormMode.newMember:
        color = Colors.orange;
      case MemberFormMode.regularMember:
        color = Colors.blue;
      case MemberFormMode.lockedSecretary:
      case MemberFormMode.lockedAdmin:
        color = Colors.red;
      case MemberFormMode.tempAccessActive:
        color = Colors.green;
    }
    final label = member == null
        ? 'New'
        : '${mode.statusLabel} · ${member!.registrationStatus}';
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
