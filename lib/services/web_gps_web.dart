import 'dart:async';
import 'dart:html' as html;

import 'gps_fix.dart';

/// Native browser geolocation with enableHighAccuracy + fresh fixes only.
Future<GpsFix?> readBestWebPosition({
  required Duration sampleFor,
  required double targetAccuracyM,
}) async {
  final geo = html.window.navigator.geolocation;

  GpsFix? best;
  var sampleCount = 0;

  void consider(html.Geoposition pos) {
    final coords = pos.coords;
    if (coords == null) return;
    final lat = coords.latitude;
    final lng = coords.longitude;
    if (lat == null || lng == null) return;

    final accuracy = (coords.accuracy ?? 9999).toDouble();
    final fix = GpsFix(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      accuracyM: accuracy,
    );
    sampleCount++;
    if (best == null || fix.accuracyM < best!.accuracyM) {
      best = fix;
    }
  }

  // Immediate fix.
  try {
    final first = await geo.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 20),
      maximumAge: Duration.zero,
    );
    consider(first);
  } catch (_) {}

  // Stream more samples; keep best accuracy.
  try {
    final stream = geo.watchPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 25),
      maximumAge: Duration.zero,
    );

    await for (final pos in stream.timeout(
      sampleFor,
      onTimeout: (sink) => sink.close(),
    )) {
      consider(pos);
      if (best != null &&
          best!.accuracyM > 0 &&
          best!.accuracyM <= targetAccuracyM &&
          sampleCount >= 3) {
        break;
      }
    }
  } catch (_) {}

  return best;
}
