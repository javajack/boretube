import 'package:boretube_mobile/discovery/device_identifier.dart';
import 'package:boretube_mobile/discovery/discovered_device.dart';
import 'package:boretube_mobile/discovery/discovery_merger.dart';
import 'package:boretube_mobile/discovery/discovery_service.dart';
import 'package:boretube_mobile/discovery/mdns_discovery.dart';
import 'package:boretube_mobile/discovery/net.dart';
import 'package:boretube_mobile/discovery/ssdp_discovery.dart';
import 'package:boretube_mobile/discovery/subnet_sweep.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _StubMdns extends MdnsDiscovery {
  final List<DiscoveredDevice> devices;
  _StubMdns(this.devices);

  @override
  Stream<DiscoveredDevice> discover({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      Stream.fromIterable(devices);
}

const _uuid = '4506a0af-4fcb-437e-993f-c16dad673aef';
const _serial = 'adb-qaezcxxq07001865';
final _now = DateTime.utc(2026, 10, 28, 12);

DiscoveredDevice _castMdns(String ip) => DiscoveredDevice(
      ip: ip,
      source: DiscoverySource.mdns,
      castName: 'Living Room TV',
      castModel: 'BRAVIA VU3',
      castUuid: _uuid,
      ports: const {MdnsDiscovery.castService: 8009},
    );

DiscoveredDevice _adbMdns(String ip, {String serial = _serial}) =>
    DiscoveredDevice(
      ip: ip,
      source: DiscoverySource.mdns,
      adbSerial: serial,
      ports: const {MdnsDiscovery.adbService: 5555},
    );

const _desc = DeviceDescription(
  friendlyName: 'Desc Name',
  manufacturer: 'Sony',
  modelName: 'BRAVIA VU3',
  udn: _uuid,
);

DiscoveryService _service({
  List<DiscoveredDevice> mdns = const [],
  List<String> ssdpIps = const [],
  FakeNet? net,
  bool sweep = false,
}) {
  final n = net ?? FakeNet();
  return DiscoveryService(
    mdns: _StubMdns(mdns),
    ssdp: SsdpDiscovery(
      transport: (_, __) => Stream.fromIterable([
        for (final ip in ssdpIps)
          (
            text: 'LOCATION: http://$ip:8008/ssdp/device-desc.xml\r\n',
            from: ip,
          ),
      ]),
    ),
    net: n,
    sweep: SubnetSweep(net: n),
    enableSweep: sweep,
    clock: () => _now,
    identifier: DeviceIdentifier(net: n),
  );
}

void main() {
  group('DiscoveryMerger', () {
    test('cast + adb at one IP → one TV keyed by ADB serial', () {
      final m = DiscoveryMerger()
        ..add(_castMdns('192.168.1.3'))
        ..add(_adbMdns('192.168.1.3'));
      final tvs = m.snapshot(_now);
      expect(tvs, hasLength(1));
      final tv = tvs.single;
      expect(tv.id, 'adb:$_serial');
      expect(tv.name, 'Living Room TV');
      expect(tv.model, 'BRAVIA VU3');
      expect(tv.udn, _uuid);
      expect(tv.adbSerial, _serial);
      expect(tv.adbPort, 5555);
      expect(tv.lastSeen, _now);
    });

    test('ADB-only host is not a TV until identified', () {
      final m = DiscoveryMerger()..add(_adbMdns('192.168.1.50'));
      expect(m.snapshot(_now), isEmpty);
      m.identify('192.168.1.50', _desc);
      expect(m.snapshot(_now).single.id, 'adb:$_serial');
    });

    test('sweep hit identified by device-desc → udn id + desc name', () {
      final m = DiscoveryMerger()
        ..add(const DiscoveredDevice(
          ip: '10.0.0.7',
          source: DiscoverySource.sweep,
        ));
      expect(m.snapshot(_now).single.id, 'ip:10.0.0.7');
      m.identify('10.0.0.7', _desc);
      final tv = m.snapshot(_now).single;
      expect(tv.id, 'udn:$_uuid');
      expect(tv.name, 'Desc Name');
      expect(tv.manufacturer, 'Sony');
    });

    test('two IPs with the same UDN merge into one TV', () {
      final m = DiscoveryMerger()
        ..add(_castMdns('192.168.1.3'))
        ..add(const DiscoveredDevice(
          ip: '192.168.1.4',
          source: DiscoverySource.ssdp,
        ));
      m.identify('192.168.1.4', _desc);
      final tvs = m.snapshot(_now);
      expect(tvs, hasLength(1));
      expect(tvs.single.ip, '192.168.1.3');
    });

    test('different TVs stay separate', () {
      final m = DiscoveryMerger()
        ..add(_castMdns('192.168.1.3'))
        ..add(const DiscoveredDevice(
          ip: '192.168.1.9',
          source: DiscoverySource.mdns,
          castName: 'Bedroom TV',
          castUuid: 'other',
        ));
      expect(m.snapshot(_now).map((t) => t.name),
          ['Living Room TV', 'Bedroom TV']);
    });

    test('stable id prefers agent > adb > udn > ip', () {
      final m = DiscoveryMerger()
        ..add(_castMdns('192.168.1.3'))
        ..add(_adbMdns('192.168.1.3'))
        ..add(const DiscoveredDevice(
          ip: '192.168.1.3',
          source: DiscoverySource.mdns,
          agentId: 'guard-1',
          ports: {MdnsDiscovery.agentService: 8790},
        ));
      expect(m.snapshot(_now).single.id, 'agent:guard-1');
      expect(Tv.stableId(adbSerial: 'a', udn: 'u', ip: '1'), 'adb:a');
      expect(Tv.stableId(udn: 'u', ip: '1'), 'udn:u');
      expect(Tv.stableId(adbSerial: '', ip: '1'), 'ip:1');
    });

    test('legacy _adb serial wins over the tls-connect instance', () {
      final m = DiscoveryMerger()
        ..add(_castMdns('192.168.1.3'))
        ..add(const DiscoveredDevice(
          ip: '192.168.1.3',
          source: DiscoverySource.mdns,
          adbSerial: 'adb-qaez-Xy12',
          ports: {MdnsDiscovery.adbTlsService: 37000},
        ))
        ..add(_adbMdns('192.168.1.3'));
      final tv = m.snapshot(_now).single;
      expect(tv.adbSerial, _serial);
      expect(tv.adbPort, 5555);
    });
  });

  group('discover', () {
    test('merges mDNS, SSDP and sweep, enriched by device-desc', () async {
      final net = FakeNet(
        localIps: ['192.168.1.10'],
        open: {'192.168.1.3:8008', '192.168.1.3:8009'},
        get: {
          'http://192.168.1.3:8008/ssdp/device-desc.xml':
              NetResponse(200, deviceDesc()),
        },
      );
      final lists = await _service(
        mdns: [_castMdns('192.168.1.3'), _adbMdns('192.168.1.3')],
        ssdpIps: ['192.168.1.3'],
        net: net,
        sweep: true,
      ).discover(timeout: const Duration(seconds: 5)).toList();
      expect(lists, isNotEmpty);
      final tv = lists.last.single;
      expect(tv.id, 'adb:$_serial');
      expect(tv.ip, '192.168.1.3');
      expect(tv.manufacturer, 'Sony');
      expect(tv.udn, _uuid);
    });

    test('emits at least once even when nothing is found', () async {
      final lists = await _service()
          .discover(timeout: const Duration(seconds: 1))
          .toList();
      expect(lists, [isEmpty]);
    });

    test('reports sweep progress', () async {
      final events = <SweepEvent>[];
      await _service(net: FakeNet(localIps: ['10.1.2.3']), sweep: true)
          .discover(onSweepProgress: events.add)
          .drain<void>();
      expect(events.last.scanned, 253);
    });
  });

  group('relocate', () {
    const saved = Tv(
      id: 'adb:$_serial',
      name: 'My TV',
      ip: '192.168.1.3',
      adbSerial: _serial,
      udn: _uuid,
      capabilities: {TvCapability.cast},
    );

    test('quick check at the saved IP skips discovery', () async {
      final net = FakeNet(get: {
        'http://192.168.1.3:8008/ssdp/device-desc.xml':
            NetResponse(200, deviceDesc()),
      });
      final tv = await _service(net: net).relocate(saved);
      expect(tv!.ip, '192.168.1.3');
      expect(tv.id, saved.id);
      expect(tv.lastSeen, _now);
      expect(tv.capabilities, {TvCapability.cast});
    });

    test('moved TV is found by ADB serial at its new IP', () async {
      final tv = await _service(
        mdns: [_adbMdns('192.168.1.7'), _castMdns('192.168.1.7')],
      ).relocate(saved, timeout: const Duration(seconds: 2));
      expect(tv!.ip, '192.168.1.7');
      expect(tv.id, saved.id);
      expect(tv.name, 'My TV');
      expect(tv.lastSeen, _now);
    });

    test('another device at the saved IP is not accepted', () async {
      final net = FakeNet(get: {
        'http://192.168.1.3:8008/ssdp/device-desc.xml':
            NetResponse(200, deviceDesc(udn: 'someone-else')),
        'http://192.168.1.8:8008/ssdp/device-desc.xml':
            NetResponse(200, deviceDesc()),
      });
      final tv =
          await _service(net: net, ssdpIps: ['192.168.1.3', '192.168.1.8'])
              .relocate(saved, timeout: const Duration(seconds: 2));
      expect(tv!.ip, '192.168.1.8');
    });

    test('temporary ip: id is upgraded on quick check', () async {
      final net = FakeNet(get: {
        'http://192.168.1.3:8008/ssdp/device-desc.xml':
            NetResponse(200, deviceDesc()),
      });
      final tv = await _service(net: net).relocate(
        const Tv(id: 'ip:192.168.1.3', name: 'TV', ip: '192.168.1.3'),
      );
      expect(tv!.id, 'udn:$_uuid');
      expect(tv.udn, _uuid);
      expect(tv.manufacturer, 'Sony');
    });

    test('returns null when the TV is gone', () async {
      final tv = await _service(mdns: [_castMdns('192.168.1.9')]).relocate(
        saved.copyWith(udn: 'gone'),
        timeout: const Duration(seconds: 1),
      );
      expect(tv, isNull);
    });

    test('matches() ignores temporary ip: ids', () {
      const a = Tv(id: 'ip:1.2.3.4', name: 'A', ip: '1.2.3.4');
      expect(DiscoveryService.matches(a, a), isFalse);
      expect(DiscoveryService.matches(saved, saved), isTrue);
    });
  });
}
