// Opt-in, READ-ONLY test against a real TV. Never calls fix() or any write:
//   BORETUBE_TV=192.168.1.3:5555 BORETUBE_ADBKEY=~/.android/adbkey \
//     flutter test test/ops/ops_live_test.dart
import 'dart:io';

import 'package:boretube_mobile/adb/adb_key.dart';
import 'package:boretube_mobile/adb/adb_session.dart';
import 'package:boretube_mobile/ops/device_profile.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final target = Platform.environment['BORETUBE_TV'];
  final keyPath = Platform.environment['BORETUBE_ADBKEY'];
  final skip = target == null || keyPath == null
      ? 'set BORETUBE_TV and BORETUBE_ADBKEY'
      : false;

  test('profile match + health on the real TV (read-only)', () async {
    final parts = target!.split(':');
    final tv = Tv(
      id: 'ip:${parts[0]}',
      name: 'live',
      ip: parts[0],
      adbPort: parts.length > 1 ? int.parse(parts[1]) : 5555,
    );
    final session = AdbSession(
      tv: tv,
      key: AdbKey.fromPem(File(keyPath!).readAsStringSync()),
      keepAlive: null,
    );
    addTearDown(session.dispose);
    await session.connect();
    expect(session.state, isA<AdbConnected>());

    final repo = ProfileRepository([
      for (final p in ProfileRepository.assetPaths)
        DeviceProfile.fromJsonString(File(p).readAsStringSync()),
    ]);
    final props = await DeviceProps.read(session);
    final match = repo.match(props);
    final ops = TvOps(adb: session, profile: match.profile, tvId: tv.id);
    final checks = await computeHealth(ops);
    final apps = await ops.listApps();
    final vol = await ops.readVolume();
    final fg = await ops.foregroundPackage();

    // ignore: avoid_print
    print('props=$props profile=${match.profile.id} '
        'buildTested=${match.buildTested}\n'
        '${checks.join('\n')}\n'
        'apps=${apps.length} launchable='
        '${apps.where((a) => a.launchable).length} volume=$vol fg=$fg');

    expect(checks.first.status, HealthStatus.ok);
    expect(checks.every((c) => c.status != HealthStatus.unknown), isTrue);
    expect(vol, isNotNull);
    if (props.manufacturer == 'Sony' && props.device.startsWith('BRAVIA_VU3')) {
      expect(match.profile.id, 'sony-bravia-vu3');
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
