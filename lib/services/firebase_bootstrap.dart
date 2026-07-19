import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  static bool ready = false;

  /// Attempts Firebase init. Returns false when placeholders are in use
  /// or initialization fails — app continues in local-only mode.
  static Future<bool> initialize() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'Firebase not configured. Running offline-first (SQLite only). '
        'Run `flutterfire configure` and set DefaultFirebaseOptions.isConfigured = true.',
      );
      ready = false;
      return false;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready = true;
      return true;
    } catch (error, stack) {
      debugPrint('Firebase init failed: $error\n$stack');
      ready = false;
      return false;
    }
  }
}
