import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Password hashing with PBKDF2-HMAC-SHA256 (salted).
///
/// Stored format: `pbkdf2$<iterations>$<saltB64>$<hashB64>`
/// Legacy SHA-256 hex (64 chars) is still accepted for migration.
class PasswordHasher {
  static const int iterations = 100000;
  static const int saltLength = 16;
  static const int keyLength = 32;
  static const String _prefix = 'pbkdf2';

  static String hash(String password) {
    final salt = _randomBytes(saltLength);
    final derived = _pbkdf2(password, salt, iterations);
    return '$_prefix\$$iterations\$${base64Encode(salt)}\$${base64Encode(derived)}';
  }

  /// Returns true when [stored] matches [password].
  static bool verify(String password, String stored) {
    if (stored.isEmpty) return false;
    if (stored.startsWith('$_prefix\$')) {
      return _verifyPbkdf2(password, stored);
    }
    // Legacy unsalted SHA-256 hex.
    return _legacySha256(password) == stored;
  }

  /// True when [stored] uses the legacy SHA-256 format and should be upgraded.
  static bool needsRehash(String stored) =>
      stored.isNotEmpty && !stored.startsWith('$_prefix\$');

  static bool _verifyPbkdf2(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != _prefix) return false;
    final iters = int.tryParse(parts[1]) ?? 0;
    if (iters < 1000) return false;
    Uint8List salt;
    Uint8List expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } catch (_) {
      return false;
    }
    final actual = _pbkdf2(password, salt, iters);
    return _constantTimeEquals(actual, expected);
  }

  static Uint8List _pbkdf2(String password, Uint8List salt, int iters) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iters, keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static String _legacySha256(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }
}
