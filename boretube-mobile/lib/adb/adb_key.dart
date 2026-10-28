import 'dart:convert';
import 'dart:typed_data';

/// An RSA key pair in the shape adbd expects: PKCS#1 v1.5 signatures over
/// the 20-byte AUTH token, and Android's custom public key struct.
class AdbKey {
  final BigInt modulus;
  final BigInt publicExponent;
  final BigInt privateExponent;

  AdbKey(this.modulus, this.publicExponent, this.privateExponent);

  int get _modulusBytes => (modulus.bitLength + 7) ~/ 8;

  /// DER prefix of a SHA-1 DigestInfo. adbd verifies the token as if it
  /// were a SHA-1 digest (RSA_verify with NID_sha1).
  static final List<int> _sha1DigestInfo = [
    0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, //
    0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14,
  ];

  /// Signs an AUTH token (expected to be 20 bytes).
  Uint8List sign(Uint8List token) {
    final k = _modulusBytes;
    final t = [..._sha1DigestInfo, ...token];
    if (t.length + 11 > k) {
      throw ArgumentError('Token too long for key size');
    }
    final em = Uint8List(k);
    em[0] = 0x00;
    em[1] = 0x01;
    for (var i = 2; i < k - t.length - 1; i++) {
      em[i] = 0xff;
    }
    em[k - t.length - 1] = 0x00;
    em.setRange(k - t.length, k, t);
    final s = _bytesToBigInt(em).modPow(privateExponent, modulus);
    return _bigIntToBytes(s, k);
  }

  /// `base64(android_pubkey_struct) + " " + name`, as sent in AUTH type 3
  /// and stored in the TV's adb_keys.
  String publicKeyString(String name) =>
      '${base64.encode(androidPublicKeyStruct())} $name';

  /// struct { u32 len_words; u32 n0inv; u8 n[k] LE; u8 rr[k] LE; u32 e; }
  Uint8List androidPublicKeyStruct() {
    final k = _modulusBytes;
    final words = k ~/ 4;
    final out = Uint8List(4 + 4 + k + k + 4);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, words, Endian.little);

    final two32 = BigInt.one << 32;
    final n0 = modulus % two32;
    final n0inv = (two32 - n0.modInverse(two32)) % two32;
    bd.setUint32(4, n0inv.toInt(), Endian.little);

    out.setRange(8, 8 + k, _bigIntToBytes(modulus, k).reversed);
    final rr = (BigInt.one << (k * 8 * 2)) % modulus;
    out.setRange(8 + k, 8 + 2 * k, _bigIntToBytes(rr, k).reversed);
    bd.setUint32(8 + 2 * k, publicExponent.toInt(), Endian.little);
    return out;
  }

  /// Parses an unencrypted PKCS#8 ("BEGIN PRIVATE KEY") or PKCS#1
  /// ("BEGIN RSA PRIVATE KEY") PEM, like the laptop's ~/.android/adbkey.
  factory AdbKey.fromPem(String pem) {
    final body = pem
        .split('\n')
        .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
        .join();
    var der = _Der(base64.decode(body));
    var seq = der.sequence();
    // PKCS#8 wraps the PKCS#1 key: version, algorithm, octet string.
    if (pem.contains('BEGIN PRIVATE KEY')) {
      seq.integer();
      seq.skip();
      der = _Der(seq.octetString());
      seq = der.sequence();
    }
    seq.integer(); // version
    final n = seq.integer();
    final e = seq.integer();
    final d = seq.integer();
    return AdbKey(n, e, d);
  }

  /// PKCS#1 PEM, the format we persist on the phone.
  String toPkcs1Pem({required BigInt p, required BigInt q}) {
    final dp = privateExponent % (p - BigInt.one);
    final dq = privateExponent % (q - BigInt.one);
    final qinv = q.modInverse(p);
    final der = _derSequence([
      _derInteger(BigInt.zero),
      _derInteger(modulus),
      _derInteger(publicExponent),
      _derInteger(privateExponent),
      _derInteger(p),
      _derInteger(q),
      _derInteger(dp),
      _derInteger(dq),
      _derInteger(qinv),
    ]);
    final b64 = base64.encode(der);
    final lines = [
      for (var i = 0; i < b64.length; i += 64)
        b64.substring(i, i + 64 > b64.length ? b64.length : i + 64),
    ];
    return '-----BEGIN RSA PRIVATE KEY-----\n${lines.join('\n')}\n'
        '-----END RSA PRIVATE KEY-----\n';
  }
}

BigInt _bytesToBigInt(List<int> bytes) {
  var r = BigInt.zero;
  for (final b in bytes) {
    r = (r << 8) | BigInt.from(b);
  }
  return r;
}

Uint8List _bigIntToBytes(BigInt v, int length) {
  final out = Uint8List(length);
  var x = v;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  return out;
}

List<int> _derLength(int len) {
  if (len < 0x80) return [len];
  final bytes = <int>[];
  var l = len;
  while (l > 0) {
    bytes.insert(0, l & 0xff);
    l >>= 8;
  }
  return [0x80 | bytes.length, ...bytes];
}

List<int> _derInteger(BigInt v) {
  var bytes = v == BigInt.zero
      ? [0]
      : _bigIntToBytes(v, (v.bitLength + 7) ~/ 8).toList();
  if (bytes.first & 0x80 != 0) bytes = [0, ...bytes];
  return [0x02, ..._derLength(bytes.length), ...bytes];
}

List<int> _derSequence(List<List<int>> items) {
  final body = items.expand((e) => e).toList();
  return [0x30, ..._derLength(body.length), ...body];
}

/// Minimal DER reader: just enough for RSA private keys.
class _Der {
  final Uint8List _b;
  int _i = 0;
  _Der(List<int> bytes) : _b = Uint8List.fromList(bytes);

  (int, Uint8List) _tlv() {
    final tag = _b[_i++];
    var len = _b[_i++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      len = 0;
      for (var k = 0; k < n; k++) {
        len = (len << 8) | _b[_i++];
      }
    }
    final value = Uint8List.sublistView(_b, _i, _i + len);
    _i += len;
    return (tag, value);
  }

  _Der sequence() {
    final (tag, v) = _tlv();
    if (tag != 0x30) throw const FormatException('Expected DER SEQUENCE');
    return _Der(v);
  }

  BigInt integer() {
    final (tag, v) = _tlv();
    if (tag != 0x02) throw const FormatException('Expected DER INTEGER');
    return _bytesToBigInt(v);
  }

  Uint8List octetString() {
    final (tag, v) = _tlv();
    if (tag != 0x04) throw const FormatException('Expected OCTET STRING');
    return v;
  }

  void skip() => _tlv();
}
