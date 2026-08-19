import 'dart:convert' show base64Decode, jsonEncode;
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lro_settings.dart' as M;
import 'lro_settings_io.dart' if (dart.library.html) 'lro_settings_stub.dart';

/// Persists and loads Admin LRO settings using SharedPreferences.
class LroSettingsService {
  static const _prefix = 'lro_';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<M.LroSettings> load() async {
    final prefs = await _prefs();
    return M.LroSettings.fromPrefs({
      'countyUniqueNo': prefs.getString('${_prefix}countyUniqueNo') ?? '',
      'facebookPageUrl': prefs.getString('${_prefix}facebookPageUrl') ?? '',
      'numberOrder': prefs.getString('${_prefix}numberOrder') ?? '',
      'publicNoticeTemplatePath': prefs.getString('${_prefix}publicNoticeTemplatePath') ?? '',
      'publicNoticeTemplateBase64': prefs.getString('${_prefix}publicNoticeTemplateBase64') ?? '',
      'countySealPath': prefs.getString('${_prefix}countySealPath') ?? '',
      'countySealBase64': prefs.getString('${_prefix}countySealBase64') ?? '',
      'statusCorrectionsJson': prefs.getString('${_prefix}statusCorrectionsJson') ?? '[]',
    });
  }

  Future<void> save(M.LroSettings s) async {
    final prefs = await _prefs();
    await prefs.setString('${_prefix}countyUniqueNo', s.countyUniqueNo);
    await prefs.setString('${_prefix}facebookPageUrl', s.facebookPageUrl);
    await prefs.setString('${_prefix}numberOrder', s.numberOrder.name);
    if (s.publicNoticeTemplatePath != null && s.publicNoticeTemplatePath!.isNotEmpty) {
      await prefs.setString('${_prefix}publicNoticeTemplatePath', s.publicNoticeTemplatePath!);
    } else {
      await prefs.remove('${_prefix}publicNoticeTemplatePath');
    }
    if (s.publicNoticeTemplateBase64 != null && s.publicNoticeTemplateBase64!.isNotEmpty) {
      await prefs.setString('${_prefix}publicNoticeTemplateBase64', s.publicNoticeTemplateBase64!);
    } else {
      await prefs.remove('${_prefix}publicNoticeTemplateBase64');
    }
    if (s.countySealPath != null && s.countySealPath!.isNotEmpty) {
      await prefs.setString('${_prefix}countySealPath', s.countySealPath!);
    } else {
      await prefs.remove('${_prefix}countySealPath');
    }
    if (s.countySealBase64 != null && s.countySealBase64!.isNotEmpty) {
      await prefs.setString('${_prefix}countySealBase64', s.countySealBase64!);
    } else {
      await prefs.remove('${_prefix}countySealBase64');
    }
    await prefs.setString(
        '${_prefix}statusCorrectionsJson',
        jsonEncode(M.LroSettings.encodeJson(s.statusCorrections)));
  }

  /// Saves uploaded Public Notice Template image bytes (web base64 or desktop path).
  Future<void> savePublicNoticeTemplateBytes(Uint8List bytes) async {
    final prefs = await _prefs();
    if (kIsWeb) {
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Public Notice Template image too large (max 5 MB).');
      }
      final encoded =
          Uri.dataFromBytes(bytes, mimeType: 'image/jpeg').toString();
      await prefs.setString('${_prefix}publicNoticeTemplateBase64', encoded);
      await prefs.setString('${_prefix}publicNoticeTemplatePath', 'web://publicNoticeTemplate');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'lro_publicNoticetemplate_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';
      await writeFileBytes(filePath, bytes);
      await prefs.setString('${_prefix}publicNoticeTemplatePath', filePath);
      await prefs.remove('${_prefix}publicNoticeTemplateBase64');
    }
  }

  /// Saves uploaded county seal image bytes (web base64 or desktop path).
  Future<void> saveCountySealBytes(Uint8List bytes) async {
    final prefs = await _prefs();
    if (kIsWeb) {
      if (bytes.length > 2 * 1024 * 1024) {
        throw Exception('County seal image too large (max 2 MB).');
      }
      final encoded =
          Uri.dataFromBytes(bytes, mimeType: 'image/png').toString();
      await prefs.setString('${_prefix}countySealBase64', encoded);
      await prefs.setString('${_prefix}countySealPath', 'web://seal');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'lro_seal_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${dir.path}/$fileName';
      await writeFileBytes(filePath, bytes);
      await prefs.setString('${_prefix}countySealPath', filePath);
      await prefs.remove('${_prefix}countySealBase64');
    }
  }

  /// Removes Public Notice Template and county seal images.
  Future<void> clearPublicNoticeTemplate() async {
    final prefs = await _prefs();
    await prefs.remove('${_prefix}publicNoticeTemplatePath');
    await prefs.remove('${_prefix}publicNoticeTemplateBase64');
  }

  Future<void> clearCountySeal() async {
    final prefs = await _prefs();
    await prefs.remove('${_prefix}countySealPath');
    await prefs.remove('${_prefix}countySealBase64');
  }

  /// Loads the uploaded Public Notice Template bytes (web base64 or desktop path).
  Future<Uint8List?> loadPublicNoticeTemplateBytes() async {
    final prefs = await _prefs();
    final path = prefs.getString('${_prefix}publicNoticeTemplatePath');
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('web://')) {
        final b64 = prefs.getString('${_prefix}publicNoticeTemplateBase64');
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
  Future<Uint8List?> loadCountySealBytes() async {
    final prefs = await _prefs();
    final path = prefs.getString('${_prefix}countySealPath');
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('web://')) {
        final b64 = prefs.getString('${_prefix}countySealBase64');
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
