import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/activity_log.dart';
import 'database_service.dart';
import 'gps_accuracy.dart';
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
          final position = await readBestGpsPosition();
          if (position != null) {
            lat = position.latitude;
            lng = position.longitude;
            final accuracyM = position.accuracyM;
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

  Future<bool> _ensurePermission() async {
    if (!kIsWeb) {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
    }

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
