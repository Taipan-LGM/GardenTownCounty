import 'dart:async';

import 'temporary_access_service.dart';

/// Periodic auto-expiry for temporary access codes (every minute while app runs).
///
/// Desktop/web cannot rely on OS schedulers reliably; this in-process timer is
/// the primary expiry mechanism while the app is open.
class TempAccessExpiryService {
  TempAccessExpiryService(this._tempAccess);

  final TemporaryAccessService _tempAccess;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        await _tempAccess.autoExpireTemporaryAccess();
      } catch (_) {
        // Best-effort; next tick will retry.
      }
    });
    // Run once shortly after start.
    Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        await _tempAccess.autoExpireTemporaryAccess();
      } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
