import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'sync_engine.dart';

/// Listens for network changes and triggers sync on reconnect.
class ConnectivityService {
  ConnectivityService(this._sync);

  final SyncEngine _sync;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  Future<void> start() async {
    final initial = await Connectivity().checkConnectivity();
    _wasOffline = _isOffline(initial);
    if (_wasOffline) {
      _sync.setOffline();
    } else {
      _sync.setOnlineAndSync();
    }

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = _isOffline(results);
      if (offline) {
        _wasOffline = true;
        _sync.setOffline();
        debugPrint('Connectivity: offline');
      } else if (_wasOffline) {
        _wasOffline = false;
        debugPrint('Connectivity: reconnected — syncing');
        _sync.setOnlineAndSync();
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  bool _isOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.every((r) => r == ConnectivityResult.none);
  }
}
