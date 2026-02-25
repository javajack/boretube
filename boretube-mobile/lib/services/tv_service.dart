import 'package:flutter/foundation.dart';

import '../models/tv_status.dart';
import '../protocols/castv2_client.dart';
import '../protocols/dial_client.dart';

/// High-level TV operations combining CastV2 + DIAL protocols.
///
/// Every public method is safe to call when the TV is off
/// or unreachable — they catch all errors internally and
/// return null / false as appropriate.
class TvService {
  final String host;
  final int castPort;
  final int dialPort;
  final DialClient _dialClient;
  final CastV2Client Function() _castFactory;

  TvService({
    required this.host,
    this.castPort = 8009,
    this.dialPort = 8008,
    @visibleForTesting DialClient? dialClient,
    @visibleForTesting
    CastV2Client Function()? castFactory,
  })  : _dialClient = dialClient ??
            DialClient(host: host, port: dialPort),
        _castFactory = castFactory ??
            (() =>
                CastV2Client(host: host, port: castPort));

  /// Get current TV status. Returns null if unreachable.
  ///
  /// Fetches CastV2 status (app info) and Sony Bravia
  /// hardware volume in parallel. Hardware volume
  /// overrides CastV2 volume (always 0 on BRAVIA).
  /// Each call is independently error-tolerant so a
  /// timeout on one doesn't kill the other.
  Future<TvStatus?> getStatus() async {
    final client = _castFactory();
    try {
      // Launch both in parallel
      final castFuture = client.getStatus();
      final hwVolFuture = _safeGetHardwareVolume();

      final json = await castFuture;
      if (json == null) return null;

      final hwVol = await hwVolFuture;
      final status = TvStatus.fromJson(json);

      if (hwVol != null) {
        return TvStatus(
          volume: hwVol.volume,
          muted: hwVol.muted,
          appId: status.appId,
          appName: status.appName,
          isIdle: status.isIdle,
        );
      }
      return status;
    } catch (e) {
      debugPrint('[TvService] getStatus error: $e');
      return null;
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// Wrapper that never throws.
  Future<({int volume, bool muted})?> _safeGetHardwareVolume() async {
    try {
      return await _dialClient.getHardwareVolume();
    } catch (e) {
      debugPrint(
        '[TvService] hardware volume unavailable: $e',
      );
      return null;
    }
  }

  /// Kill current app + mute TV.
  Future<void> bore() async {
    final client = _castFactory();
    try {
      await client.bore();
    } catch (e) {
      debugPrint('[TvService] bore CastV2 error: $e');
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
    try {
      await _dialClient.killApps();
    } catch (_) {}
  }

  /// Unmute TV.
  Future<void> restore() async {
    final client = _castFactory();
    try {
      await client.unmute();
    } catch (e) {
      debugPrint('[TvService] restore error: $e');
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// Set volume (0-100) via Sony Bravia REST API.
  /// Falls back to CastV2 if hardware API fails.
  Future<bool> setVolume(int percent) async {
    try {
      final ok =
          await _dialClient.setHardwareVolume(percent);
      if (ok) return true;
    } catch (e) {
      debugPrint(
        '[TvService] setHardwareVolume error: $e',
      );
    }

    // Fallback to CastV2
    final client = _castFactory();
    try {
      await client.setVolume(percent);
      return true;
    } catch (e) {
      debugPrint(
        '[TvService] setVolume CastV2 error: $e',
      );
      return false;
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// Mute TV.
  Future<bool> mute() async {
    final client = _castFactory();
    try {
      await client.mute();
      return true;
    } catch (e) {
      debugPrint('[TvService] mute error: $e');
      return false;
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// Unmute TV.
  Future<bool> unmute() async {
    final client = _castFactory();
    try {
      await client.unmute();
      return true;
    } catch (e) {
      debugPrint('[TvService] unmute error: $e');
      return false;
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  /// Stop current app without muting.
  Future<void> killApp() async {
    final client = _castFactory();
    try {
      await client.stop();
    } catch (_) {
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
    }
    try {
      await _dialClient.killApps();
    } catch (_) {}
  }

  /// Check if TV is reachable via DIAL.
  Future<bool> isReachable() async {
    try {
      return await _dialClient.isReachable();
    } catch (_) {
      return false;
    }
  }

  /// Get device name via DIAL.
  Future<String?> getDeviceName() async {
    try {
      return await _dialClient.getDeviceName();
    } catch (_) {
      return null;
    }
  }
}
