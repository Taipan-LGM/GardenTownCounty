import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/user_role.dart';
import 'package:garden_town_county/navigation/app_drawer_catalog.dart';

void main() {
  group('AppDrawerCatalog sync with AppPermission', () {
    test('drawer has exactly 17 items', () {
      expect(AppDrawerCatalog.items, hasLength(17));
    });

    test('RS Rights order matches drawer permission order', () {
      final drawerPerms = AppDrawerCatalog.rsRightsItems
          .map((i) => i.permission!)
          .toList();
      final managementDrawer = AppPermission.managementOrder
          .where((p) => p != AppPermission.onboarding)
          .toList();
      expect(managementDrawer, drawerPerms);
    });

    test('drawer labels match AppPermission labels', () {
      for (final item in AppDrawerCatalog.rsRightsItems) {
        final p = item.permission!;
        expect(
          p.label,
          item.label,
          reason: '${p.code} label must match drawer "${item.label}"',
        );
      }
    });

    test('defaultSecretary matches catalog flags', () {
      final fromCatalog = [
        for (final i in AppDrawerCatalog.items)
          if (i.defaultSecretary && i.permission != null) i.permission!,
      ];
      expect(AppPermission.defaultSecretary, fromCatalog);
    });

    test('adminOnly matches catalog flags', () {
      final fromCatalog = [
        for (final i in AppDrawerCatalog.items)
          if (i.adminOnly && i.permission != null) i.permission!,
      ];
      expect(AppPermission.adminOnly, fromCatalog);
    });
  });
}
