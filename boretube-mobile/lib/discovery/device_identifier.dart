import 'package:xml/xml.dart';

import 'net.dart';

/// Identity read from a DIAL/UPnP `device-desc.xml`.
class DeviceDescription {
  final String friendlyName;
  final String manufacturer;
  final String modelName;

  /// UDN without the `uuid:` prefix, lower-cased; null when absent.
  final String? udn;

  const DeviceDescription({
    required this.friendlyName,
    this.manufacturer = '',
    this.modelName = '',
    this.udn,
  });

  @override
  String toString() =>
      'DeviceDescription("$friendlyName", $manufacturer $modelName, $udn)';
}

/// Identifies a host via `GET http://ip:8008/ssdp/device-desc.xml`.
class DeviceIdentifier {
  final DiscoveryNet net;
  final Duration timeout;

  const DeviceIdentifier({
    this.net = const DiscoveryNet(),
    this.timeout = const Duration(seconds: 3),
  });

  Future<DeviceDescription?> identify(
    String ip, {
    int port = 8008,
    Duration? timeout,
  }) async {
    final r = await net.httpGet(
      Uri.parse('http://$ip:$port/ssdp/device-desc.xml'),
      timeout: timeout ?? this.timeout,
    );
    if (r == null || r.statusCode != 200) return null;
    return parse(r.body);
  }

  /// Parses device-desc XML; null when it has no usable device element.
  static DeviceDescription? parse(String xml) {
    try {
      final doc = XmlDocument.parse(xml);
      final device = doc.findAllElements('device').firstOrNull;
      if (device == null) return null;
      String text(String name) =>
          device.findElements(name).firstOrNull?.innerText.trim() ?? '';
      final name = text('friendlyName');
      var udn = text('UDN');
      if (udn.toLowerCase().startsWith('uuid:')) udn = udn.substring(5);
      udn = udn.trim().toLowerCase();
      if (name.isEmpty && udn.isEmpty) return null;
      return DeviceDescription(
        friendlyName: name,
        manufacturer: text('manufacturer'),
        modelName: text('modelName'),
        udn: udn.isEmpty ? null : udn,
      );
    } catch (_) {
      return null;
    }
  }
}
