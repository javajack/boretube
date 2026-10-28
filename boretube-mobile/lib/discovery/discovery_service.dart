import 'dart:async';

import '../tv/tv.dart';
import 'device_identifier.dart';
import 'discovered_device.dart';
import 'discovery_merger.dart';
import 'mdns_discovery.dart';
import 'net.dart';
import 'ssdp_discovery.dart';
import 'subnet_sweep.dart';

/// Finds TVs on the LAN by running mDNS, SSDP and a subnet sweep
/// together, merging the hits and identifying them via device-desc.xml.
class DiscoveryService {
  final MdnsDiscovery mdns;
  final SsdpDiscovery ssdp;
  final SubnetSweep sweep;
  final DeviceIdentifier identifier;
  final DiscoveryNet net;
  final DateTime Function() clock;

  /// Set false to skip the (slow) subnet sweep.
  final bool enableSweep;

  DiscoveryService({
    MdnsDiscovery? mdns,
    SsdpDiscovery? ssdp,
    SubnetSweep? sweep,
    DeviceIdentifier? identifier,
    this.net = const DiscoveryNet(),
    DateTime Function()? clock,
    this.enableSweep = true,
  })  : mdns = mdns ?? MdnsDiscovery(),
        ssdp = ssdp ?? SsdpDiscovery(),
        sweep = sweep ?? SubnetSweep(net: net),
        identifier = identifier ?? DeviceIdentifier(net: net),
        clock = clock ?? DateTime.now;

  /// Streams the growing, de-duplicated list of TVs found within
  /// [timeout]. The stream emits whenever the list changes (and at least
  /// once) and closes when all sources finish or [timeout] passes.
  Stream<List<Tv>> discover({
    Duration timeout = const Duration(seconds: 10),
    void Function(SweepEvent event)? onSweepProgress,
  }) {
    final merger = DiscoveryMerger();
    final identifying = <Future<void>>[];
    var stopped = false; // timeout passed: ignore new hits
    var gone = false; // listener cancelled
    var emitted = false;
    String? lastSignature;
    late final StreamController<List<Tv>> out;

    void emit({bool force = false}) {
      if (out.isClosed || gone) return;
      final list = merger.snapshot(clock());
      final sig = list
          .map((t) => '${t.id}|${t.ip}|${t.name}|${t.model}|'
              '${t.adbSerial}|${t.udn}|${t.castPort}|${t.adbPort}')
          .join(';');
      if (sig == lastSignature && !(force && !emitted)) return;
      lastSignature = sig;
      emitted = true;
      out.add(list);
    }

    void onDevice(DiscoveredDevice d) {
      if (stopped || gone) return;
      if (merger.add(d)) {
        identifying.add(
          identifier.identify(d.ip).then((desc) {
            merger.identify(d.ip, desc);
            emit();
          }),
        );
      }
      emit();
    }

    Duration part(int divisor) {
      final t = timeout ~/ divisor;
      return t < const Duration(seconds: 1) ? timeout : t;
    }

    Future<void> run() async {
      final sources = Future.wait([
        mdns.discover(timeout: part(2)).forEach(onDevice),
        ssdp.discover(timeout: part(2)).forEach(onDevice),
        if (enableSweep)
          sweep.run(isCancelled: () => stopped || gone).forEach((e) {
            if (!stopped && !gone) onSweepProgress?.call(e);
            final hit = e.hit;
            if (hit != null) {
              onDevice(DiscoveredDevice(
                ip: hit,
                source: DiscoverySource.sweep,
                ports: const {'dial': 8008, MdnsDiscovery.castService: 8009},
              ));
            }
          }),
      ]);
      await Future.any([sources, Future<void>.delayed(timeout)]);
      // Stop the sweep but let in-flight identification finish (bounded
      // by the identifier timeout).
      stopped = true;
      var done = 0;
      while (done < identifying.length) {
        final batch = identifying.sublist(done);
        done = identifying.length;
        await Future.wait(batch);
      }
      emit(force: true);
      await out.close();
    }

    out = StreamController<List<Tv>>(
      onListen: () => unawaited(run()),
      onCancel: () => gone = true,
    );
    return out.stream;
  }

  /// Finds a saved TV again: first a quick check at its saved IP, then a
  /// full [discover] matched by id, ADB serial or UDN. Returns the TV with
  /// its current IP and `lastSeen`, or null when it is not found.
  Future<Tv?> relocate(
    Tv saved, {
    Duration timeout = const Duration(seconds: 10),
    Duration quickTimeout = const Duration(milliseconds: 1500),
  }) async {
    final quick = await _quickCheck(saved, quickTimeout);
    if (quick != null) return quick;
    Tv? found;
    await for (final list in discover(timeout: timeout)) {
      for (final t in list) {
        if (matches(saved, t)) {
          found = t;
          break;
        }
      }
      if (found != null) break;
    }
    if (found == null) return null;
    return rebase(saved, found, clock());
  }

  Future<Tv?> _quickCheck(Tv saved, Duration timeout) async {
    final desc = await identifier.identify(
      saved.ip,
      port: saved.dialPort,
      timeout: timeout,
    );
    if (desc != null) {
      if (saved.udn != null && desc.udn != null && desc.udn != saved.udn) {
        return null; // Another device now has this IP.
      }
      final udn = saved.udn ?? desc.udn;
      return saved.copyWith(
        id: _upgradeId(saved, udn: udn),
        udn: udn,
        manufacturer: saved.manufacturer.isEmpty ? desc.manufacturer : null,
        model: saved.model.isEmpty ? desc.modelName : null,
        lastSeen: clock(),
      );
    }
    // No device-desc: we can only trust an open port for a TV whose
    // identity we never knew.
    if (saved.udn == null &&
        saved.adbSerial == null &&
        await net.tcpOpen(saved.ip, saved.castPort, timeout)) {
      return saved.copyWith(lastSeen: clock());
    }
    return null;
  }

  /// True when discovered [t] is the same TV as [saved].
  static bool matches(Tv saved, Tv t) {
    bool eq(String? a, String? b) => a != null && a.isNotEmpty && a == b;
    return (t.id == saved.id && !saved.id.startsWith('ip:')) ||
        eq(saved.adbSerial, t.adbSerial) ||
        eq(saved.udn, t.udn);
  }

  /// [saved] moved to [found]'s address; keeps the saved name and id
  /// (upgrading a temporary `ip:` id) and fills in missing identity.
  static Tv rebase(Tv saved, Tv found, DateTime now) {
    final adbSerial = saved.adbSerial ?? found.adbSerial;
    final udn = saved.udn ?? found.udn;
    return saved.copyWith(
      id: saved.id.startsWith('ip:') ? found.id : saved.id,
      ip: found.ip,
      castPort: found.castPort,
      dialPort: found.dialPort,
      adbPort: found.adbPort,
      agentPort: found.agentPort,
      adbSerial: adbSerial,
      udn: udn,
      manufacturer: saved.manufacturer.isEmpty ? found.manufacturer : null,
      model: saved.model.isEmpty ? found.model : null,
      lastSeen: now,
    );
  }

  static String _upgradeId(Tv saved, {String? udn}) {
    if (!saved.id.startsWith('ip:')) return saved.id;
    return Tv.stableId(adbSerial: saved.adbSerial, udn: udn, ip: saved.ip);
  }
}
