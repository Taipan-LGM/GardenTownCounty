import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/providers.dart';
import 'services/database_service.dart';
import 'services/firebase_bootstrap.dart';
import 'widgets/menu_guide_arrow.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseBootstrap.initialize();

  // SQLite on desktop/mobile; in-memory store on web preview.
  await DatabaseService.instance.init();
  if (kIsWeb) {
    debugPrint('Running web preview with in-memory database.');
  }

  final container = ProviderContainer();
  final auth = container.read(authServiceProvider);
  await auth.restoreSession();
  if (auth.currentUser != null) {
    container.read(authUserProvider.notifier).state = auth.currentUser;
    // Session restore skips LoginScreen — still arm MENU guide once.
    await registerMenuGuideLoginAttempt();
  }

  final prefs = container.read(appPreferencesServiceProvider);
  container.read(themeModeProvider.notifier).state =
      await prefs.loadThemeMode();
  container.read(appLanguageProvider.notifier).state =
      await prefs.loadLanguage();

  final sync = container.read(syncEngineProvider);
  await sync.start();

  final connectivity = container.read(connectivityServiceProvider);
  await connectivity.start();

  final autoBackup = container.read(autoBackupSchedulerProvider);
  autoBackup.start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GardenTownCountyApp(),
    ),
  );
}
