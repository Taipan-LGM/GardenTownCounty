import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/county_profile.dart';
import 'county_logo_store_stub.dart'
    if (dart.library.io) 'county_logo_store_io.dart' as store;

/// Persists county identity + uploaded logos.
///
/// Multi-county: every key is namespaced by the active county id
/// (`gtc_county_<id>_...`). On first load for a county that has no profile
/// yet, the previously-global `gtc_county_*` keys are migrated into the
/// default county so an existing install keeps its current branding.
class CountySettingsService {
  static const _globalPrefix = 'gtc_county_';

  String _prefixFor(String countyId) =>
      countyId.isEmpty ? _globalPrefix : 'gtc_county_${countyId}_';

  Future<CountyProfile> load({String countyId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefixFor(countyId);
    final raw = CountyProfile.fromPrefs({
      'countyName': prefs.getString('${prefix}name'),
      'countyAddress': prefs.getString('${prefix}address'),
      'countyRegNo': prefs.getString('${prefix}reg'),
      'countyContactNo': prefs.getString('${prefix}contact'),
      'logoPath': prefs.getString('${prefix}logo'),
      'secondaryLogoPath': prefs.getString('${prefix}logo2'),
    });

    // Migration: if this county has no name and the legacy global keys exist,
    // copy them into this county once.
    final hasAny = raw.countyName.trim().isNotEmpty ||
        raw.logoPath != null ||
        raw.secondaryLogoPath != null;
    if (!hasAny && countyId.isNotEmpty) {
      final legacy = CountyProfile.fromPrefs({
        'countyName': prefs.getString('${_globalPrefix}name'),
        'countyAddress': prefs.getString('${_globalPrefix}address'),
        'countyRegNo': prefs.getString('${_globalPrefix}reg'),
        'countyContactNo': prefs.getString('${_globalPrefix}contact'),
        'logoPath': prefs.getString('${_globalPrefix}logo'),
        'secondaryLogoPath': prefs.getString('${_globalPrefix}logo2'),
      });
      final legacyHasAny = legacy.countyName.trim().isNotEmpty ||
          legacy.logoPath != null ||
          legacy.secondaryLogoPath != null;
      if (legacyHasAny) {
        await _writeAll(prefs, prefix, legacy);
        return legacy;
      }
    }
    return raw;
  }

  Future<void> _writeAll(
    SharedPreferences prefs,
    String prefix,
    CountyProfile profile,
  ) async {
    await prefs.setString('${prefix}name', profile.countyName);
    await prefs.setString('${prefix}address', profile.countyAddress);
    await prefs.setString('${prefix}reg', profile.countyRegNo);
    await prefs.setString('${prefix}contact', profile.countyContactNo);
    if (profile.logoPath != null) {
      await prefs.setString('${prefix}logo', profile.logoPath!);
    } else {
      await prefs.remove('${prefix}logo');
    }
    if (profile.secondaryLogoPath != null) {
      await prefs.setString('${prefix}logo2', profile.secondaryLogoPath!);
    } else {
      await prefs.remove('${prefix}logo2');
    }
  }

  Future<CountyProfile> save(CountyProfile profile,
      {String countyId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefixFor(countyId);
    await prefs.setString('${prefix}name', profile.countyName);
    await prefs.setString('${prefix}address', profile.countyAddress);
    await prefs.setString('${prefix}reg', profile.countyRegNo);
    await prefs.setString('${prefix}contact', profile.countyContactNo);
    if (profile.logoPath != null) {
      await prefs.setString('${prefix}logo', profile.logoPath!);
    } else {
      await prefs.remove('${prefix}logo');
    }
    if (profile.secondaryLogoPath != null) {
      await prefs.setString('${prefix}logo2', profile.secondaryLogoPath!);
    } else {
      await prefs.remove('${prefix}logo2');
    }
    return profile;
  }

  /// Saves uploaded logo bytes; returns absolute path (or virtual web path).
  Future<String> saveLogoBytes(
    Uint8List bytes, {
    required bool secondary,
    String countyId = '',
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _prefixFor(countyId);
      final key = secondary ? '${prefix}logo2_b64' : '${prefix}logo_b64';
      if (bytes.length > 900000) {
        throw Exception('Logo file too large (max ~900 KB).');
      }
      final encoded =
          Uri.dataFromBytes(bytes, mimeType: 'image/png').toString();
      await prefs.setString(key, encoded);
      final marker = secondary ? 'web://logo2' : 'web://logo';
      await prefs.setString(
        secondary ? '${prefix}logo2' : '${prefix}logo',
        marker,
      );
      return marker;
    }

    return store.saveLogoToDisk(bytes, secondary: secondary);
  }

  Future<Uint8List?> loadWebLogoBytes({
    required bool secondary,
    String countyId = '',
  }) async {
    if (!kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefixFor(countyId);
    final key = secondary ? '${prefix}logo2_b64' : '${prefix}logo_b64';
    final raw = prefs.getString(key);
    if (raw == null || !raw.startsWith('data:')) return null;
    final uri = Uri.parse(raw);
    return uri.data?.contentAsBytes();
  }
}
