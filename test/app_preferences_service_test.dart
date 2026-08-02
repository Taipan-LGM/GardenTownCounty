import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/app_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dark is default while saved theme choices are preserved', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AppPreferencesService();

    expect(await service.loadThemeMode(), ThemeMode.dark);

    await service.saveThemeMode(ThemeMode.light);
    expect(await service.loadThemeMode(), ThemeMode.light);
  });
}
