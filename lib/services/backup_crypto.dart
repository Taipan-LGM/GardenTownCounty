import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../core/constants/app_constants.dart';

/// AES-CBC encryption for .gtb backup payloads.
class BackupCrypto {
  static Uint8List _keyBytes() {
    final digest = sha256.convert(
      utf8.encode(AppConstants.backupMasterPassword),
    );
    return Uint8List.fromList(digest.bytes);
  }

  static Uint8List encrypt(Uint8List plain) {
    final key = _keyBytes();
    final iv = _randomBytes(16);
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
    // Format: GTB1 | iv(16) | ciphertext
    final out = BytesBuilder();
    out.add(utf8.encode('GTB1'));
    out.add(iv);
    out.add(encrypted);
    return out.toBytes();
  }

  static Uint8List decrypt(Uint8List payload) {
    if (payload.length < 4 + 16 + 1) {
      throw Exception('Invalid backup file.');
    }
    final magic = utf8.decode(payload.sublist(0, 4));
    if (magic != 'GTB1') {
      throw Exception('Not a Garden Town Backup (.gtb) file.');
    }
    final iv = payload.sublist(4, 20);
    final cipherBytes = payload.sublist(20);
    final key = _keyBytes();
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

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }
}
