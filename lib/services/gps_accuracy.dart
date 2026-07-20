import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_fix.dart';
import 'web_gps_stub.dart'
    if (dart.library.html) 'web_gps_web.dart' as web_gps;

/// Best-effort high-accuracy fix for Activities.
Future<GpsFix?> readBestGpsPosition() async {
  if (kIsWeb) {
    final web = await web_gps.readBestWebPosition(
      sampleFor: const Duration(seconds: 30),
      targetAccuracyM: 10,
    );
    if (web != null) return web;
  }

  return _readBestViaGeolocator();
}

Future<GpsFix?> _readBestViaGeolocator() async {
  Position? best;

  final settings = const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 30),
  );

  try {
    best = await Geolocator.getCurrentPosition(locationSettings: settings);
  } catch (_) {}

  try {
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    await for (final pos in stream) {
      if (best == null || pos.accuracy + 0.5 < best.accuracy) {
        best = pos;
      } else if ((pos.accuracy - best.accuracy).abs() <= 0.5 &&
          pos.timestamp.isAfter(best.timestamp)) {
        best = pos;
      }
      if (best.accuracy > 0 && best.accuracy <= 8) break;
      if (DateTime.now().isAfter(deadline)) break;
    }
  } catch (_) {}

  if (best == null) {
    try {
      best = await Geolocator.getLastKnownPosition();
    } catch (_) {}
  }

  if (best == null) return null;
  return GpsFix(
    latitude: best.latitude,
    longitude: best.longitude,
    accuracyM: best.accuracy,
  );
}
