import 'package:boretube_mobile/discovery/net.dart';

/// Scriptable [DiscoveryNet] for unit tests.
class FakeNet extends DiscoveryNet {
  /// `host:port` pairs that accept TCP.
  final Set<String> open;

  /// URL → response.
  final Map<String, NetResponse> get;
  final List<String> localIps;
  final List<String> connects = [];

  FakeNet({
    this.open = const {},
    this.get = const {},
    this.localIps = const [],
  });

  @override
  Future<bool> tcpOpen(String host, int port, Duration timeout) async {
    connects.add('$host:$port');
    return open.contains('$host:$port');
  }

  @override
  Future<NetResponse?> httpGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 3),
    Map<String, String>? headers,
  }) async =>
      get[uri.toString()];

  @override
  Future<NetResponse?> httpPost(
    Uri uri, {
    required String body,
    Duration timeout = const Duration(seconds: 3),
    Map<String, String>? headers,
  }) async =>
      get[uri.toString()];

  @override
  Future<List<String>> localIPv4s() async => localIps;
}

String deviceDesc({
  String name = 'Living Room TV',
  String udn = '4506a0af-4fcb-437e-993f-c16dad673aef',
}) =>
    '<?xml version="1.0"?><root xmlns="urn:schemas-upnp-org:device-1-0">'
    '<device><friendlyName>$name</friendlyName>'
    '<manufacturer>Sony</manufacturer><modelName>BRAVIA VU3</modelName>'
    '<UDN>uuid:$udn</UDN></device></root>';
