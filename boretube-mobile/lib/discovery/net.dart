import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A minimal HTTP response used by discovery and probing.
class NetResponse {
  final int statusCode;
  final String body;

  const NetResponse(this.statusCode, this.body);
}

/// Network primitives used by discovery and capability probing.
///
/// Everything that touches the network goes through this class so tests
/// can substitute a fake.
class DiscoveryNet {
  const DiscoveryNet();

  /// True when a TCP connection to [host]:[port] succeeds within [timeout].
  Future<bool> tcpOpen(String host, int port, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// HTTP GET; null on any network error or timeout.
  Future<NetResponse?> httpGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 3),
    Map<String, String>? headers,
  }) async {
    try {
      final r = await http.get(uri, headers: headers).timeout(timeout);
      return NetResponse(r.statusCode, r.body);
    } catch (_) {
      return null;
    }
  }

  /// HTTP POST; null on any network error or timeout.
  Future<NetResponse?> httpPost(
    Uri uri, {
    required String body,
    Duration timeout = const Duration(seconds: 3),
    Map<String, String>? headers,
  }) async {
    try {
      final r =
          await http.post(uri, headers: headers, body: body).timeout(timeout);
      return NetResponse(r.statusCode, r.body);
    } catch (_) {
      return null;
    }
  }

  /// Non-loopback, non-link-local IPv4 addresses of this device.
  Future<List<String>> localIPv4s() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      return [
        for (final i in ifaces)
          for (final a in i.addresses)
            if (!a.isLoopback && !a.address.startsWith('169.254.')) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }
}
