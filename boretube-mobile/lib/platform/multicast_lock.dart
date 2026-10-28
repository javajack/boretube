import 'package:flutter/services.dart';

/// Android WifiManager.MulticastLock via the `boretube/multicast` channel
/// (see MainActivity.kt). No-ops where the channel is missing.
class MulticastLock {
  static const channel = MethodChannel('boretube/multicast');

  const MulticastLock();

  Future<void> acquire() => _call('acquire');

  Future<void> release() => _call('release');

  Future<void> _call(String method) async {
    try {
      await channel.invokeMethod<bool>(method);
    } on MissingPluginException {
      // Not Android (tests, desktop).
    } on PlatformException {
      // Discovery still works on many phones without the lock.
    }
  }
}
