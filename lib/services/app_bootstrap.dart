import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';

class AppBootstrap {
  static Future<void> initialize(ProviderContainer container) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await FirebaseBootstrap.initialize();
    } catch (error, stack) {
      debugPrint('Bootstrap: Firebase initialization failed: $error\n$stack');
    }

    try {
      await DatabaseService.instance.init();
    } catch (error, stack) {
      debugPrint('Bootstrap: database initialization failed: $error\n$stack');
    }

    try {
      final auth = container.read(authServiceProvider);
      await auth.restoreSession();
      if (auth.currentUser != null) {
        container.read(authUserProvider.notifier).state = auth.currentUser;
      }
    } catch (error, stack) {
      debugPrint('Bootstrap: auth restoration failed: $error\n$stack');
      await container.read(authServiceProvider).signOut();
    }

    try {
      final prefs = container.read(appPreferencesServiceProvider);
      container.read(themeModeProvider.notifier).state =
          await prefs.loadThemeMode();
      container.read(appLanguageProvider.notifier).state =
          await prefs.loadLanguage();
    } catch (error, stack) {
      debugPrint('Bootstrap: preferences load failed: $error\n$stack');
    }

    try {
      await container.read(syncEngineProvider).start();
    } catch (error, stack) {
      debugPrint('Bootstrap: sync engine start failed: $error\n$stack');
    }

    try {
      await container.read(connectivityServiceProvider).start();
    } catch (error, stack) {
      debugPrint('Bootstrap: connectivity start failed: $error\n$stack');
    }

    try {
      container.read(autoBackupSchedulerProvider).start();
    } catch (error, stack) {
      debugPrint('Bootstrap: auto-backup start failed: $error\n$stack');
    }

    try {
      container.read(tempAccessExpiryServiceProvider).start();
    } catch (error, stack) {
      debugPrint('Bootstrap: temp access expiry start failed: $error\n$stack');
    }

    if (kIsWeb) {
      debugPrint('Running web preview with in-memory database.');
    }
  }
}
