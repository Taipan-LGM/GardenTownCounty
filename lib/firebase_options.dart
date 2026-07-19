// File generated for Garden Town County.
// Replace values via `flutterfire configure` before enabling cloud sync.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Set [isConfigured] to true after replacing placeholder values.
class DefaultFirebaseOptions {
  /// Flip to true after running `flutterfire configure` with a real project.
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:replace',
    messagingSenderId: '000000000000',
    projectId: 'garden-town-county',
    authDomain: 'garden-town-county.firebaseapp.com',
    storageBucket: 'garden-town-county.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:android:replace',
    messagingSenderId: '000000000000',
    projectId: 'garden-town-county',
    storageBucket: 'garden-town-county.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:replace',
    messagingSenderId: '000000000000',
    projectId: 'garden-town-county',
    storageBucket: 'garden-town-county.appspot.com',
    iosBundleId: 'za.co.gardentowncounty.gardenTownCounty',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:macos:replace',
    messagingSenderId: '000000000000',
    projectId: 'garden-town-county',
    storageBucket: 'garden-town-county.appspot.com',
    iosBundleId: 'za.co.gardentowncounty.gardenTownCounty',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:replace',
    messagingSenderId: '000000000000',
    projectId: 'garden-town-county',
    authDomain: 'garden-town-county.firebaseapp.com',
    storageBucket: 'garden-town-county.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:replace',
    messagingSenderId: '000000000000',
    projectId: 'garden-town-county',
    authDomain: 'garden-town-county.firebaseapp.com',
    storageBucket: 'garden-town-county.appspot.com',
  );
}
