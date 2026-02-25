import 'package:flutter/foundation.dart';

import '../models/tv_status.dart';
import '../protocols/castv2_client.dart';
import '../protocols/dial_client.dart';

/// High-level TV operations combining CastV2 + DIAL protocols.
/// Matches the bash boretube.sh action functions.
///
/// Each operation opens a fresh CastV2 connection (matching
/// the bash pattern where each cast_command() spawns a new
/// python process with its own TLS connection).
class TvService {
  final String host;
  final int castPort;
  final int dialPort;
  final DialClient _dialClient;

  TvService({
    required this.host,
    this.castPort = 8009,
    this.dialPort = 8008,
  }) : _dialClient = DialClient(host: host, port: dialPort);

  /// Create a fresh CastV2 client for one-shot use.
  CastV2Client _newCastClient() =>
      CastV2Client(host: host, port: castPort);

  /// Get current TV status. Returns null if unreachable.
  Future<TvStatus?> getStatus() async {
    final client = _newCastClient();
    try {
      final json = await client.getStatus();
      if (json == null) return null;
      return TvStatus.fromJson(json);
    } catch (e) {
      debugPrint('[TvService] getStatus error: $e');
      return null;
    } finally {
      await client.disconnect();
    }
  }

  /// Kill current app + mute TV. Matches bash do_bore():
  /// CastV2 STOP + MUTE + DIAL kill YouTube/Netflix.
  Future<void> bore() async {
    final client = _newCastClient();
    try {
      await client.bore();
    } catch (e) {
      debugPrint('[TvService] bore CastV2 error: $e');
    } finally {
      await client.disconnect();
    }
    try {
      await _dialClient.killApps();
    } catch (_) {
      // DIAL kill failed
    }
  }

  /// Unmute TV. Matches bash do_restore().
  Future<void> restore() async {
    final client = _newCastClient();
    try {
      await client.unmute();
    } catch (e) {
      debugPrint('[TvService] restore error: $e');
    } finally {
      await client.disconnect();
    }
  }

  /// Set volume (0-100).
  Future<void> setVolume(int percent) async {
    final client = _newCastClient();
    try {
      await client.setVolume(percent);
    } finally {
      await client.disconnect();
    }
  }

  /// Mute TV.
  Future<void> mute() async {
    final client = _newCastClient();
    try {
      await client.mute();
    } finally {
      await client.disconnect();
    }
  }

  /// Unmute TV.
  Future<void> unmute() async {
    final client = _newCastClient();
    try {
      await client.unmute();
    } finally {
      await client.disconnect();
    }
  }

  /// Stop current app without muting.
  Future<void> killApp() async {
    final client = _newCastClient();
    try {
      await client.stop();
    } catch (_) {
      // Ignore
    } finally {
      await client.disconnect();
    }
    try {
      await _dialClient.killApps();
    } catch (_) {
      // Ignore
    }
  }

  /// Check if TV is reachable via DIAL.
  Future<bool> isReachable() async {
    return _dialClient.isReachable();
  }

  /// Get device name via DIAL.
  Future<String?> getDeviceName() async {
    return _dialClient.getDeviceName();
  }
}
