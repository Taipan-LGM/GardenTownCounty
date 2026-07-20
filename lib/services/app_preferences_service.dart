import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, afrikaans }

class AppPreferencesService {
  static const _themeKey = 'gtc_theme_mode';
  static const _langKey = 'gtc_language';

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeKey)) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await prefs.setString(_themeKey, value);
  }

  Future<AppLanguage> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) == 'af'
        ? AppLanguage.afrikaans
        : AppLanguage.english;
  }

  Future<void> saveLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _langKey,
      language == AppLanguage.afrikaans ? 'af' : 'en',
    );
  }
}
