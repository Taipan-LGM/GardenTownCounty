import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrint(stack.toString());
    return true;
  };

  final container = ProviderContainer();
  await AppBootstrap.initialize(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GardenTownCountyApp(),
    ),
  );
}

Widget buildApp() => const ProviderScope(child: GardenTownCountyApp());
