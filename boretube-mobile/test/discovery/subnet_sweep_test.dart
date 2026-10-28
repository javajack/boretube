import 'package:boretube_mobile/discovery/subnet_sweep.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('subnetBase', () {
    expect(SubnetSweep.subnetBase('192.168.1.10'), '192.168.1');
    expect(SubnetSweep.subnetBase('fe80::1'), isNull);
    expect(SubnetSweep.subnetBase('1.2.3'), isNull);
  });

  group('candidateSubnets', () {
    test('local /24 always; gateways only when TCP answers', () async {
      final net = FakeNet(
        localIps: ['192.168.31.5'],
        open: {'192.168.1.1:80', '10.0.0.1:53'},
      );
      final bases = await SubnetSweep(net: net).candidateSubnets();
      expect(bases, ['192.168.31', '192.168.1', '10.0.0']);
    });

    test('gateway in the local /24 is not probed', () async {
      final net = FakeNet(localIps: ['192.168.1.10']);
      final bases = await SubnetSweep(net: net).candidateSubnets();
      expect(bases, ['192.168.1']);
      expect(net.connects.where((c) => c.startsWith('192.168.1.1:')), isEmpty);
      expect(net.connects, contains('192.168.0.1:443'));
    });

    test('duplicate local subnets collapse', () async {
      final net = FakeNet(localIps: ['10.0.0.2', '10.0.0.3']);
      expect(await SubnetSweep(net: net).candidateSubnets(), ['10.0.0']);
    });
  });

  test('run needs 8008 AND 8009, reports progress, skips own IP', () async {
    final net = FakeNet(
      localIps: ['192.168.1.10'],
      open: {
        '192.168.1.3:8008',
        '192.168.1.3:8009',
        '192.168.1.4:8009', // only one Cast port: not a hit
        '192.168.1.10:8008',
        '192.168.1.10:8009', // ourselves
      },
    );
    final events = await SubnetSweep(net: net).run().toList();
    expect(events.first.scanned, 0);
    expect(events.last.scanned, 253);
    expect(events.last.total, 253);
    expect(
        events.where((e) => e.hit != null).map((e) => e.hit), ['192.168.1.3']);
  });

  test('run stops when cancelled', () async {
    final net = FakeNet(localIps: ['192.168.1.10']);
    var n = 0;
    final events = await SubnetSweep(net: net, concurrency: 1)
        .run(subnets: ['192.168.1'], isCancelled: () => ++n > 5).toList();
    expect(events.last.scanned, lessThan(10));
    expect(events.last.total, 253);
  });
}
