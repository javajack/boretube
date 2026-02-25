import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// DIAL protocol client — kills apps via HTTP DELETE on port 8008,
/// fetches device description, and controls hardware volume via
/// Sony Bravia REST API (/sony/audio).
class DialClient {
  final String host;
  final int port;

  static const _timeout = Duration(seconds: 2);
  static const _sonyTimeout = Duration(seconds: 5);

  DialClient({required this.host, this.port = 8008});

  String get _baseUrl => 'http://$host:$port';

  /// Kill YouTube and Netflix via DIAL in parallel.
  Future<void> killApps() async {
    await Future.wait([
      _killApp('YouTube'),
      _killApp('Netflix'),
    ]);
  }

  /// Kill a specific app by name via DIAL HTTP DELETE.
  Future<bool> _killApp(String appName) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/apps/$appName/run'),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch device description XML for identification.
  Future<String?> getDeviceName() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/ssdp/device-desc.xml',
            ),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final doc = XmlDocument.parse(response.body);
        final friendlyName = doc.findAllElements(
          'friendlyName',
        );
        if (friendlyName.isNotEmpty) {
          return friendlyName.first.innerText;
        }
      }
    } catch (_) {
      // Device not reachable
    }
    return null;
  }

  /// Check if TV is reachable via DIAL port.
  Future<bool> isReachable() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/ssdp/device-desc.xml',
            ),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Sony Bravia REST API (hardware volume) ──

  /// Get actual TV hardware volume via Sony REST API.
  /// Returns (volume: 0-100, muted: bool) or null
  /// if the API is unavailable.
  Future<({int volume, bool muted})?> getHardwareVolume() async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$host/sony/audio'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'method': 'getVolumeInformation',
              'id': 33,
              'params': <Object>[],
              'version': '1.0',
            }),
          )
          .timeout(_sonyTimeout);

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body)
          as Map<String, dynamic>;
      return parseVolumeResponse(json);
    } catch (e) {
      debugPrint(
        '[DialClient] getHardwareVolume error: $e',
      );
    }
    return null;
  }

  /// Parse Sony getVolumeInformation JSON response.
  /// Exposed for testing.
  @visibleForTesting
  static ({int volume, bool muted})? parseVolumeResponse(
    Map<String, dynamic> json,
  ) {
    final result = json['result'] as List?;
    if (result == null || result.isEmpty) {
      return null;
    }

    final volumes = result[0] as List;
    for (final v in volumes) {
      if (v is Map<String, dynamic>) {
        final target = v['target'] as String?;
        if (target == 'speaker' ||
            target == 'headphone') {
          return (
            volume: v['volume'] as int? ?? 0,
            muted: v['mute'] as bool? ?? false,
          );
        }
      }
    }
    return null;
  }

  /// Set actual TV hardware volume via Sony REST API.
  Future<bool> setHardwareVolume(int volume) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$host/sony/audio'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'method': 'setAudioVolume',
              'id': 98,
              'params': [
                {
                  'target': 'speaker',
                  'volume': '$volume',
                },
              ],
              'version': '1.0',
            }),
          )
          .timeout(_sonyTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(
        '[DialClient] setHardwareVolume error: $e',
      );
      return false;
    }
  }

  /// Mute/unmute TV hardware via Sony REST API.
  Future<bool> setHardwareMute(bool muted) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$host/sony/audio'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'method': 'setAudioMute',
              'id': 601,
              'params': [
                {'status': muted},
              ],
              'version': '1.0',
            }),
          )
          .timeout(_sonyTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(
        '[DialClient] setHardwareMute error: $e',
      );
      return false;
    }
  }
}
