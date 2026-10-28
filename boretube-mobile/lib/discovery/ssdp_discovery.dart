import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'discovered_device.dart';

/// One UDP reply: its text and the sender's address.
typedef SsdpReply = ({String text, String from});

/// Sends [request] to the SSDP multicast group and streams replies for
/// [timeout]; injectable for tests.
typedef SsdpTransport = Stream<SsdpReply> Function(
  String request,
  Duration timeout,
);

/// SSDP (DIAL) discovery via M-SEARCH.
class SsdpDiscovery {
  static const dialSearchTarget = 'urn:dial-multiscreen-org:service:dial:1';
  static const multicastAddress = '239.255.255.250';
  static const multicastPort = 1900;

  final SsdpTransport transport;

  SsdpDiscovery({SsdpTransport? transport})
      : transport = transport ?? udpTransport;

  static String get searchRequest => 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: $multicastAddress:$multicastPort\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $dialSearchTarget\r\n'
      '\r\n';

  /// Emits one [DiscoveredDevice] per distinct responding IP.
  Stream<DiscoveredDevice> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async* {
    final seen = <String>{};
    try {
      await for (final reply in transport(searchRequest, timeout)) {
        final location = parseLocation(reply.text);
        final ip = location?.host ?? reply.from;
        if (ip.isEmpty || !seen.add(ip)) continue;
        yield DiscoveredDevice(
          ip: ip,
          source: DiscoverySource.ssdp,
          ports: {
            if (location != null && location.hasPort) 'dial': location.port,
          },
        );
      }
    } catch (_) {
      // UDP unavailable; other sources still run.
    }
  }

  /// The LOCATION header of an SSDP response, if any.
  static Uri? parseLocation(String response) {
    for (final line in const LineSplitter().convert(response)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      if (line.substring(0, colon).trim().toLowerCase() != 'location') {
        continue;
      }
      return Uri.tryParse(line.substring(colon + 1).trim());
    }
    return null;
  }

  /// Default transport over a real UDP socket. Sends the request twice
  /// (UDP is lossy).
  static Stream<SsdpReply> udpTransport(
    String request,
    Duration timeout,
  ) {
    final out = StreamController<SsdpReply>();
    Future<void> run() async {
      RawDatagramSocket? socket;
      try {
        socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket.multicastHops = 4;
        final s = socket;
        s.listen((event) {
          if (event != RawSocketEvent.read) return;
          final d = s.receive();
          if (d == null || out.isClosed) return;
          out.add((
            text: utf8.decode(d.data, allowMalformed: true),
            from: d.address.address,
          ));
        });
        final group = InternetAddress(multicastAddress);
        final bytes = utf8.encode(request);
        const gap = Duration(milliseconds: 300);
        s.send(bytes, group, multicastPort);
        await Future<void>.delayed(gap);
        s.send(bytes, group, multicastPort);
        if (timeout > gap) await Future<void>.delayed(timeout - gap);
      } catch (_) {
        // Ignore; stream just ends.
      } finally {
        socket?.close();
        await out.close();
      }
    }

    unawaited(run());
    return out.stream;
  }
}
