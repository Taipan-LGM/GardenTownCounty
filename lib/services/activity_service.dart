import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/activity_log.dart';
import 'database_service.dart';
import 'sync_engine.dart';

class ActivityService {
  ActivityService(this._db, this._sync);

  final DatabaseService _db;
  final SyncEngine _sync;

  Future<List<ActivityLog>> list() => _db.getActivities();

  Future<ActivityLog> record({
    required String userName,
    required String action,
    bool captureGps = true,
  }) async {
    double? lat;
    double? lng;
    String? label;

    if (captureGps) {
      try {
        final permission = await _ensurePermission();
        if (permission) {
          final position = await _readBestPosition();
          if (position != null) {
            lat = position.latitude;
            lng = position.longitude;
            final accuracyM = position.accuracy;
            label =
                '${lat.toStringAsFixed(7)}, ${lng.toStringAsFixed(7)} (±${accuracyM.toStringAsFixed(1)}m)';
          } else {
            label = 'GPS unavailable';
          }
        } else {
          label = 'GPS permission denied';
        }
      } catch (_) {
        label = 'GPS unavailable';
      }
    }

    final activity = ActivityLog.create(
      userName: userName,
      action: action,
      latitude: lat,
      longitude: lng,
      locationLabel: label,
    );
    await _db.insertActivity(activity);
    await _sync.pushPending();
    return activity;
  }

  /// Sample the GPS stream and keep the reading with the best (lowest) accuracy.
  Future<Position?> _readBestPosition() async {
    final settings = _platformSettings(timeLimit: const Duration(seconds: 25));

    Position? best;

    // 1) Quick first fix.
    try {
      best = await Geolocator.getCurrentPosition(locationSettings: settings);
    } catch (_) {}

    // 2) Sample stream for up to ~12s; keep improving accuracy.
    try {
      final stream = Geolocator.getPositionStream(
        locationSettings: _platformSettings(
          timeLimit: null,
          distanceFilter: 0,
        ),
      );

      await for (final pos in stream.timeout(
        const Duration(seconds: 12),
        onTimeout: (sink) => sink.close(),
      )) {
        if (best == null || pos.accuracy < best.accuracy) {
          best = pos;
        }
        // Good enough for county desk map pinning.
        if (best.accuracy > 0 && best.accuracy <= 12) break;
      }
    } catch (_) {}

    // 3) Last-known fallback.
    if (best == null) {
      try {
        best = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    return best;
  }

  LocationSettings _platformSettings({
    Duration? timeLimit = const Duration(seconds: 25),
    int distanceFilter = 0,
  }) {
    if (kIsWeb) {
      return LocationSettings(
        // Web maps this to navigator.geolocation enableHighAccuracy=true.
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 1),
          timeLimit: timeLimit,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.otherNavigation,
          distanceFilter: distanceFilter,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: false,
          showBackgroundLocationIndicator: false,
          timeLimit: timeLimit,
        );
      default:
        return LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter,
          timeLimit: timeLimit,
        );
    }
  }

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }
}
