import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/county_profile.dart';
import 'county_logo_store_stub.dart'
    if (dart.library.io) 'county_logo_store_io.dart' as store;

/// Persists county identity + uploaded logos.
class CountySettingsService {
  static const _prefix = 'gtc_county_';

  Future<CountyProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CountyProfile.fromPrefs({
      'countyName': prefs.getString('${_prefix}name'),
      'countyAddress': prefs.getString('${_prefix}address'),
      'countyRegNo': prefs.getString('${_prefix}reg'),
      'countyContactNo': prefs.getString('${_prefix}contact'),
      'logoPath': prefs.getString('${_prefix}logo'),
      'secondaryLogoPath': prefs.getString('${_prefix}logo2'),
    });
  }

  Future<CountyProfile> save(CountyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}name', profile.countyName);
    await prefs.setString('${_prefix}address', profile.countyAddress);
    await prefs.setString('${_prefix}reg', profile.countyRegNo);
    await prefs.setString('${_prefix}contact', profile.countyContactNo);
    if (profile.logoPath != null) {
      await prefs.setString('${_prefix}logo', profile.logoPath!);
    } else {
      await prefs.remove('${_prefix}logo');
    }
    if (profile.secondaryLogoPath != null) {
      await prefs.setString('${_prefix}logo2', profile.secondaryLogoPath!);
    } else {
      await prefs.remove('${_prefix}logo2');
    }
    return profile;
  }

  /// Saves uploaded logo bytes; returns absolute path (or virtual web path).
  Future<String> saveLogoBytes(
    Uint8List bytes, {
    required bool secondary,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = secondary ? '${_prefix}logo2_b64' : '${_prefix}logo_b64';
      if (bytes.length > 900000) {
        throw Exception('Logo file too large (max ~900 KB).');
      }
      final encoded =
          Uri.dataFromBytes(bytes, mimeType: 'image/png').toString();
      await prefs.setString(key, encoded);
      final marker = secondary ? 'web://logo2' : 'web://logo';
      await prefs.setString(
        secondary ? '${_prefix}logo2' : '${_prefix}logo',
        marker,
      );
      return marker;
    }

    return store.saveLogoToDisk(bytes, secondary: secondary);
  }

  Future<Uint8List?> loadWebLogoBytes({required bool secondary}) async {
    if (!kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final key = secondary ? '${_prefix}logo2_b64' : '${_prefix}logo_b64';
    final raw = prefs.getString(key);
    if (raw == null || !raw.startsWith('data:')) return null;
    final uri = Uri.parse(raw);
    return uri.data?.contentAsBytes();
  }
}
