import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/lro_settings_service.dart';

/// Reads and writes the Admin Land Recovery Office settings.
final lroSettingsServiceProvider = Provider<LroSettingsService>((ref) {
  return LroSettingsService();
});
