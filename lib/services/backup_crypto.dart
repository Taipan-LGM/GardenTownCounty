import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../core/constants/app_constants.dart';

/// AES-CBC encryption for .gtb backup payloads.
///
/// - **GTB2** (preferred): user password → PBKDF2 key + random salt/IV
/// - **GTB1** (legacy): static app master password (decrypt only for restore)
class BackupCrypto {
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  /// Encrypt with a user-chosen [password] (GTB2).
  static Uint8List encrypt(Uint8List plain, {required String password}) {
    if (password.trim().length < 8) {
      throw Exception('Backup password must be at least 8 characters.');
    }
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(16);
    final key = _deriveKey(password, salt);
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
    final encrypted = cipher.process(plain);
    // Format: GTB2 | salt(16) | iv(16) | ciphertext
    final out = BytesBuilder();
    out.add(utf8.encode('GTB2'));
    out.add(salt);
    out.add(iv);
    out.add(encrypted);
    return out.toBytes();
  }

  /// Decrypt GTB2 with [password], or legacy GTB1 with the built-in master key.
  static Uint8List decrypt(Uint8List payload, {String? password}) {
    if (payload.length < 4 + 16 + 1) {
      throw Exception('Invalid backup file.');
    }
    final magic = utf8.decode(payload.sublist(0, 4));
    if (magic == 'GTB2') {
      if (password == null || password.isEmpty) {
        throw Exception('This backup requires a password.');
      }
      if (payload.length < 4 + _saltLength + 16 + 1) {
        throw Exception('Invalid backup file.');
      }
      final salt = payload.sublist(4, 4 + _saltLength);
      final iv = payload.sublist(4 + _saltLength, 4 + _saltLength + 16);
      final cipherBytes = payload.sublist(4 + _saltLength + 16);
      final key = _deriveKey(password, salt);
      return _aesDecrypt(key, iv, cipherBytes);
    }
    if (magic == 'GTB1') {
      // Legacy backups encrypted with the app master password.
      final iv = payload.sublist(4, 20);
      final cipherBytes = payload.sublist(20);
      final key = _legacyMasterKey();
      return _aesDecrypt(key, iv, cipherBytes);
    }
    throw Exception('Not a Garden Town Backup (.gtb) file.');
  }

  /// Whether [payload] is a GTB2 (password-protected) backup.
  static bool requiresPassword(Uint8List payload) {
    if (payload.length < 4) return false;
    return utf8.decode(payload.sublist(0, 4)) == 'GTB2';
  }

  static Uint8List _aesDecrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List cipherBytes,
  ) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
    return cipher.process(cipherBytes);
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _legacyMasterKey() {
    final digest = sha256.convert(
      utf8.encode(AppConstants.backupMasterPassword),
    );
    return Uint8List.fromList(digest.bytes);
  }

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }
}
