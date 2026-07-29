import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/password_hasher.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  test('PasswordHasher PBKDF2 round-trip', () {
    final hash = PasswordHasher.hash('garden2026');
    expect(hash.startsWith('pbkdf2\$'), isTrue);
    expect(PasswordHasher.verify('garden2026', hash), isTrue);
    expect(PasswordHasher.verify('wrong', hash), isFalse);
    expect(PasswordHasher.needsRehash(hash), isFalse);
  });

  test('PasswordHasher verifies legacy SHA-256 and flags rehash', () {
    final legacy = sha256.convert(utf8.encode('garden2026')).toString();
    expect(PasswordHasher.verify('garden2026', legacy), isTrue);
    expect(PasswordHasher.needsRehash(legacy), isTrue);
  });
}
