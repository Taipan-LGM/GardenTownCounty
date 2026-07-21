import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/member_navigation_state.dart';

/// Persist recently viewed + favorites for Member Info navigation.
class MemberNavigationPrefs {
  static const _recentKey = 'member_nav_recent_v1';
  static const _favoritesKey = 'member_nav_favorites_v1';

  Future<List<RecentlyViewedEntry>> loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => RecentlyViewedEntry.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.memberId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveRecent(List<RecentlyViewedEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_recentKey, encoded);
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? const [];
    return list.toSet();
  }

  Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, ids.toList());
  }
}
