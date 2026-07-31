import 'package:flutter/material.dart';

import '../../models/member.dart';
import '../../widgets/member_nav/profile_navigation_bar.dart';
import '../standard_buttons.dart';

class MemberProfileNavSection extends StatelessWidget {
  const MemberProfileNavSection({
    super.key,
    required this.currentMember,
    required this.currentIndex,
    required this.totalMembers,
    required this.previousName,
    required this.nextName,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onFirst,
    required this.onLast,
    required this.canEdit,
    required this.canNew,
    required this.showRsRadio,
    required this.rsRadioOn,
    required this.rsRadioEnabled,
    required this.onEdit,
    required this.onNew,
    required this.onUpload,
    required this.onRsRadioChanged,
  });

  final Member currentMember;
  final int currentIndex;
  final int totalMembers;
  final String? previousName;
  final String? nextName;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirst;
  final VoidCallback onLast;
  final bool canEdit;
  final bool canNew;
  final bool showRsRadio;
  final bool rsRadioOn;
  final bool rsRadioEnabled;
  final VoidCallback? onEdit;
  final Future<void> Function()? onNew;
  final Future<void> Function()? onUpload;
  final ValueChanged<bool> onRsRadioChanged;

  @override
  Widget build(BuildContext context) {
    return ProfileNavigationBar(
      currentMember: currentMember,
      currentIndex: currentIndex,
      totalMembers: totalMembers,
      previousName: previousName,
      nextName: nextName,
      onBack: onBack,
      onPrevious: onPrevious,
      onNext: onNext,
      onFirst: onFirst,
      onLast: onLast,
      canEdit: canEdit,
      canDelete: false,
      onDelete: null,
      onEdit: onEdit,
      onNew: onNew,
      canNew: canNew,
      onUpload: onUpload,
      showRsRadio: showRsRadio,
      rsRadioOn: rsRadioOn,
      rsRadioEnabled: rsRadioEnabled,
      onRsRadioChanged: onRsRadioChanged,
    );
  }
}
