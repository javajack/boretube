import 'dart:convert';

import 'package:boretube_mobile/tv/tv.dart';
import 'package:boretube_mobile/tv/tv_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uuid = '4506a0af-4fcb-437e-993f-c16dad673aef';
const _serial = 'adb-qaezcxxq07001865';

Future<TvStore> _load([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return TvStore.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migration', () {
    test('old tv_config becomes an ip: TV and is active', () async {
      final store = await _load({
        'tv_config': jsonEncode({
          'ip': '192.168.1.3',
          'name': 'Sony BRAVIA',
          'dialPort': 8008,
          'castPort': 8009,
        }),
      });
      expect(store.tvs, hasLength(1));
      final tv = store.tvs.single;
      expect(tv.id, 'ip:192.168.1.3');
      expect(tv.name, 'Sony BRAVIA');
      expect(tv.ip, '192.168.1.3');
      expect(store.activeId, 'ip:192.168.1.3');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tvs_v2'), contains('ip:192.168.1.3'));
      expect(prefs.getString('active_tv_id'), 'ip:192.168.1.3');
    });

    test('runs only once (removed TVs stay removed)', () async {
      SharedPreferences.setMockInitialValues({
        'tv_config': jsonEncode({'ip': '192.168.1.3', 'name': ''}),
      });
      final first = await TvStore.load();
      expect(first.tvs.single.name, 'TV');
      await first.remove('ip:192.168.1.3');
      final second = await TvStore.load();
      expect(second.tvs, isEmpty);
      expect(second.activeId, isNull);
    });

    test('no old config → empty store', () async {
      final store = await _load();
      expect(store.tvs, isEmpty);
      expect(store.active, isNull);
    });

    test('corrupt tvs_v2 does not crash', () async {
      final store = await _load({'tvs_v2': '{nope'});
      expect(store.tvs, isEmpty);
    });
  });

  group('upsert', () {
    test('adds, persists and becomes active when none', () async {
      final store = await _load();
      var notified = 0;
      store.addListener(() => notified++);
      await store.upsert(const Tv(id: 'udn:a', name: 'A', ip: '10.0.0.2'));
      expect(store.activeId, 'udn:a');
      expect(notified, 1);
      final again = await TvStore.load();
      expect(again.tvs.single.name, 'A');
      expect(again.activeId, 'udn:a');
    });

    test('updates by id in place', () async {
      final store = await _load();
      await store.upsert(const Tv(id: 'udn:a', name: 'A', ip: '10.0.0.2'));
      await store.upsert(const Tv(id: 'udn:b', name: 'B', ip: '10.0.0.3'));
      await store.upsert(const Tv(id: 'udn:a', name: 'A', ip: '10.0.0.9'));
      expect(store.tvs.map((t) => '${t.id}@${t.ip}'),
          ['udn:a@10.0.0.9', 'udn:b@10.0.0.3']);
    });

    test('migrated ip: entry is replaced by the identified TV', () async {
      final store = await _load({
        'tv_config': jsonEncode({'ip': '192.168.1.3', 'name': 'Sony'}),
      });
      await store.upsert(const Tv(
        id: 'adb:$_serial',
        name: 'Living Room TV',
        ip: '192.168.1.3',
        adbSerial: _serial,
        udn: _uuid,
      ));
      expect(store.tvs.single.id, 'adb:$_serial');
      expect(store.activeId, 'adb:$_serial');
    });

    test('the saved id stays when the same TV shows up under another id',
        () async {
      // Everything else is keyed by the TV id (agent token, baselines,
      // restore points, plan state): a re-key orphans all of it.
      final checked = DateTime.utc(2026, 10, 1);
      final store = await _load();
      await store.upsert(Tv(
        id: 'udn:$_uuid',
        name: 'Living Room TV',
        model: 'BRAVIA VU3',
        ip: '192.168.1.3',
        udn: _uuid,
        capabilities: const {TvCapability.cast, TvCapability.dial},
        capabilitiesCheckedAt: checked,
      ));
      await store.upsert(const Tv(id: 'udn:x', name: 'Other', ip: '1.1.1.1'));
      // Later the TV is seen with its ADB serial at a new IP.
      await store.upsert(const Tv(
        id: 'adb:$_serial',
        name: 'Living Room TV',
        ip: '192.168.1.7',
        adbSerial: _serial,
        udn: _uuid,
      ));
      expect(store.tvs.map((t) => t.id), ['udn:$_uuid', 'udn:x']);
      final tv = store.byId('udn:$_uuid')!;
      expect(tv.ip, '192.168.1.7');
      expect(tv.adbSerial, _serial);
      expect(tv.model, 'BRAVIA VU3');
      expect(tv.capabilities, {TvCapability.cast, TvCapability.dial});
      expect(tv.capabilitiesCheckedAt, checked);
      expect(store.activeId, 'udn:$_uuid');
    });

    test('TV Guard announcing itself does not re-key the saved TV', () async {
      final store = await _load();
      await store.upsert(const Tv(
        id: 'adb:$_serial',
        name: 'Living Room TV',
        ip: '192.168.1.3',
        adbSerial: _serial,
        udn: _uuid,
      ));
      await store.upsert(const Tv(
        id: 'agent:b816a77435caf382',
        name: 'Living Room TV',
        ip: '192.168.1.3',
        adbSerial: _serial,
        udn: _uuid,
        agentPort: 8790,
      ));
      expect(store.tvs.single.id, 'adb:$_serial');
      expect(store.tvs.single.agentPort, 8790);
      expect(store.activeId, 'adb:$_serial');
    });

    test('a TV already re-keyed gets its old id back when data is under it',
        () async {
      // The 2026-10-29 bug: the TV moved to agent:…, its data stayed under
      // adb:<serial>.
      final store = await _load({
        'tvs_v2': jsonEncode([
          const Tv(
            id: 'agent:b816a77435caf382',
            name: 'Living Room TV',
            ip: '192.168.1.3',
            adbSerial: _serial,
          ).toJson(),
        ]),
        'active_tv_id': 'agent:b816a77435caf382',
        'baseline.adb:$_serial': '{}',
      });
      expect(store.tvs.single.id, 'adb:$_serial');
      expect(store.activeId, 'adb:$_serial');
      final again = await TvStore.load();
      expect(again.tvs.single.id, 'adb:$_serial');
    });

    test('no data under the old id: the id is left alone', () async {
      final store = await _load({
        'tvs_v2': jsonEncode([
          const Tv(
            id: 'agent:b816a77435caf382',
            name: 'Living Room TV',
            ip: '192.168.1.3',
            adbSerial: _serial,
          ).toJson(),
        ]),
      });
      expect(store.tvs.single.id, 'agent:b816a77435caf382');
    });
  });

  test('remove and setActive', () async {
    final store = await _load();
    await store.upsert(const Tv(id: 'udn:a', name: 'A', ip: '10.0.0.2'));
    await store.upsert(const Tv(id: 'udn:b', name: 'B', ip: '10.0.0.3'));
    await store.setActive('udn:b');
    expect(store.active!.name, 'B');
    await store.setActive('nope');
    expect(store.activeId, 'udn:b');
    await store.remove('udn:b');
    expect(store.activeId, 'udn:a');
    await store.remove('udn:a');
    expect(store.activeId, isNull);
    expect(store.tvs, isEmpty);
  });

  test('changes stream emits after each change', () async {
    final store = await _load();
    final got = <int>[];
    final sub = store.changes.listen((l) => got.add(l.length));
    await store.upsert(const Tv(id: 'udn:a', name: 'A', ip: '10.0.0.2'));
    await store.upsert(const Tv(id: 'udn:b', name: 'B', ip: '10.0.0.3'));
    await store.remove('udn:a');
    await pumpEventQueue();
    expect(got, [1, 2, 1]);
    await sub.cancel();
  });
}
