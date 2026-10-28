import 'dart:async';

import 'net.dart';

/// Progress or a hit from a [SubnetSweep].
class SweepEvent {
  final int scanned;
  final int total;

  /// IP of a host with both Cast ports open, if this event is a hit.
  final String? hit;

  const SweepEvent({required this.scanned, required this.total, this.hit});

  @override
  String toString() => 'SweepEvent($scanned/$total${hit != null ? ' '
      'hit=$hit' : ''})';
}

/// Fallback discovery: TCP-probes every host of the local /24s (plus
/// reachable upstream gateway subnets) for Cast ports 8008 and 8009.
class SubnetSweep {
  /// Same list as detect.sh.
  static const gatewayCandidates = [
    '192.168.0.1',
    '192.168.1.1',
    '192.168.2.1',
    '10.0.0.1',
    '10.0.1.1',
    '172.16.0.1',
  ];

  /// Ports tried to decide a gateway is reachable (no ICMP from Dart).
  static const gatewayPorts = [80, 443, 53];

  static const castPorts = [8008, 8009];

  final DiscoveryNet net;
  final int concurrency;
  final Duration probeTimeout;

  const SubnetSweep({
    this.net = const DiscoveryNet(),
    this.concurrency = 50,
    this.probeTimeout = const Duration(milliseconds: 600),
  });

  /// The /24 bases (e.g. `192.168.1`) to scan: every local IPv4's /24,
  /// then each gateway candidate whose /24 is not local but which
  /// answers TCP on 80, 443 or 53.
  Future<List<String>> candidateSubnets({List<String>? localIps}) async {
    final locals = localIps ?? await net.localIPv4s();
    final bases = <String>[];
    for (final ip in locals) {
      final b = subnetBase(ip);
      if (b != null && !bases.contains(b)) bases.add(b);
    }
    final extra = await Future.wait([
      for (final gw in gatewayCandidates)
        if (!bases.contains(subnetBase(gw)))
          _reachable(gw).then((ok) => ok ? subnetBase(gw) : null),
    ]);
    for (final b in extra) {
      if (b != null && !bases.contains(b)) bases.add(b);
    }
    return bases;
  }

  Future<bool> _reachable(String host) async {
    final results = await Future.wait([
      for (final p in gatewayPorts) net.tcpOpen(host, p, probeTimeout),
    ]);
    return results.any((ok) => ok);
  }

  /// `a.b.c` for an IPv4 `a.b.c.d`, or null when not IPv4.
  static String? subnetBase(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    if (parts.any((p) => int.tryParse(p) == null)) return null;
    return parts.sublist(0, 3).join('.');
  }

  /// Scans hosts .1-.254 of [subnets] (default: [candidateSubnets]),
  /// skipping this device's own IPs. Emits progress after each host and
  /// a hit event for each host with 8008 and 8009 open. Stops early when
  /// [isCancelled] returns true.
  Stream<SweepEvent> run({
    List<String>? subnets,
    List<String>? localIps,
    bool Function()? isCancelled,
  }) {
    final out = StreamController<SweepEvent>();
    Future<void> go() async {
      try {
        final locals = localIps ?? await net.localIPv4s();
        final bases = subnets ?? await candidateSubnets(localIps: locals);
        final hosts = [
          for (final b in bases)
            for (var i = 1; i <= 254; i++)
              if (!locals.contains('$b.$i')) '$b.$i',
        ];
        final total = hosts.length;
        var scanned = 0;
        var next = 0;
        Future<void> worker() async {
          while (next < hosts.length) {
            if (out.isClosed || (isCancelled?.call() ?? false)) return;
            final host = hosts[next++];
            final hit = await _isCast(host);
            scanned++;
            if (out.isClosed) return;
            out.add(SweepEvent(
              scanned: scanned,
              total: total,
              hit: hit ? host : null,
            ));
          }
        }

        out.add(SweepEvent(scanned: 0, total: total));
        await Future.wait([
          for (var i = 0; i < concurrency; i++) worker(),
        ]);
      } catch (_) {
        // Sweep is best effort.
      } finally {
        await out.close();
      }
    }

    unawaited(go());
    return out.stream;
  }

  Future<bool> _isCast(String host) async {
    if (!await net.tcpOpen(host, castPorts[1], probeTimeout)) return false;
    return net.tcpOpen(host, castPorts[0], probeTimeout);
  }
}
