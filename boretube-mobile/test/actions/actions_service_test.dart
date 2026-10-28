import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/protocols/castv2_client.dart';
import 'package:boretube_mobile/protocols/dial_client.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ops/fake_tv.dart';

class FakeSony implements SonyAudio {
  final calls = <String>[];
  bool works = true;
  @override
  Future<({int volume, bool muted})?> getHardwareVolume() async =>
      (volume: 10, muted: false);
  @override
  Future<bool> setHardwareVolume(int volume) async {
    calls.add('volume $volume');
    return works;
  }

  @override
  Future<bool> setHardwareMute(bool muted) async {
    calls.add('mute $muted');
    return works;
  }
}

class FakeCast implements CastV2Client {
  final List<String> calls;
  FakeCast(this.calls);
  @override
  Future<bool> stop() async => _c('stop');
  @override
  Future<bool> mute() async => _c('mute');
  @override
  Future<bool> unmute() async => _c('unmute');
  @override
  Future<bool> setVolume(int percent) async => _c('volume $percent');
  @override
  Future<void> disconnect() async => calls.add('disconnect');
  bool _c(String s) {
    calls.add(s);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDial implements DialClient {
  int kills = 0;
  @override
  Future<void> killApps() async => kills++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Tv _tv(Set<TvCapability> caps) =>
    Tv(id: 'ip:1', name: 'TV', ip: '10.0.0.9', capabilities: caps);

void main() {
  final vu3 = loadProfile('sony-bravia-vu3');
  late FakeTv fake;
  late TvOps ops;
  late FakeSony sony;
  late List<String> cast;
  late FakeDial dial;

  ActionsService svc(Set<TvCapability> caps, {bool withAdb = true}) =>
      ActionsService(
        _tv(caps),
        adb: withAdb ? ops : null,
        cast: () => FakeCast(cast),
        sony: sony,
        dial: dial,
      );

  setUp(() {
    fake = FakeTv();
    ops = TvOps(adb: fake, profile: vu3, tvId: 't');
    sony = FakeSony();
    cast = [];
    dial = FakeDial();
  });

  const all = {
    TvCapability.cast,
    TvCapability.dial,
    TvCapability.sonyRest,
    TvCapability.adb,
  };

  test('mute prefers Sony REST', () async {
    final r = await svc(all).mute();
    expect(r.via, ActionTransport.sonyRest);
    expect(sony.calls, ['mute true']);
    expect(fake.writes, isEmpty);
  });

  test('mute falls back to ADB when Sony REST fails', () async {
    sony.works = false;
    final r = await svc(all).mute();
    expect(r.ok, isTrue);
    expect(r.via, ActionTransport.adb);
    expect(fake.writes, ['input keyevent KEYCODE_VOLUME_MUTE']);
  });

  test('unmute via ADB is a no-op when not muted', () async {
    final r = await svc({TvCapability.adb}).unmute();
    expect(r.ok, isTrue);
    expect(fake.writes, isEmpty);
  });

  test('cast-only TV uses Cast', () async {
    final r = await svc({TvCapability.cast}, withAdb: false).mute();
    expect(r.via, ActionTransport.cast);
    expect(cast, ['mute', 'disconnect']);
  });

  test('adb capability without TvOps is skipped', () async {
    final r = await svc({TvCapability.adb}, withAdb: false).mute();
    expect(r.ok, isFalse);
    expect(r.via, ActionTransport.none);
  });

  test('setVolume via Sony REST sets the absolute value', () async {
    await svc(all).setVolume(30);
    expect(sony.calls, ['volume 30']);
  });

  test('setVolume via ADB steps by the difference', () async {
    final r = await svc({TvCapability.adb, TvCapability.cast}).setVolume(5);
    expect(r.via, ActionTransport.adb);
    expect(
        fake.writes.single.split(' ').skip(2).toSet(), {'KEYCODE_VOLUME_DOWN'});
    expect(fake.writes.single.split(' '), hasLength(2 + 7));
    expect(fake.volume, 5);
    expect(cast, isEmpty);
  });

  test('setVolume via ADB at target sends nothing', () async {
    final r = await svc({TvCapability.adb}).setVolume(12);
    expect(r.ok, isTrue);
    expect(fake.writes, isEmpty);
  });

  test('setVolume clamps and falls back to Cast', () async {
    await svc({TvCapability.cast}, withAdb: false).setVolume(150);
    expect(cast, ['volume 100', 'disconnect']);
  });

  test('stopCurrentApp via ADB force-stops then Home', () async {
    fake.foreground = 'com.netflix.ninja';
    final r = await svc(all).stopCurrentApp();
    expect(r.via, ActionTransport.adb);
    expect(fake.writes, [
      'am force-stop com.netflix.ninja',
      'input keyevent KEYCODE_HOME',
    ]);
    expect(cast, isEmpty);
  });

  test('stopCurrentApp without ADB uses Cast', () async {
    final r = await svc({TvCapability.cast, TvCapability.dial}, withAdb: false)
        .stopCurrentApp();
    expect(r.via, ActionTransport.cast);
    expect(cast, ['stop', 'disconnect']);
  });

  test('stopCurrentApp falls back to DIAL', () async {
    final r = await svc({TvCapability.dial}, withAdb: false).stopCurrentApp();
    expect(r.via, ActionTransport.dial);
    expect(dial.kills, 1);
  });

  test('bore = stop + mute; break returns an expiry; restore unmutes',
      () async {
    fake.foreground = 'com.netflix.ninja';
    final s = svc({TvCapability.adb});
    final before = DateTime.now();
    final p = await s.startBreak(15);
    expect(p.ok, isTrue);
    expect(p.until!.difference(before).inMinutes, inInclusiveRange(14, 15));
    expect(fake.writes, [
      'am force-stop com.netflix.ninja',
      'input keyevent KEYCODE_HOME',
      'input keyevent KEYCODE_VOLUME_MUTE',
    ]);
    expect(fake.muted, isTrue);
    await s.restore();
    expect(fake.muted, isFalse);
  });

  test('no capabilities: nothing runs', () async {
    final r = await svc({}).bore();
    expect(r.ok, isFalse);
    expect(fake.log, isEmpty);
  });
}
