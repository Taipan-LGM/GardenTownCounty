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
          final position = await _readAccuratePosition();
          if (position != null) {
            lat = position.latitude;
            lng = position.longitude;
            final accuracyM = position.accuracy;
            label =
                '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)} (±${accuracyM.toStringAsFixed(0)}m)';
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

  /// Prefer a fresh high-accuracy fix; fall back to last known.
  Future<Position?> _readAccuratePosition() async {
    final settings = _platformSettings();

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  LocationSettings _platformSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 20),
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 20),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.other,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          timeLimit: const Duration(seconds: 20),
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
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
