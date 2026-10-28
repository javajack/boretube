import 'dart:convert';
import 'dart:typed_data';

import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:boretube_mobile/adb/adb_message.dart';
import 'package:flutter_test/flutter_test.dart';

// A textbook key is too small for PKCS#1 padding of a 35-byte DigestInfo,
// so use two known Mersenne primes (2^521-1, 2^607-1): n is 1128 bits.
final _p = (BigInt.one << 521) - BigInt.one;
final _q = (BigInt.one << 607) - BigInt.one;

AdbKey _testKey() {
  final n = _p * _q;
  final phi = (_p - BigInt.one) * (_q - BigInt.one);
  final e = BigInt.from(65537);
  final d = e.modInverse(phi);
  return AdbKey(n, e, d);
}

void main() {
  group('AdbMessage', () {
    test('encodes header with magic and round-trips', () {
      final m = AdbMessage.text(AdbCommand.open, 7, 0, 'shell:id');
      final bytes = m.encode();
      expect(bytes.length, adbHeaderLength + 'shell:id'.length + 1);
      final (h, len) = AdbMessage.decodeHeader(
          Uint8List.sublistView(bytes, 0, adbHeaderLength));
      expect(h.command, AdbCommand.open);
      expect(h.arg0, 7);
      expect(len, 9);
      expect(utf8.decode(bytes.sublist(adbHeaderLength)), 'shell:id\u0000');
    });

    test('rejects bad magic', () {
      final bytes = AdbMessage(AdbCommand.okay, 1, 2).encode();
      bytes[20] ^= 0xff;
      expect(() => AdbMessage.decodeHeader(bytes.sublist(0, 24)),
          throwsFormatException);
    });
  });

  group('AdbKey', () {
    test('signature verifies with public exponent and PKCS#1 layout', () {
      final key = _testKey();
      final token = Uint8List.fromList(List.generate(20, (i) => i + 1));
      final sig = key.sign(token);
      final k = (key.modulus.bitLength + 7) ~/ 8;
      expect(sig.length, k);
      var s = BigInt.zero;
      for (final b in sig) {
        s = (s << 8) | BigInt.from(b);
      }
      final m = s.modPow(key.publicExponent, key.modulus);
      final em = List<int>.filled(k, 0);
      var x = m;
      for (var i = k - 1; i >= 0; i--) {
        em[i] = (x & BigInt.from(0xff)).toInt();
        x >>= 8;
      }
      expect(em.sublist(0, 2), [0x00, 0x01]);
      expect(em.sublist(k - 20), token);
      expect(em[k - 36], 0x00);
      expect(em[k - 35], 0x30); // DigestInfo starts
    });

    test('android public key struct has the right shape', () {
      final key = _testKey();
      final k = (key.modulus.bitLength + 7) ~/ 8;
      final s = key.androidPublicKeyStruct();
      expect(s.length, 4 + 4 + k + k + 4);
      final bd = ByteData.sublistView(s);
      expect(bd.getUint32(0, Endian.little), k ~/ 4);
      // n0inv * n0 == -1 mod 2^32
      final two32 = BigInt.one << 32;
      final n0 = key.modulus % two32;
      final n0inv = BigInt.from(bd.getUint32(4, Endian.little));
      expect((n0 * n0inv) % two32, two32 - BigInt.one);
      expect(bd.getUint32(8 + 2 * k, Endian.little), 65537);
      expect(key.publicKeyString('me').endsWith(' me'), isTrue);
    });

    test('PKCS#1 PEM round-trips', () {
      final key = _testKey();
      final pem = key.toPkcs1Pem(p: _p, q: _q);
      final back = AdbKey.fromPem(pem);
      expect(back.modulus, key.modulus);
      expect(back.privateExponent, key.privateExponent);
    });
  });
}
