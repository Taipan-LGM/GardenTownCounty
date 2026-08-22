import 'dart:convert' show base64Decode, base64Encode, jsonEncode;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lro_settings.dart' as M;
import 'lro_settings_io.dart' if (dart.library.html) 'lro_settings_stub.dart';

/// Persists and loads Admin LRO settings using SharedPreferences.
///
/// Multi-county: every key is namespaced by the active county id
/// (`lro_<countyId>_...`). On first load for a county that has no settings
/// yet, the previously-unseeded global `lro_*` keys are migrated into the
/// default county so an existing install keeps its current LRO configuration.
class LroSettingsService {
  static const _legacyPrefix = 'lro_';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Builds the county-scoped key prefix. Empty countyId is treated as the
  /// global/legacy namespace for safety.
  String _prefixFor(String countyId) =>
      countyId.isEmpty ? _legacyPrefix : 'lro_${countyId}_';

  Map<String, String?> _readAll(
    SharedPreferences prefs,
    String prefix,
  ) =>
      {
        'countyUniqueNo': prefs.getString('${prefix}countyUniqueNo'),
        'facebookPageUrl': prefs.getString('${prefix}facebookPageUrl'),
        'numberOrder': prefs.getString('${prefix}numberOrder'),
        'publicNoticeTemplatePath':
            prefs.getString('${prefix}publicNoticeTemplatePath'),
        'publicNoticeTemplateBase64':
            prefs.getString('${prefix}publicNoticeTemplateBase64'),
        'countySealPath': prefs.getString('${prefix}countySealPath'),
        'countySealBase64': prefs.getString('${prefix}countySealBase64'),
        'statusCorrectionsJson': prefs.getString('${prefix}statusCorrectionsJson'),
      };

  Future<M.LroSettings> load({String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    final raw = _readAll(prefs, prefix);

    // Migration: if this county has no settings and the legacy global keys
    // exist, copy them into this county (once) so the first county created
    // inherits the existing install's configuration.
    final hasAny = raw.values.any((v) => v != null && v.isNotEmpty);
    if (!hasAny && countyId.isNotEmpty) {
      final legacy = _readAll(prefs, _legacyPrefix);
      final legacyHasAny = legacy.values.any((v) => v != null && v.isNotEmpty);
      if (legacyHasAny) {
        await _writeAll(prefs, prefix, legacy);
        return M.LroSettings.fromPrefs({
          'countyUniqueNo': legacy['countyUniqueNo'] ?? '',
          'facebookPageUrl': legacy['facebookPageUrl'] ?? '',
          'numberOrder': legacy['numberOrder'] ?? '',
          'publicNoticeTemplatePath': legacy['publicNoticeTemplatePath'] ?? '',
          'publicNoticeTemplateBase64': legacy['publicNoticeTemplateBase64'] ?? '',
          'countySealPath': legacy['countySealPath'] ?? '',
          'countySealBase64': legacy['countySealBase64'] ?? '',
          'statusCorrectionsJson': legacy['statusCorrectionsJson'] ?? '[]',
        });
      }
    }

    return M.LroSettings.fromPrefs({
      'countyUniqueNo': raw['countyUniqueNo'] ?? '',
      'facebookPageUrl': raw['facebookPageUrl'] ?? '',
      'numberOrder': raw['numberOrder'] ?? '',
      'publicNoticeTemplatePath': raw['publicNoticeTemplatePath'] ?? '',
      'publicNoticeTemplateBase64': raw['publicNoticeTemplateBase64'] ?? '',
      'countySealPath': raw['countySealPath'] ?? '',
      'countySealBase64': raw['countySealBase64'] ?? '',
      'statusCorrectionsJson': raw['statusCorrectionsJson'] ?? '[]',
    });
  }

  Future<void> _writeAll(
    SharedPreferences prefs,
    String prefix,
    Map<String, String?> values,
  ) async {
    for (final entry in values.entries) {
      final v = entry.value;
      if (v == null || v.isEmpty) {
        await prefs.remove('$prefix${entry.key}');
      } else {
        await prefs.setString('$prefix${entry.key}', v);
      }
    }
  }

  Future<void> save(M.LroSettings s, {String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    await prefs.setString('${prefix}countyUniqueNo', s.countyUniqueNo);
    await prefs.setString('${prefix}facebookPageUrl', s.facebookPageUrl);
    await prefs.setString('${prefix}numberOrder', s.numberOrder.name);
    if (s.publicNoticeTemplatePath != null && s.publicNoticeTemplatePath!.isNotEmpty) {
      await prefs.setString(
        '${prefix}publicNoticeTemplatePath',
        s.publicNoticeTemplatePath!,
      );
    } else {
      await prefs.remove('${prefix}publicNoticeTemplatePath');
    }
    if (s.publicNoticeTemplateBase64 != null && s.publicNoticeTemplateBase64!.isNotEmpty) {
      await prefs.setString(
        '${prefix}publicNoticeTemplateBase64',
        s.publicNoticeTemplateBase64!,
      );
    } else {
      await prefs.remove('${prefix}publicNoticeTemplateBase64');
    }
    if (s.countySealPath != null && s.countySealPath!.isNotEmpty) {
      await prefs.setString('${prefix}countySealPath', s.countySealPath!);
    } else {
      await prefs.remove('${prefix}countySealPath');
    }
    if (s.countySealBase64 != null && s.countySealBase64!.isNotEmpty) {
      await prefs.setString('${prefix}countySealBase64', s.countySealBase64!);
    } else {
      await prefs.remove('${prefix}countySealBase64');
    }
    await prefs.setString(
      '${prefix}statusCorrectionsJson',
      jsonEncode(M.LroSettings.encodeJson(s.statusCorrections)),
    );
  }

  /// Saves uploaded Public Notice Template image bytes (web base64 or desktop path).
  Future<void> savePublicNoticeTemplateBytes(Uint8List bytes, {String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    if (kIsWeb) {
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Public Notice Template image too large (max 5 MB).');
      }
      final encoded = base64Encode(bytes);
      await prefs.setString('${prefix}publicNoticeTemplateBase64', encoded);
      await prefs.setString('${prefix}publicNoticeTemplatePath', 'web://publicNoticeTemplate');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'lro_publicNoticetemplate_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';
      await writeFileBytes(filePath, bytes);
      await prefs.setString('${prefix}publicNoticeTemplatePath', filePath);
      await prefs.remove('${prefix}publicNoticeTemplateBase64');
    }
  }

  /// Saves uploaded county seal image bytes (web base64 or desktop path).
  Future<void> saveCountySealBytes(Uint8List bytes, {String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    if (kIsWeb) {
      if (bytes.length > 2 * 1024 * 1024) {
        throw Exception('County seal image too large (max 2 MB).');
      }
      final encoded = base64Encode(bytes);
      await prefs.setString('${prefix}countySealBase64', encoded);
      await prefs.setString('${prefix}countySealPath', 'web://seal');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'lro_seal_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${dir.path}/$fileName';
      await writeFileBytes(filePath, bytes);
      await prefs.setString('${prefix}countySealPath', filePath);
      await prefs.remove('${prefix}countySealBase64');
    }
  }

  /// Removes Public Notice Template and county seal images.
  Future<void> clearPublicNoticeTemplate({String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    await prefs.remove('${prefix}publicNoticeTemplatePath');
    await prefs.remove('${prefix}publicNoticeTemplateBase64');
  }

  Future<void> clearCountySeal({String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    await prefs.remove('${prefix}countySealPath');
    await prefs.remove('${prefix}countySealBase64');
  }

  /// Loads the uploaded Public Notice Template bytes (web base64 or desktop path).
  Future<Uint8List?> loadPublicNoticeTemplateBytes({String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    final path = prefs.getString('${prefix}publicNoticeTemplatePath');
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('web://')) {
        final b64 = prefs.getString('${prefix}publicNoticeTemplateBase64');
        if (b64 != null && b64.isNotEmpty) {
          return base64Decode(b64);
        }
      } else {
        try {
          return File(path).readAsBytes();
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Loads the uploaded County Seal bytes (web base64 or desktop path).
  Future<Uint8List?> loadCountySealBytes({String countyId = ''}) async {
    final prefs = await _prefs();
    final prefix = _prefixFor(countyId);
    final path = prefs.getString('${prefix}countySealPath');
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('web://')) {
        final b64 = prefs.getString('${prefix}countySealBase64');
        if (b64 != null && b64.isNotEmpty) {
          return base64Decode(b64);
        }
      } else {
        try {
          return File(path).readAsBytes();
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }
}
