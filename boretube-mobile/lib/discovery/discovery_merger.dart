import '../tv/tv.dart';
import 'device_identifier.dart';
import 'discovered_device.dart';
import 'mdns_discovery.dart';

/// Everything learned about one IP so far.
class _Entry {
  final String ip;
  final Set<DiscoverySource> sources = {};
  String? castName;
  String? castModel;
  String? castUuid;
  String? adbSerial;
  bool adbSerialFromTls = false;
  String? agentId;
  int? castPort;
  int? dialPort;
  int? adbPort;
  int? agentPort;
  DeviceDescription? desc;

  _Entry(this.ip);

  String? get udn => desc?.udn ?? castUuid;

  /// True once something says this is a Cast/DIAL TV or runs TV Guard;
  /// an ADB-only host (e.g. a phone with wireless debugging) is not.
  bool get looksLikeTv =>
      desc != null ||
      castName != null ||
      castUuid != null ||
      agentId != null ||
      sources.contains(DiscoverySource.ssdp) ||
      sources.contains(DiscoverySource.sweep);
}

/// Merges raw discovery hits into a de-duplicated list of [Tv]s.
///
/// Hits are first merged by IP, then IP entries that share an agent id,
/// ADB serial or UDN are merged into one TV keyed by [Tv.stableId].
class DiscoveryMerger {
  final _entries = <String, _Entry>{};

  /// Adds a hit. Returns true when [d.ip] was not seen before.
  bool add(DiscoveredDevice d) {
    final isNew = !_entries.containsKey(d.ip);
    final e = _entries.putIfAbsent(d.ip, () => _Entry(d.ip));
    e.sources.add(d.source);
    e.castName ??= d.castName;
    e.castModel ??= d.castModel;
    e.castUuid ??= d.castUuid;
    e.agentId ??= d.agentId;
    final tls = d.ports.containsKey(MdnsDiscovery.adbTlsService);
    if (d.adbSerial != null &&
        (e.adbSerial == null || (e.adbSerialFromTls && !tls))) {
      e.adbSerial = d.adbSerial;
      e.adbSerialFromTls = tls;
    }
    e.castPort ??= d.ports[MdnsDiscovery.castService];
    e.adbPort ??= d.ports[MdnsDiscovery.adbService];
    e.agentPort ??= d.ports[MdnsDiscovery.agentService];
    e.dialPort ??= d.ports['dial'];
    return isNew;
  }

  /// Records the device-desc identity for [ip] (null = not identified).
  void identify(String ip, DeviceDescription? desc) {
    final e = _entries[ip];
    if (e != null && desc != null) e.desc = desc;
  }

  /// IPs seen so far.
  Iterable<String> get ips => _entries.keys;

  /// Current merged TVs, in first-seen order, stamped with [now].
  List<Tv> snapshot(DateTime now) {
    final groups = <List<_Entry>>[];
    for (final e in _entries.values.where((e) => e.looksLikeTv)) {
      final g = groups.where((g) => g.any((o) => _sameTv(o, e)));
      if (g.isEmpty) {
        groups.add([e]);
      } else {
        g.first.add(e);
      }
    }
    return [for (final g in groups) _toTv(g, now)];
  }

  static bool _sameTv(_Entry a, _Entry b) {
    bool eq(String? x, String? y) => x != null && x == y;
    return eq(a.agentId, b.agentId) ||
        eq(a.adbSerial, b.adbSerial) ||
        eq(a.udn, b.udn);
  }

  static Tv _toTv(List<_Entry> group, DateTime now) {
    T? first<T>(T? Function(_Entry e) f) {
      for (final e in group) {
        final v = f(e);
        if (v != null && (v is! String || v.isNotEmpty)) return v;
      }
      return null;
    }

    // Prefer the IP that answered Cast / device-desc.
    final main = group.firstWhere(
      (e) => e.desc != null || e.castPort != null,
      orElse: () => group.first,
    );
    final agentId = first((e) => e.agentId);
    final adbSerial = first((e) => e.adbSerial);
    final udn = first((e) => e.udn);
    final name = first((e) => e.castName) ??
        first((e) => e.desc?.friendlyName) ??
        first((e) => e.desc?.modelName) ??
        first((e) => e.castModel) ??
        'TV';
    return Tv(
      id: Tv.stableId(
        agentId: agentId,
        adbSerial: adbSerial,
        udn: udn,
        ip: main.ip,
      ),
      name: name,
      manufacturer: first((e) => e.desc?.manufacturer) ?? '',
      model: first((e) => e.desc?.modelName) ?? first((e) => e.castModel) ?? '',
      ip: main.ip,
      castPort: main.castPort ?? 8009,
      dialPort: main.dialPort ?? 8008,
      adbPort: first((e) => e.adbPort) ?? 5555,
      agentPort: first((e) => e.agentPort) ?? 8790,
      adbSerial: adbSerial,
      udn: udn,
      lastSeen: now,
    );
  }
}
