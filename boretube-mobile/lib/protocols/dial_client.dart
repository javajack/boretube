import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// DIAL protocol client — kills apps via HTTP DELETE on port 8008
/// and fetches device description.
class DialClient {
  final String host;
  final int port;

  static const _timeout = Duration(seconds: 2);

  DialClient({required this.host, this.port = 8008});

  String get _baseUrl => 'http://$host:$port';

  /// Kill YouTube and Netflix via DIAL in parallel.
  /// Matches the bash do_bore() pattern of parallel curl DELETEs.
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
          .delete(Uri.parse('$_baseUrl/apps/$appName/run'))
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
          .get(Uri.parse('$_baseUrl/ssdp/device-desc.xml'))
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
          .get(Uri.parse('$_baseUrl/ssdp/device-desc.xml'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
