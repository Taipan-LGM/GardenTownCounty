import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/backup_crypto.dart';

void main() {
  test('BackupCrypto GTB2 round-trips with user password', () {
    final plain = Uint8List.fromList(List<int>.generate(200, (i) => i % 256));
    final encrypted = BackupCrypto.encrypt(plain, password: 'securePass1');
    expect(encrypted, isNot(equals(plain)));
    expect(BackupCrypto.requiresPassword(encrypted), isTrue);
    final decrypted = BackupCrypto.decrypt(encrypted, password: 'securePass1');
    expect(decrypted, plain);
  });

  test('BackupCrypto rejects wrong GTB2 password', () {
    final plain = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    final encrypted = BackupCrypto.encrypt(plain, password: 'securePass1');
    expect(
      () => BackupCrypto.decrypt(encrypted, password: 'wrongPass!!'),
      throwsA(isA<Exception>()),
    );
  });

  test('BackupCrypto rejects bad magic', () {
    expect(
      () => BackupCrypto.decrypt(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(isA<Exception>()),
    );
  });

  test('BackupCrypto requires min password length', () {
    final plain = Uint8List.fromList([1, 2, 3]);
    expect(
      () => BackupCrypto.encrypt(plain, password: 'short'),
      throwsA(isA<Exception>()),
    );
  });
}
