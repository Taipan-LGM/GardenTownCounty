import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lro_settings.dart';
import 'lro_settings_io.dart' if (dart.library.html) 'lro_settings_stub.dart';

/// Persists and loads Admin LRO settings using SharedPreferences.
class LroSettingsService {
  static const _prefix = 'lro_';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<LroSettings> load() async {
    final prefs = await _prefs();
    return LroSettings.fromPrefs({
      'countyUniqueNo': prefs.getString('${_prefix}countyUniqueNo') ?? '',
      'facebookPageUrl': prefs.getString('${_prefix}facebookPageUrl') ?? '',
      'numberOrder': prefs.getString('${_prefix}numberOrder') ?? '',
      'blueprintPath': prefs.getString('${_prefix}blueprintPath') ?? '',
      'blueprintBase64': prefs.getString('${_prefix}blueprintBase64') ?? '',
      'samplePath': prefs.getString('${_prefix}samplePath') ?? '',
      'sampleBase64': prefs.getString('${_prefix}sampleBase64') ?? '',
    });
  }

  Future<LroSettings> save(LroSettings settings) async {
    final prefs = await _prefs();
    await prefs.setString('${_prefix}countyUniqueNo', settings.countyUniqueNo);
    await prefs.setString('${_prefix}facebookPageUrl', settings.facebookPageUrl);
    await prefs.setString('${_prefix}numberOrder', settings.numberOrder.name);
    if (settings.blueprintPath != null && settings.blueprintPath!.isNotEmpty) {
      await prefs.setString('${_prefix}blueprintPath', settings.blueprintPath!);
    } else {
      await prefs.remove('${_prefix}blueprintPath');
    }
    if (settings.blueprintBase64 != null && settings.blueprintBase64!.isNotEmpty) {
      await prefs.setString('${_prefix}blueprintBase64', settings.blueprintBase64!);
    } else {
      await prefs.remove('${_prefix}blueprintBase64');
    }
    if (settings.samplePath != null && settings.samplePath!.isNotEmpty) {
      await prefs.setString('${_prefix}samplePath', settings.samplePath!);
    } else {
      await prefs.remove('${_prefix}samplePath');
    }
    if (settings.sampleBase64 != null && settings.sampleBase64!.isNotEmpty) {
      await prefs.setString('${_prefix}sampleBase64', settings.sampleBase64!);
    } else {
      await prefs.remove('${_prefix}sampleBase64');
    }
    return settings;
  }

  /// Returns the stored blueprint image bytes, or null if none uploaded.
  Future<Uint8List?> loadBlueprintBytes() async {
    final prefs = await _prefs();
    final base64 = prefs.getString('${_prefix}blueprintBase64');
    if (base64 != null && base64.isNotEmpty && base64.startsWith('data:')) {
      final uri = Uri.parse(base64);
      return uri.data?.contentAsBytes();
    }
    final path = prefs.getString('${_prefix}blueprintPath');
    if (path != null && path.isNotEmpty && path.startsWith('file://')) {
      return readFileBytes(Uri.parse(path).path);
    }
    return null;
  }

  /// Returns the stored sample image bytes, or null if none uploaded.
  Future<Uint8List?> loadSampleBytes() async {
    final prefs = await _prefs();
    final base64 = prefs.getString('${_prefix}sampleBase64');
    if (base64 != null && base64.isNotEmpty && base64.startsWith('data:')) {
      final uri = Uri.parse(base64);
      return uri.data?.contentAsBytes();
    }
    final path = prefs.getString('${_prefix}samplePath');
    if (path != null && path.isNotEmpty && path.startsWith('file://')) {
      return readFileBytes(Uri.parse(path).path);
    }
    return null;
  }

  /// Saves uploaded blueprint image bytes (web base64 or desktop path).
  Future<void> saveBlueprintBytes(Uint8List bytes) async {
    final prefs = await _prefs();
    if (kIsWeb) {
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Blueprint image too large (max 5 MB).');
      }
      final encoded = Uri.dataFromBytes(bytes, mimeType: 'image/jpeg').toString();
      await prefs.setString('${_prefix}blueprintBase64', encoded);
      await prefs.setString('${_prefix}blueprintPath', 'web://blueprint');
    } else {
      // Desktop: save to app documents and store the file path.
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'lro_blueprint_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';
      await writeFileBytes(filePath, bytes);
      await prefs.setString('${_prefix}blueprintPath', filePath);
      await prefs.remove('${_prefix}blueprintBase64');
    }
  }

  /// Saves uploaded sample image bytes.
  Future<void> saveSampleBytes(Uint8List bytes) async {
    final prefs = await _prefs();
    if (kIsWeb) {
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Sample image too large (max 5 MB).');
      }
      final encoded = Uri.dataFromBytes(bytes, mimeType: 'image/jpeg').toString();
      await prefs.setString('${_prefix}sampleBase64', encoded);
      await prefs.setString('${_prefix}samplePath', 'web://sample');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'lro_sample_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';
      await writeFileBytes(filePath, bytes);
      await prefs.setString('${_prefix}samplePath', filePath);
      await prefs.remove('${_prefix}sampleBase64');
    }
  }

  /// Removes both blueprint and sample images.
  Future<void> clearImages() async {
    final prefs = await _prefs();
    await prefs.remove('${_prefix}blueprintPath');
    await prefs.remove('${_prefix}blueprintBase64');
    await prefs.remove('${_prefix}samplePath');
    await prefs.remove('${_prefix}sampleBase64');
  }
}