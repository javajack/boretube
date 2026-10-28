import 'package:boretube_mobile/discovery/discovery_service.dart';
import 'package:boretube_mobile/discovery/subnet_sweep.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:boretube_mobile/tv/tv_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ops/fake_tv.dart';

class _Moved extends DiscoveryService {
  final Tv? result;
  _Moved(this.result) : super(enableSweep: false);

  @override
  Stream<List<Tv>> discover({
    Duration timeout = const Duration(seconds: 10),
    void Function(SweepEvent event)? onSweepProgress,
  }) =>
      const Stream.empty();

  @override
  Future<Tv?> relocate(
    Tv saved, {
    Duration timeout = const Duration(seconds: 10),
    Duration quickTimeout = const Duration(milliseconds: 1500),
  }) async =>
      result;
}

void main() {
  test('readNowPlaying over ADB names the app and reads volume', () async {
    final tv = FakeTv()
      ..foreground = 'org.smarttube.stable'
      ..volume = 30;
    final ops = TvOps(
      adb: tv,
      profile: loadProfile('sony-bravia-vu3'),
      tvId: 't',
    );
    final now = await readNowPlaying(ops: ops);
    expect(now!.online, isTrue);
    expect(now.appName, 'SmartTube');
    expect(now.volume, 30);
    expect(now.source, 'adb');
    expect(tv.writes, isEmpty, reason: 'polling must only read');
  });

  test('home launcher reads as Home screen', () async {
    final tv = FakeTv()..foreground = 'com.google.android.apps.tv.launcherx';
    final ops = TvOps(
      adb: tv,
      profile: loadProfile('sony-bravia-vu3'),
      tvId: 't',
    );
    final now = await readNowPlaying(ops: ops);
    expect(now!.isHome, isTrue);
    expect(now.appName, 'Home screen');
  });

  test('appLabel', () {
    expect(appLabel('com.netflix.ninja'), 'Netflix');
    expect(appLabel('com.example.coolapp'), 'Coolapp');
    expect(appLabel('com.example.player.tv'), 'Player');
  });

  test('two failed polls trigger relocation once', () async {
    var calls = 0;
    var n = 0;
    final notifier = NowPlayingNotifier(
      fetch: () async => n++ == 0 ? const NowPlaying(online: true) : null,
      interval: const Duration(days: 1),
      active: false,
      onUnreachable: () => calls++,
    );
    await notifier.refresh();
    expect(notifier.state.online, isTrue);
    await notifier.refresh();
    await notifier.refresh();
    await notifier.refresh();
    expect(notifier.state.online, isFalse);
    expect(calls, 1);
    notifier.dispose();
  });

  group('Relocator', () {
    late TvStore store;
    const saved = Tv(
      id: 'udn:abc',
      name: 'Living Room TV',
      ip: '192.168.1.3',
      udn: 'abc',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await TvStore.load(prefs: await SharedPreferences.getInstance());
      await store.upsert(saved);
    });

    test('moves the TV and says where', () async {
      final messages = <String>[];
      final r = Relocator(
        store: store,
        discovery: _Moved(saved.copyWith(ip: '192.168.1.7')),
        notify: messages.add,
      );
      await r.relocateActive();
      expect(store.active!.ip, '192.168.1.7');
      expect(store.tvs, hasLength(1));
      expect(messages, ['Living Room TV moved to .7']);
    });

    test('a temporary ip: id is replaced, not duplicated', () async {
      SharedPreferences.setMockInitialValues({});
      store = await TvStore.load(prefs: await SharedPreferences.getInstance());
      const temp = Tv(id: 'ip:192.168.1.3', name: 'TV', ip: '192.168.1.3');
      await store.upsert(temp);
      final r = Relocator(
        store: store,
        discovery: _Moved(
          temp.copyWith(id: 'udn:new', ip: '192.168.1.8', udn: 'new'),
        ),
        notify: (_) {},
      );
      await r.relocateActive();
      expect(store.tvs.map((t) => t.id), ['udn:new']);
      expect(store.activeId, 'udn:new');
    });

    test('not found: nothing changes', () async {
      final messages = <String>[];
      await Relocator(
        store: store,
        discovery: _Moved(null),
        notify: messages.add,
      ).relocateActive();
      expect(store.active!.ip, '192.168.1.3');
      expect(messages, isEmpty);
    });
  });
}
