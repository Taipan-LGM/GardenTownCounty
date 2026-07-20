import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/backup_crypto.dart';

void main() {
  test('BackupCrypto round-trips payload', () {
    final plain = Uint8List.fromList(List<int>.generate(200, (i) => i % 256));
    final encrypted = BackupCrypto.encrypt(plain);
    expect(encrypted, isNot(equals(plain)));
    final decrypted = BackupCrypto.decrypt(encrypted);
    expect(decrypted, plain);
  });

  test('BackupCrypto rejects bad magic', () {
    expect(
      () => BackupCrypto.decrypt(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(isA<Exception>()),
    );
  });
}
