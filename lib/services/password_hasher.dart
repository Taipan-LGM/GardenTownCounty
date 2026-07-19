import 'dart:convert';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  static String hash(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static bool verify(String password, String hash) {
    return PasswordHasher.hash(password) == hash;
  }
}
