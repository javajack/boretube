// Opt-in, read-only test against the real TV on the LAN:
//   BORETUBE_LIVE=1 [BORETUBE_ADBKEY=~/.android/adbkey] \
//     flutter test test/discovery/discovery_live_test.dart
import 'dart:io';

import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:boretube_mobile/discovery/discovery_service.dart';
import 'package:boretube_mobile/discovery/mdns_discovery.dart';
import 'package:boretube_mobile/discovery/ssdp_discovery.dart';
import 'package:boretube_mobile/discovery/subnet_sweep.dart';
import 'package:boretube_mobile/tv/capabilities.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = Platform.environment['BORETUBE_LIVE'] == '1';
  final keyPath = Platform.environment['BORETUBE_ADBKEY'];
  final tvIp = Platform.environment['BORETUBE_TV_IP'] ?? '192.168.1.3';
  final skip = live ? false : 'set BORETUBE_LIVE=1';

  test('discover() finds the living room TV', () async {
    var sweepTotal = 0;
    var sweepScanned = 0;
    final sw = Stopwatch()..start();
    final lists = await DiscoveryService().discover(
      onSweepProgress: (e) {
        sweepTotal = e.total;
        sweepScanned = e.scanned;
      },
    ).toList();
    final tvs = lists.last;
    // ignore: avoid_print
    print('emissions=${lists.length} in ${sw.elapsedMilliseconds}ms, '
        'sweep $sweepScanned/$sweepTotal\n'
        '${tvs.map((t) => '${t.id} ${t.ip} "${t.name}" '
            '${t.manufacturer} ${t.model} adb=${t.adbSerial} '
            'udn=${t.udn}').join('\n')}');
    final tv = tvs.firstWhere((t) => t.ip == tvIp);
    expect(tv.name, 'Living Room TV');
    expect(tv.adbSerial, startsWith('adb-'));
    expect(tv.id, 'adb:${tv.adbSerial}');
    expect(tv.udn, isNotNull);
  }, skip: skip, timeout: const Timeout(Duration(seconds: 40)));

  test('each source finds the TV on its own', () async {
    final mdns = await MdnsDiscovery().discover().toList();
    final ssdp = await SsdpDiscovery().discover().toList();
    final hits = await const SubnetSweep()
        .run(subnets: [tvIp.substring(0, tvIp.lastIndexOf('.'))])
        .where((e) => e.hit != null)
        .map((e) => e.hit!)
        .toList();
    // ignore: avoid_print
    print('mdns=${mdns.join('\n')}\nssdp=$ssdp\nsweep=$hits');
    expect(mdns.where((d) => d.ip == tvIp), isNotEmpty);
    expect(ssdp.map((d) => d.ip), contains(tvIp));
    expect(hits, contains(tvIp));
  }, skip: skip, timeout: const Timeout(Duration(seconds: 40)));

  test('relocate() quick-checks the saved IP', () async {
    final saved = Tv(id: 'ip:$tvIp', name: 'TV', ip: tvIp);
    final t = await DiscoveryService().relocate(saved);
    expect(t, isNotNull);
    expect(t!.ip, tvIp);
    expect(t.udn, isNotNull);
    expect(t.id, startsWith('udn:'));
  }, skip: skip);

  test('probe() reports cast + dial + adb', () async {
    final key = keyPath == null
        ? null
        : AdbKey.fromPem(File(keyPath).readAsStringSync());
    final report = await CapabilityProber().probe(
      Tv(id: 'ip:$tvIp', name: 'TV', ip: tvIp),
      key: key,
    );
    // ignore: avoid_print
    print(report.details.entries
        .map((e) => '${e.key.name}: ${e.value}')
        .join('\n'));
    expect(report.capabilities, contains(TvCapability.cast));
    expect(report.capabilities, contains(TvCapability.dial));
    expect(report.tv.capabilitiesCheckedAt, isNotNull);
    if (key != null) {
      expect(report.capabilities, contains(TvCapability.adb));
      expect(report.detail(TvCapability.adb), 'authorized');
    }
  }, skip: skip);
}
