import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

import 'adb_key.dart';

/// Tiny key/value store for secrets, so tests can swap in memory storage.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [SecretStore] backed by the platform keystore.
class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;

  const SecureSecretStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// [SecretStore] that lives in memory (tests, previews).
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The phone's ADB identity: one RSA key, generated on first use and kept
/// in secure storage as a PKCS#1 PEM.
class AdbIdentity {
  static const storageKey = 'adb_private_key';
  static const keyName = 'boretube@phone';

  final SecretStore store;
  final int bits;

  AdbKey? _cached;

  AdbIdentity({
    this.store = const SecureSecretStore(),
    this.bits = 2048,
  });

  /// Whether a key has already been stored.
  Future<bool> exists() async => (await store.read(storageKey)) != null;

  /// Returns the stored key, generating and persisting one if needed.
  Future<AdbKey> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final pem = await store.read(storageKey);
    if (pem != null && pem.isNotEmpty) {
      return _cached = AdbKey.fromPem(pem);
    }
    final b = bits;
    final newPem = await Isolate.run(() => generatePem(bits: b));
    await store.write(storageKey, newPem);
    return _cached = AdbKey.fromPem(newPem);
  }

  /// Forgets the key. The TV will ask "Allow USB debugging?" again.
  Future<void> reset() async {
    _cached = null;
    await store.delete(storageKey);
  }

  /// Generates an RSA key (e = 65537) and returns it as a PKCS#1 PEM.
  static String generatePem({int bits = 2048}) {
    final rnd = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );
    final random = FortunaRandom()..seed(KeyParameter(seed));
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    final priv = pair.privateKey;
    final pub = pair.publicKey;
    final key = AdbKey(
      priv.modulus!,
      pub.publicExponent!,
      priv.privateExponent!,
    );
    return key.toPkcs1Pem(p: priv.p!, q: priv.q!);
  }
}
