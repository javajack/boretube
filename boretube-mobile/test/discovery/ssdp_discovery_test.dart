import 'package:boretube_mobile/discovery/discovered_device.dart';
import 'package:boretube_mobile/discovery/ssdp_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

const _reply = 'HTTP/1.1 200 OK\r\n'
    'CACHE-CONTROL: max-age=1800\r\n'
    'Location: http://192.168.1.3:8008/ssdp/device-desc.xml\r\n'
    'ST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n';

void main() {
  test('search request targets DIAL', () {
    expect(SsdpDiscovery.searchRequest, startsWith('M-SEARCH * HTTP/1.1'));
    expect(SsdpDiscovery.searchRequest,
        contains('ST: urn:dial-multiscreen-org:service:dial:1'));
    expect(SsdpDiscovery.searchRequest, contains('239.255.255.250:1900'));
  });

  test('parseLocation is case-insensitive', () {
    expect(SsdpDiscovery.parseLocation(_reply)!.host, '192.168.1.3');
    expect(SsdpDiscovery.parseLocation('HTTP/1.1 200 OK\r\n\r\n'), isNull);
  });

  test('discover emits one device per IP from LOCATION', () async {
    String? sent;
    final ssdp = SsdpDiscovery(
      transport: (req, timeout) {
        sent = req;
        return Stream.fromIterable([
          (text: _reply, from: '192.168.1.3'),
          (text: _reply, from: '192.168.1.3'),
          (text: 'HTTP/1.1 200 OK\r\n\r\n', from: '192.168.1.20'),
        ]);
      },
    );
    final found = await ssdp.discover().toList();
    expect(sent, SsdpDiscovery.searchRequest);
    expect(found.map((d) => d.ip), ['192.168.1.3', '192.168.1.20']);
    expect(found.first.source, DiscoverySource.ssdp);
    expect(found.first.ports, {'dial': 8008});
  });
}
