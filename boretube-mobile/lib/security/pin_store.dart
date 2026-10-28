import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../adb/adb_identity.dart';

/// Stores the parent PIN as a salted SHA-256 hash in a [SecretStore]
/// (secure storage on the phone). The PIN itself is never stored.
class PinStore {
  static const storageKey = 'app_pin_v1';
  static const minLength = 4;
  static const maxLength = 6;

  final SecretStore store;
  final Random _random;

  PinStore({
    this.store = const SecureSecretStore(),
    Random? random,
  }) : _random = random ?? Random.secure();

  /// 4–6 digits.
  static bool isValid(String pin) =>
      RegExp('^[0-9]{$minLength,$maxLength}\$').hasMatch(pin);

  static String hash(String pin, List<int> salt) =>
      sha256.convert([...salt, ...utf8.encode(pin)]).toString();

  Future<bool> hasPin() async {
    final v = await store.read(storageKey);
    return v != null && v.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (!isValid(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be 4-6 digits');
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    await store.write(
      storageKey,
      'v1:${base64.encode(salt)}:${hash(pin, salt)}',
    );
  }

  Future<bool> verify(String pin) async {
    final raw = await store.read(storageKey);
    if (raw == null) return false;
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    final List<int> salt;
    try {
      salt = base64.decode(parts[1]);
    } on FormatException {
      return false;
    }
    return _equal(hash(pin, salt), parts[2]);
  }

  Future<void> clear() => store.delete(storageKey);

  /// Constant-time string compare.
  static bool _equal(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
