import 'dart:typed_data';

import 'package:boretube_mobile/adb/adb_identity.dart';
import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates RSA-2048, e=65537, PKCS#1 PEM that round-trips', () {
    final pem = AdbIdentity.generatePem();
    expect(pem, startsWith('-----BEGIN RSA PRIVATE KEY-----'));
    final key = AdbKey.fromPem(pem);
    expect(key.modulus.bitLength, 2048);
    expect(key.publicExponent, BigInt.from(65537));
    final sig = key.sign(Uint8List(20));
    expect(sig.length, 256);
    // Signature verifies with the public key.
    final m = sig.fold<BigInt>(
      BigInt.zero,
      (a, b) => (a << 8) | BigInt.from(b),
    );
    final em = m.modPow(key.publicExponent, key.modulus);
    expect(em.bitLength, inInclusiveRange(2033, 2041));
    expect(
      key.publicKeyString(AdbIdentity.keyName),
      endsWith(' boretube@phone'),
    );
  });

  test('load generates once, persists, and reuses the key', () async {
    final store = MemorySecretStore();
    final a = await AdbIdentity(store: store, bits: 1024).load();
    expect(store.values[AdbIdentity.storageKey], contains('RSA PRIVATE'));
    final b = await AdbIdentity(store: store, bits: 1024).load();
    expect(b.modulus, a.modulus);
    expect(b.privateExponent, a.privateExponent);
  });

  test('reset forgets the key', () async {
    final store = MemorySecretStore();
    final id = AdbIdentity(store: store, bits: 1024);
    final a = await id.load();
    await id.reset();
    expect(await id.exists(), isFalse);
    final b = await id.load();
    expect(b.modulus, isNot(a.modulus));
  });
}
