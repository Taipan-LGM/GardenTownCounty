import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/providers.dart';
import 'services/database_service.dart';
import 'services/firebase_bootstrap.dart';

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
  }

  final sync = container.read(syncEngineProvider);
  await sync.start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GardenTownCountyApp(),
    ),
  );
}
