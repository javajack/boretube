import 'dart:async';
import 'dart:io';

import 'package:boretube_mobile/discovery/discovered_device.dart';
import 'package:boretube_mobile/discovery/mdns_discovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Answers lookups from a fixed record table keyed by `type:name`.
class FakeMdnsClient extends Fake implements MDnsClient {
  final Map<String, List<ResourceRecord>> records;
  bool started = false;
  bool stopped = false;

  FakeMdnsClient(this.records);

  @override
  Future<void> start({
    InternetAddress? listenAddress,
    NetworkInterfacesFactory? interfacesFactory,
    int mDnsPort = 5353,
    InternetAddress? mDnsAddress,
    Function? onError,
  }) async =>
      started = true;

  @override
  void stop() => stopped = true;

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      Stream.fromIterable(
        (records['${query.resourceRecordType}:${query.fullyQualifiedName}'] ??
                const [])
            .whereType<T>(),
      );
}

const _castFqdn =
    'BRAVIA-VU3-4506a0af4fcb437e993fc16dad673aef._googlecast._tcp.local';
const _adbFqdn = 'adb-qaezcxxq07001865._adb._tcp.local';

Map<String, List<ResourceRecord>> _vu3Records() {
  const ptr = ResourceRecordType.serverPointer;
  const srv = ResourceRecordType.service;
  const txt = ResourceRecordType.text;
  const a = ResourceRecordType.addressIPv4;
  return {
    '$ptr:_googlecast._tcp.local': [
      const PtrResourceRecord('_googlecast._tcp.local', 0,
          domainName: _castFqdn),
    ],
    '$srv:$_castFqdn': [
      const SrvResourceRecord(_castFqdn, 0,
          target: 'uuid.local', port: 8009, priority: 0, weight: 0),
    ],
    '$txt:$_castFqdn': [
      const TxtResourceRecord(_castFqdn, 0,
          text: 'id=4506a0af4fcb437e993fc16dad673aef\nmd=BRAVIA VU3\n'
              'fn=Living Room TV\nrm=\n'),
    ],
    '$a:uuid.local': [
      IPAddressResourceRecord('uuid.local', 0,
          address: InternetAddress('192.168.1.3')),
    ],
    '$ptr:_adb._tcp.local': [
      const PtrResourceRecord('_adb._tcp.local', 0, domainName: _adbFqdn),
      // Duplicate answers are ignored.
      const PtrResourceRecord('_adb._tcp.local', 0, domainName: _adbFqdn),
    ],
    '$srv:$_adbFqdn': [
      const SrvResourceRecord(_adbFqdn, 0,
          target: 'Android.local', port: 5555, priority: 0, weight: 0),
    ],
    '$a:Android.local': [
      IPAddressResourceRecord('Android.local', 0,
          address: InternetAddress('192.168.1.3')),
    ],
  };
}

void main() {
  group('parsing', () {
    test('parseTxt splits key=value lines', () {
      expect(
        MdnsDiscovery.parseTxt('id=abc\nfn=Living Room TV\nrm=\nflag\n'),
        {'id': 'abc', 'fn': 'Living Room TV', 'rm': '', 'flag': ''},
      );
    });

    test('adbSerialFromInstance takes the part before ._adb', () {
      expect(MdnsDiscovery.adbSerialFromInstance(_adbFqdn),
          'adb-qaezcxxq07001865');
      expect(
        MdnsDiscovery.adbSerialFromInstance(
            'adb-qaez-AbC123._adb-tls-connect._tcp.local'),
        'adb-qaez-AbC123',
      );
      expect(MdnsDiscovery.adbSerialFromInstance('x._googlecast'), isNull);
    });

    test('normalizeUuid dashes 32-hex cast ids', () {
      expect(MdnsDiscovery.normalizeUuid('4506A0AF4FCB437E993FC16DAD673AEF'),
          '4506a0af-4fcb-437e-993f-c16dad673aef');
      expect(MdnsDiscovery.normalizeUuid('not-a-uuid'), 'not-a-uuid');
    });

    test('deviceFor maps the agent service id', () {
      final d = MdnsDiscovery.deviceFor(
        service: MdnsDiscovery.agentService,
        fqdn: 'guard._boretube._tcp.local',
        ip: '10.0.0.9',
        port: 8790,
        txt: {'id': 'agent-1'},
      );
      expect(d.agentId, 'agent-1');
      expect(d.ports, {'_boretube._tcp': 8790});
    });
  });

  test('discover resolves PTR → SRV/TXT/A for all services', () async {
    final client = FakeMdnsClient(_vu3Records());
    final events = <String>[];
    final mdns = MdnsDiscovery(
      clientFactory: () => client,
      acquireMulticastLock: () async => events.add('acquire'),
      releaseMulticastLock: () async => events.add('release'),
    );
    final found = await mdns.discover().toList();
    expect(client.started, isTrue);
    expect(client.stopped, isTrue);
    expect(events, ['acquire', 'release']);
    expect(found, hasLength(2));
    final cast = found.firstWhere((d) => d.castName != null);
    expect(cast.ip, '192.168.1.3');
    expect(cast.source, DiscoverySource.mdns);
    expect(cast.castName, 'Living Room TV');
    expect(cast.castModel, 'BRAVIA VU3');
    expect(cast.castUuid, '4506a0af-4fcb-437e-993f-c16dad673aef');
    expect(cast.ports, {'_googlecast._tcp': 8009});
    final adb = found.firstWhere((d) => d.adbSerial != null);
    expect(adb.adbSerial, 'adb-qaezcxxq07001865');
    expect(adb.ports, {'_adb._tcp': 5555});
  });

  test('a failing client yields an empty stream and releases the lock',
      () async {
    var released = false;
    final mdns = MdnsDiscovery(
      clientFactory: () => throw const SocketException('no multicast'),
      releaseMulticastLock: () async => released = true,
    );
    expect(await mdns.discover().toList(), isEmpty);
    expect(released, isTrue);
  });
}
