import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import 'discovered_device.dart';

/// Creates an mDNS client; injectable for tests.
typedef MdnsClientFactory = MDnsClient Function();

/// App-layer hook, e.g. to acquire/release an Android WifiManager
/// multicast lock around a query (multicast_dns needs one on Android).
typedef MulticastLockHook = Future<void> Function();

/// mDNS discovery of Cast, ADB and TV Guard services.
class MdnsDiscovery {
  static const castService = '_googlecast._tcp';
  static const adbService = '_adb._tcp';
  static const adbTlsService = '_adb-tls-connect._tcp';
  static const agentService = '_boretube._tcp';

  static const serviceTypes = [
    castService,
    adbService,
    adbTlsService,
    agentService,
  ];

  final MdnsClientFactory clientFactory;
  final MulticastLockHook? acquireMulticastLock;
  final MulticastLockHook? releaseMulticastLock;

  /// Timeout for each SRV / TXT / A lookup after a PTR answer.
  final Duration resolveTimeout;

  MdnsDiscovery({
    MdnsClientFactory? clientFactory,
    this.acquireMulticastLock,
    this.releaseMulticastLock,
    this.resolveTimeout = const Duration(milliseconds: 1500),
  }) : clientFactory = clientFactory ?? MDnsClient.new;

  /// Browses all [serviceTypes] for [timeout] and emits one
  /// [DiscoveredDevice] per resolved service instance and IPv4 address.
  Stream<DiscoveredDevice> discover({
    Duration timeout = const Duration(seconds: 4),
  }) {
    final out = StreamController<DiscoveredDevice>();
    Future<void> run() async {
      MDnsClient? client;
      try {
        await acquireMulticastLock?.call();
        final c = clientFactory();
        await c.start();
        client = c;
        await Future.wait([
          for (final s in serviceTypes) _browse(c, s, timeout, out),
        ]);
      } catch (_) {
        // mDNS unavailable (no multicast, permission); other sources
        // still run.
      } finally {
        client?.stop();
        try {
          await releaseMulticastLock?.call();
        } catch (_) {
          // Ignore lock release errors.
        }
        await out.close();
      }
    }

    unawaited(run());
    return out.stream;
  }

  Future<void> _browse(
    MDnsClient client,
    String service,
    Duration timeout,
    StreamController<DiscoveredDevice> out,
  ) async {
    final resolving = <Future<void>>[];
    final seen = <String>{};
    try {
      final ptrs = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('$service.local'),
        timeout: timeout,
      );
      await for (final ptr in ptrs) {
        if (!seen.add(ptr.domainName)) continue;
        resolving.add(_resolve(client, service, ptr.domainName, out));
      }
    } catch (_) {
      // Ignore lookup errors for this service type.
    }
    await Future.wait(resolving);
  }

  Future<void> _resolve(
    MDnsClient client,
    String service,
    String fqdn,
    StreamController<DiscoveredDevice> out,
  ) async {
    try {
      final srvs = await client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(fqdn),
            timeout: resolveTimeout,
          )
          .toList();
      final txts = await client
          .lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(fqdn),
            timeout: resolveTimeout,
          )
          .toList();
      final txt = <String, String>{
        for (final t in txts) ...parseTxt(t.text),
      };
      for (final srv in srvs) {
        final ips = await client
            .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
              timeout: resolveTimeout,
            )
            .map((a) => a.address)
            .where((a) => a.type == InternetAddressType.IPv4)
            .map((a) => a.address)
            .toSet();
        for (final ip in ips) {
          if (out.isClosed) return;
          out.add(deviceFor(
            service: service,
            fqdn: fqdn,
            ip: ip,
            port: srv.port,
            txt: txt,
          ));
        }
      }
    } catch (_) {
      // Ignore resolution failures for one instance.
    }
  }

  /// Builds a [DiscoveredDevice] from a resolved service instance.
  static DiscoveredDevice deviceFor({
    required String service,
    required String fqdn,
    required String ip,
    required int port,
    Map<String, String> txt = const {},
  }) {
    final ports = {service: port};
    String? nonEmpty(String? s) => s == null || s.isEmpty ? null : s;
    switch (service) {
      case castService:
        final id = nonEmpty(txt['id']);
        return DiscoveredDevice(
          ip: ip,
          source: DiscoverySource.mdns,
          castName: nonEmpty(txt['fn']),
          castModel: nonEmpty(txt['md']),
          castUuid: id == null ? null : normalizeUuid(id),
          ports: ports,
        );
      case adbService:
      case adbTlsService:
        return DiscoveredDevice(
          ip: ip,
          source: DiscoverySource.mdns,
          adbSerial: adbSerialFromInstance(fqdn),
          ports: ports,
        );
      case agentService:
        return DiscoveredDevice(
          ip: ip,
          source: DiscoverySource.mdns,
          agentId: nonEmpty(txt['id']),
          ports: ports,
        );
      default:
        return DiscoveredDevice(
          ip: ip,
          source: DiscoverySource.mdns,
          ports: ports,
        );
    }
  }

  /// Parses multicast_dns TXT text (one `key=value` per line).
  static Map<String, String> parseTxt(String text) {
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      if (line.isEmpty) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) {
        result[line] = '';
      } else {
        result[line.substring(0, eq)] = line.substring(eq + 1);
      }
    }
    return result;
  }

  /// ADB serial from an mDNS instance FQDN such as
  /// `adb-qaezcxxq07001865._adb._tcp.local` (the part before `._adb`).
  static String? adbSerialFromInstance(String fqdn) {
    final i = fqdn.indexOf('._adb');
    if (i <= 0) return null;
    return fqdn.substring(0, i);
  }

  /// Turns a 32-hex Cast id into the dashed UDN form used by
  /// device-desc.xml; other ids are returned lower-cased.
  static String normalizeUuid(String id) {
    final s = id.trim().toLowerCase();
    if (RegExp(r'^[0-9a-f]{32}$').hasMatch(s)) {
      return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
          '${s.substring(12, 16)}-${s.substring(16, 20)}-'
          '${s.substring(20)}';
    }
    return s;
  }
}
