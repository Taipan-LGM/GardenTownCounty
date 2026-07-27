import 'package:flutter/material.dart';

import '../models/user_role.dart';
import 'app_section.dart';

/// How a drawer row behaves when tapped.
enum AppDrawerAction {
  navigate,
  search,
  demoData,
  signOut,
}

/// Single source of truth for left-drawer rows + Recording Secretary Rights.
///
/// **Future drawer changes:** edit [AppDrawerCatalog.items] only, then mirror
/// any new [AppPermission] codes/lists in `user_role.dart`. The sync test
/// fails if drawer labels/permissions drift from RS Rights order.
class AppDrawerItemDef {
  const AppDrawerItemDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
    this.permission,
    this.section,
    this.adminOnly = false,
    this.defaultSecretary = false,
    this.requiredSecretary = false,
    this.alwaysVisible = false,
    this.showInRsRights = true,
    this.showDividerAfter = false,
    this.showReminderBadge = false,
    this.accentColor,
  });

  final String id;
  final String label;
  final IconData icon;
  final AppDrawerAction action;
  final AppPermission? permission;
  final AppSection? section;
  final bool adminOnly;
  final bool defaultSecretary;
  final bool requiredSecretary;
  final bool alwaysVisible;
  final bool showInRsRights;
  final bool showDividerAfter;
  final bool showReminderBadge;
  final Color? accentColor;
}

/// Canonical 17 drawer items — order is top → bottom.
class AppDrawerCatalog {
  AppDrawerCatalog._();

  static const List<AppDrawerItemDef> items = [
    AppDrawerItemDef(
      id: 'home',
      label: 'Home',
      icon: Icons.home,
      action: AppDrawerAction.navigate,
      section: AppSection.home,
      permission: AppPermission.home,
      alwaysVisible: true,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'search',
      label: 'Search',
      icon: Icons.search,
      action: AppDrawerAction.search,
      permission: AppPermission.search,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'application_form',
      label: 'Application Form',
      icon: Icons.assignment,
      action: AppDrawerAction.navigate,
      section: AppSection.memberInfo,
      permission: AppPermission.memberInfo,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'step1_global528',
      label: 'Step 1_Global 528',
      icon: Icons.numbers,
      action: AppDrawerAction.navigate,
      section: AppSection.global528,
      permission: AppPermission.global528,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'step2_global528',
      label: 'Step 2_Global 528',
      icon: Icons.numbers,
      action: AppDrawerAction.navigate,
      section: AppSection.global528Step2,
      permission: AppPermission.global528Step2,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'step3_global928',
      label: 'Step 3_Global 928',
      icon: Icons.numbers,
      action: AppDrawerAction.navigate,
      section: AppSection.global928,
      permission: AppPermission.global928,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'step4_lro',
      label: 'Step 4_LRO',
      icon: Icons.gavel,
      action: AppDrawerAction.navigate,
      section: AppSection.lro,
      permission: AppPermission.lro,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'step5_credential',
      label: 'Step 5_Credential Card',
      icon: Icons.credit_card,
      action: AppDrawerAction.navigate,
      section: AppSection.credentialCard,
      permission: AppPermission.credentialCard,
      defaultSecretary: true,
      requiredSecretary: false,
      showDividerAfter: true,
    ),
    AppDrawerItemDef(
      id: 'backup_restore',
      label: 'Backup & Restore',
      icon: Icons.backup,
      action: AppDrawerAction.navigate,
      section: AppSection.backupRestore,
      permission: AppPermission.backupRestore,
      adminOnly: true,
    ),
    AppDrawerItemDef(
      id: 'user_management',
      label: 'RS Rights',
      icon: Icons.admin_panel_settings,
      action: AppDrawerAction.navigate,
      section: AppSection.addUser,
      permission: AppPermission.userManagement,
      adminOnly: true,
    ),
    AppDrawerItemDef(
      id: 'cancellations',
      label: 'Cancellations',
      icon: Icons.cancel_outlined,
      action: AppDrawerAction.navigate,
      section: AppSection.lockedMembers,
      permission: AppPermission.cancellations,
      adminOnly: true,
      accentColor: Colors.redAccent,
    ),
    AppDrawerItemDef(
      id: 'duplicate_management',
      label: 'Duplicate Manager',
      icon: Icons.warning_amber,
      action: AppDrawerAction.navigate,
      section: AppSection.duplicateReport,
      permission: AppPermission.duplicateManagement,
      adminOnly: true,
      accentColor: Colors.orangeAccent,
    ),
    AppDrawerItemDef(
      id: 'sos',
      label: 'SOS',
      icon: Icons.sos,
      action: AppDrawerAction.navigate,
      section: AppSection.sos,
      permission: AppPermission.sos,
      defaultSecretary: true,
      requiredSecretary: false,
    ),
    AppDrawerItemDef(
      id: 'reminders',
      label: 'Reminders',
      icon: Icons.alarm,
      action: AppDrawerAction.navigate,
      section: AppSection.reminders,
      permission: AppPermission.reminders,
      defaultSecretary: true,
      requiredSecretary: false,
      showReminderBadge: true,
    ),
    AppDrawerItemDef(
      id: 'activities',
      label: 'Activities',
      icon: Icons.list_alt,
      action: AppDrawerAction.navigate,
      section: AppSection.activities,
      permission: AppPermission.activities,
      defaultSecretary: true,
      requiredSecretary: false,
      showDividerAfter: true,
    ),
    AppDrawerItemDef(
      id: 'demo_data',
      label: 'Demo Data',
      icon: Icons.science,
      action: AppDrawerAction.demoData,
      permission: AppPermission.demoData,
      adminOnly: true,
      accentColor: Colors.purpleAccent,
    ),
    AppDrawerItemDef(
      id: 'sign_out',
      label: 'Sign Out',
      icon: Icons.logout,
      action: AppDrawerAction.signOut,
      permission: AppPermission.signOut,
      alwaysVisible: true,
      adminOnly: true,
      accentColor: Colors.redAccent,
    ),
  ];

  static List<AppDrawerItemDef> get rsRightsItems =>
      items.where((i) => i.showInRsRights && i.permission != null).toList();

  /// Whether [user] may see this drawer row.
  static bool isVisible({
    required AppDrawerItemDef item,
    required bool isAdmin,
    required bool Function(AppPermission permission) hasPermission,
  }) {
    if (item.alwaysVisible) return true;
    if (item.adminOnly) return isAdmin;
    final p = item.permission;
    if (p == null) return isAdmin;
    return isAdmin || hasPermission(p);
  }
}
