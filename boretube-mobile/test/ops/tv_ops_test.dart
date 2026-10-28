import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_tv.dart';

void main() {
  final vu3 = loadProfile('sony-bravia-vu3');
  final generic = loadProfile('generic');
  late FakeTv tv;
  late TvOps ops;
  late Journal journal;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    journal = Journal();
    tv = FakeTv();
    ops = TvOps(
      adb: tv,
      profile: vu3,
      tvId: 'tv1',
      journal: journal,
      clock: () => DateTime.utc(2026, 10, 28, 12),
    );
  });

  group('parsers on real captures', () {
    test('package snapshot states', () async {
      final s = await ops.packages();
      expect(s.state('com.sony.dtv.promos'), AppState.disabled);
      expect(s.state('com.google.android.youtube.tv'), AppState.notInstalled);
      expect(s.state('com.netflix.ninja'), AppState.enabled);
      expect(s.state('com.example.none'), AppState.absent);
    });

    test('leanback activities', () {
      final m = TvOps.parseLeanbackActivities(fixture('query_leanback.txt'));
      expect(m, hasLength(10));
      expect(m['com.netflix.ninja'], 'com.netflix.ninja/.MainActivity');
      expect(
          m['com.sony.dtv.timers'],
          'com.sony.dtv.timers/.activity.'
          'TimersMainActivity');
      expect(m['com.gathin.tvhome'], 'com.gathin.tvhome/.MainActivity');
    });

    test('launcher health: HOME is launcherx but helper is on', () async {
      final h = await ops.launcherHealth();
      expect(
        h.homeComponent,
        'com.google.android.apps.tv.launcherx/.home.HomeActivity',
      );
      expect(h.homeIsLauncher, isFalse);
      expect(h.helperEnabled, isTrue);
      expect(h.a11yEnabled, isTrue);
      expect(h.ok, isTrue);
    });

    test('a11y list parsing and component normalization', () {
      expect(TvOps.parseA11yList('null'), isEmpty);
      expect(TvOps.parseA11yList(' a/.B:c/c.D '), ['a/.B', 'c/c.D']);
      expect(
        TvOps.normalizeComponent('com.gathin.tvhome/.HomeKeyService'),
        'com.gathin.tvhome/com.gathin.tvhome.HomeKeyService',
      );
    });

    test('volume from full dumpsys audio and grep excerpt', () {
      for (final f in ['dumpsys_audio.txt', 'dumpsys_audio_music.txt']) {
        final v = TvOps.parseVolume(fixture(f))!;
        expect(v.level, 12);
        expect(v.max, 100);
        expect(v.min, 0);
        expect(v.muted, isFalse);
        expect(v.percent, 12);
      }
      expect(TvOps.parseVolume('nothing'), isNull);
    });

    test('foreground package', () {
      expect(
        TvOps.parseTopResumed(fixture('top_resumed.txt')),
        'org.smarttube.stable',
      );
      expect(TvOps.parseTopResumed(''), isNull);
    });

    test('package version', () {
      final tts = TvOps.parsePackageVersion(
        fixture('dumpsys_package_tts.txt'),
      )!;
      expect(
        tts.versionName,
        'googletts.google-speech-apk_20251028.02_p2.827711934',
      );
      expect(tts.updatedSystemApp, isFalse);
      expect(tts.installedForUser0, isTrue);
      final yt = TvOps.parsePackageVersion(
        fixture('dumpsys_package_youtube.txt'),
      )!;
      expect(yt.versionName, '7.27.302');
      expect(yt.updatedSystemApp, isTrue);
      expect(yt.installedForUser0, isFalse);
      expect(TvOps.parsePackageVersion('Unable to find package: x'), isNull);
    });
  });

  group('guards', () {
    test('refuses neverTouch packages before sending anything', () async {
      for (final p in [
        'com.google.android.apps.tv.launcherx',
        'com.gathin.tvhome',
        'com.google.android.tts',
        'com.android.vending',
      ]) {
        await expectLater(
          ops.setAppEnabled(p, false),
          throwsA(isA<NeverTouchException>()),
        );
        await expectLater(
          ops.stopApp(p),
          throwsA(isA<NeverTouchException>()),
        );
      }
      expect(tv.writes, isEmpty);
    });

    test('baseline list applies even if the profile forgets it', () async {
      final o = TvOps(
          adb: tv, profile: generic, tvId: 't', maintenanceUnlocked: true);
      await expectLater(
        o.setAppEnabled('com.rakesh.boretube.agent', false),
        throwsA(isA<NeverTouchException>()),
      );
    });

    test('rejects shell-unsafe package names', () async {
      for (final p in ['a;reboot', r'a$(x)', 'a b', "a'", '']) {
        await expectLater(
          ops.setAppEnabled(p, false),
          throwsA(isA<InvalidPackageException>()),
        );
      }
      expect(tv.log, isEmpty);
    });

    test('generic profile is read-only until unlocked', () async {
      final o = TvOps(adb: tv, profile: generic, tvId: 't');
      await expectLater(
        o.setAppEnabled('com.netflix.ninja', false),
        throwsA(isA<ReadOnlyProfileException>()),
      );
      await expectLater(
        o.stockYouTube(false),
        throwsA(isA<ReadOnlyProfileException>()),
      );
      // Instant actions still work.
      await o.volumeStep(up: true);
      expect(tv.volume, 13);
    });

    test('cleanup with a profile-unknown extra is refused', () async {
      expect(
        () => ops.applyCleanup(extras: {'com.netflix.ninja'}),
        throwsArgumentError,
      );
    });
  });

  group('writes', () {
    test('setAppEnabled sends the exact command, verifies, journals', () async {
      final e = await ops.setAppEnabled('com.netflix.ninja', false);
      expect(tv.writes, ['pm disable-user --user 0 com.netflix.ninja']);
      expect(e.ok, isTrue);
      expect(e.before, 'enabled');
      expect(e.after, 'disabled');
      expect(e.undoCommand, 'pm enable com.netflix.ninja');
      final saved = await journal.entries('tv1');
      expect(saved.single.op, 'disableApp');
      expect(saved.single.time, DateTime.utc(2026, 10, 28, 12));
    });

    test('a write the TV ignores is journaled as not ok', () async {
      tv.failing.add('pm disable-user');
      final e = await ops.setAppEnabled('com.netflix.ninja', false);
      expect(e.ok, isFalse);
      expect(e.after, 'enabled');
    });

    test('stopApp force-stops', () async {
      tv.running['com.netflix.ninja'] = 42;
      final e = await ops.stopApp('com.netflix.ninja');
      expect(tv.writes, ['am force-stop com.netflix.ninja']);
      expect(e.before, 'pid 42');
      expect(e.after, 'not running');
      expect(e.ok, isTrue);
    });

    test('stopForegroundApp: protected app only gets Home', () async {
      final s = await ops.stopForegroundApp();
      expect(s.pkg, 'org.smarttube.stable');
      expect(s.forceStopped, isFalse);
      expect(s.sentHome, isTrue);
      expect(tv.writes, ['input keyevent KEYCODE_HOME']);
    });

    test('stopForegroundApp: normal app is force-stopped then Home', () async {
      tv.foreground = 'com.netflix.ninja';
      tv.running['com.netflix.ninja'] = 7;
      final s = await ops.stopForegroundApp();
      expect(s.forceStopped, isTrue);
      expect(tv.writes, [
        'am force-stop com.netflix.ninja',
        'input keyevent KEYCODE_HOME',
      ]);
    });

    test('stopForegroundApp: on the launcher does nothing', () async {
      tv.foreground = 'com.gathin.tvhome';
      final s = await ops.stopForegroundApp();
      expect(s.sentHome, isFalse);
      expect(tv.writes, isEmpty);
    });

    test('stockYouTube on: install-existing + enable companion', () async {
      tv.disabled.add('com.google.android.youtube.tvmusic');
      final es = await ops.stockYouTube(true);
      expect(tv.writes, [
        'cmd package install-existing com.google.android.youtube.tv',
        'pm enable com.google.android.youtube.tvmusic',
      ]);
      expect(es.map((e) => e.ok), [true, true]);
      expect(es.first.undoCommand,
          'pm uninstall -k --user 0 com.google.android.youtube.tv');
    });

    test('stockYouTube off: uninstall -k + disable companion', () async {
      tv.installed.add('com.google.android.youtube.tv');
      tv.disabled.remove('com.google.android.youtube.tvmusic');
      final es = await ops.stockYouTube(false);
      expect(tv.writes, [
        'pm uninstall -k --user 0 com.google.android.youtube.tv',
        'pm disable-user --user 0 com.google.android.youtube.tvmusic',
      ]);
      expect(es.every((e) => e.ok), isTrue);
      expect(await ops.stockYouTubeState(), AppState.notInstalled);
    });

    test('applyCleanup disables only what is still enabled', () async {
      // On the real TV everything is already done.
      expect(await ops.applyCleanup(), isEmpty);
      expect(tv.writes, isEmpty);
      final st = await ops.cleanupStatus();
      expect(st.present, hasLength(18));
      expect(st.disabled, hasLength(18));
      expect(st.complete, isTrue);

      tv.disabled.removeAll(['com.sony.dtv.promos', 'com.android.gallery3d']);
      final es = await ops.applyCleanup();
      expect(tv.writes, [
        'pm disable-user --user 0 com.sony.dtv.promos',
        'pm disable-user --user 0 com.android.gallery3d',
      ]);
      expect(es.every((e) => e.ok && e.after == 'disabled'), isTrue);
    });

    test('extras are opt-in', () async {
      tv.disabled.remove('com.sonyliv');
      expect(await ops.applyCleanup(), isEmpty);
      final es = await ops.applyCleanup(extras: {'com.sonyliv'});
      expect(es.single.target, 'com.sonyliv');
    });

    test('undoCleanup enables each disabled cleanup package', () async {
      final es = await ops.undoCleanup();
      expect(es, hasLength(18));
      expect(tv.writes.first, 'pm enable com.sony.dtv.promos');
      expect(tv.writes.every((w) => w.startsWith('pm enable ')), isTrue);
      expect(tv.disabled, contains('com.sonyliv'));
      expect(await journal.entries('tv1'), hasLength(18));
    });
  });

  group('speech rollback', () {
    test('not needed when at the known-good factory build', () async {
      final d = await ops.speechDecision();
      expect(d.needed, isFalse);
      expect(d.atKnownGood, isTrue);
      expect(await ops.speechRollback(), isNull);
      expect(tv.writes, isEmpty);
    });

    test('needed when an update replaced the known-good build', () async {
      tv.dumpsys['com.google.android.tts'] = FakeTv.updatedTtsDump();
      final d = await ops.speechDecision();
      expect(d.needed, isTrue);
      final e = await ops.speechRollback();
      expect(tv.writes, [
        'pm uninstall-system-updates com.google.android.tts',
      ]);
      expect(e!.ok, isTrue);
      expect(e.before, contains('20260901'));
      expect(e.after, contains('20251028'));
    });

    test('different version but not an update: no rollback', () {
      final d = TvOps.decideSpeechRollback(
        const PackageVersion(versionName: 'old', updatedSystemApp: false),
        'good',
      );
      expect(d.needed, isFalse);
      expect(d.atKnownGood, isFalse);
    });
  });

  group('launcher fix', () {
    test('no-op when the helper is already on', () async {
      final e = await ops.fixLauncher();
      expect(e.ok, isTrue);
      expect(tv.writes, isEmpty);
    });

    test('re-puts the list preserving existing entries', () async {
      tv.a11y = 'com.foo/.Talk';
      tv.a11yEnabled = '0';
      final e = await ops.fixLauncher();
      expect(tv.writes, [
        "settings put secure enabled_accessibility_services "
            "'com.foo/.Talk:com.gathin.tvhome/.HomeKeyService' && "
            'settings put secure accessibility_enabled 1',
      ]);
      expect(e.ok, isTrue);
      expect(e.undoCommand,
          "settings put secure enabled_accessibility_services 'com.foo/.Talk'");
    });

    test('empty (null) list', () async {
      tv.a11y = 'null';
      final e = await ops.fixLauncher();
      expect(tv.a11y, 'com.gathin.tvhome/.HomeKeyService');
      expect(e.undoCommand,
          'settings delete secure enabled_accessibility_services');
    });
  });

  group('apps', () {
    test('listApps merges launchable, disabled and removed apps', () async {
      final apps = {for (final a in await ops.listApps()) a.pkg: a};
      expect(apps['com.netflix.ninja']!.state, AppState.enabled);
      expect(apps['com.netflix.ninja']!.launchable, isTrue);
      expect(apps['com.netflix.ninja']!.protected, isFalse);
      expect(apps['com.sonyliv']!.state, AppState.disabled);
      expect(
          apps['com.google.android.youtube.tv']!.state, AppState.notInstalled);
      expect(apps['org.smarttube.stable']!.protected, isTrue);
      expect(apps['com.android.tv.settings']!.protected, isTrue);
      expect(tv.writes, isEmpty);
    });
  });

  group('volume', () {
    test('volumeStep sends n key events in one command', () async {
      final e = await ops.volumeStep(up: false, n: 3);
      expect(tv.writes, [
        'input keyevent KEYCODE_VOLUME_DOWN KEYCODE_VOLUME_DOWN '
            'KEYCODE_VOLUME_DOWN',
      ]);
      expect(tv.volume, 9);
      expect(e.ok, isTrue);
      expect(e.before, '12/100');
      expect(e.after, '9/100');
    });

    test('volumeStep caps at 100 presses', () async {
      await ops.volumeStep(up: true, n: 500);
      expect(' '.allMatches(tv.writes.single).length, 101);
    });

    test('setMuted toggles only when needed', () async {
      expect((await ops.setMuted(true))!.ok, isTrue);
      expect(tv.muted, isTrue);
      expect(await ops.setMuted(true), isNull);
      expect(tv.writes, ['input keyevent KEYCODE_VOLUME_MUTE']);
    });

    test('mute not reflected in dumpsys is reported', () async {
      tv.muteReflected = false;
      final e = await ops.toggleMute();
      expect(e.ok, isFalse);
    });
  });
}
