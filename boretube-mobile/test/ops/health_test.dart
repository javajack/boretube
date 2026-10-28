import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tv.dart';

void main() {
  final vu3 = loadProfile('sony-bravia-vu3');
  final generic = loadProfile('generic');

  Map<String, HealthCheck> byId(List<HealthCheck> l) =>
      {for (final c in l) c.id: c};

  test('real VU3 state is all green and computing writes nothing', () async {
    final tv = FakeTv();
    final checks = byId(
      await computeHealth(TvOps(adb: tv, profile: vu3, tvId: 't')),
    );
    expect(
        checks.keys, ['adb', 'cleanup', 'stockYouTube', 'speech', 'launcher']);
    for (final c in checks.values) {
      expect(c.status, HealthStatus.ok, reason: '$c');
      expect(c.fix, isNull);
    }
    expect(checks['cleanup']!.detail, '18/18 disabled');
    expect(tv.writes, isEmpty);
  });

  test('problems get warn/fail with fixes that work', () async {
    final tv = FakeTv()
      ..installed.add('com.google.android.youtube.tv')
      ..a11y = 'null'
      ..dumpsys['com.google.android.tts'] = FakeTv.updatedTtsDump();
    tv.disabled.remove('com.sony.dtv.promos');
    final ops = TvOps(adb: tv, profile: vu3, tvId: 't');
    final checks = byId(await computeHealth(ops));
    expect(checks['cleanup']!.status, HealthStatus.warn);
    expect(checks['cleanup']!.detail, contains('17/18'));
    expect(checks['stockYouTube']!.status, HealthStatus.warn);
    expect(checks['speech']!.status, HealthStatus.fail);
    expect(checks['launcher']!.status, HealthStatus.fail);
    expect(tv.writes, isEmpty);

    for (final c in checks.values) {
      await c.fix?.call();
    }
    final after = byId(await computeHealth(ops));
    for (final c in after.values) {
      expect(c.status, HealthStatus.ok, reason: '$c');
    }
  });

  test('stock YouTube allowed is ok', () async {
    final tv = FakeTv()..installed.add('com.google.android.youtube.tv');
    final checks = byId(
      await computeHealth(
        TvOps(adb: tv, profile: vu3, tvId: 't'),
        allowStockYouTube: true,
      ),
    );
    expect(checks['stockYouTube']!.status, HealthStatus.ok);
  });

  test('generic profile offers no fixes', () async {
    final tv = FakeTv()..a11y = 'null';
    final checks = byId(
      await computeHealth(TvOps(adb: tv, profile: generic, tvId: 't')),
    );
    expect(checks['launcher']!.status, HealthStatus.fail);
    expect(checks['launcher']!.fix, isNull);
    expect(checks.containsKey('cleanup'), isFalse);
  });

  test('ADB failure short-circuits', () async {
    final tv = FakeTv()..failing.add('echo ok');
    final checks = await computeHealth(
      TvOps(adb: tv, profile: vu3, tvId: 't'),
    );
    expect(checks.single.id, 'adb');
    expect(checks.single.status, HealthStatus.fail);
  });
}
