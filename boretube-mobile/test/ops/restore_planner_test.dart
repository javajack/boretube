import 'package:boretube_mobile/agent/agent_models.dart';
import 'package:boretube_mobile/ops/baseline.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/ops/restore_planner.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_tv.dart';

void main() {
  final vu3 = loadProfile('sony-bravia-vu3');
  late FakeTv tv;
  late TvOps ops;
  late Journal journal;
  final t0 = DateTime(2026, 10, 28, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    journal = Journal();
    tv = FakeTv();
    ops = TvOps(
      adb: tv,
      profile: vu3,
      tvId: 'tv1',
      journal: journal,
      clock: () => t0,
    );
  });

  void installAgent() {
    tv.all.add(kAgentPackage);
    tv.installed.add(kAgentPackage);
  }

  JournalEntry entry(String op, String target, {int min = 0, bool ok = true}) =>
      JournalEntry(
        tvId: 'tv1',
        time: t0.add(Duration(minutes: min)),
        op: op,
        target: target,
        before: '',
        after: '',
        ok: ok,
      );

  Future<RestorePlan> plan(
    RestoreTarget target, {
    List<JournalEntry> history = const [],
    TvBaseline? baseline,
    bool helper = false,
  }) async =>
      RestorePlanner.plan(
        target: target,
        profile: vu3,
        packages: await ops.packages(),
        launcher: await ops.launcherHealth(),
        journal: history,
        baseline: baseline,
        removeLauncherHelper: helper,
      );

  group('stock', () {
    test('exact commands on the debloated VU3', () async {
      installAgent();
      final p = await plan(RestoreTarget.stock);
      expect(p.commands, [
        'pm uninstall com.rakesh.boretube.agent',
        for (final c in vu3.cleanup) 'pm enable ${c.pkg}',
        'pm enable com.sonyliv',
        'pm enable com.amazon.amazonvideo.livingroom',
        'pm enable com.apple.atve.androidtv.appletv',
        'cmd package install-existing com.google.android.youtube.tv',
        'pm enable com.google.android.youtube.tvmusic',
      ]);
      expect(p.steps.first.kind, RestoreStepKind.uninstallAgent);
      expect(
        p.steps.where((s) => s.kind == RestoreStepKind.note),
        hasLength(2),
      );
    });

    test('launcher helper removal keeps other services', () async {
      tv.a11y = 'com.google.android.marvin.talkback/.TalkBackService:'
          'com.gathin.tvhome/com.gathin.tvhome.HomeKeyService';
      final p = await plan(RestoreTarget.stock, helper: true);
      expect(
        p.commands.last,
        "settings put secure enabled_accessibility_services "
        "'com.google.android.marvin.talkback/.TalkBackService'",
      );
      // HOME already resolves to launcherx on the VU3: no set-home step.
      expect(
        p.steps.any((s) => s.kind == RestoreStepKind.setHome),
        isFalse,
      );
    });

    test('helper as the only service: list deleted, a11y off', () async {
      final p = await plan(RestoreTarget.stock, helper: true);
      expect(
        p.commands.last,
        'settings delete secure enabled_accessibility_services && '
        'settings put secure accessibility_enabled 0',
      );
    });

    test('HOME on the custom launcher goes back to Google TV', () async {
      tv.home = 'x\ncom.gathin.tvhome/.MainActivity\n';
      final p = await plan(RestoreTarget.stock, helper: true);
      expect(
        p.commands.last,
        'cmd package set-home-activity $kStockHome',
      );
    });

    test('nothing touches the never-touch list', () async {
      // Even if never-touch packages are disabled, stock leaves them.
      for (final p in vu3.neverTouch) {
        if (tv.installed.contains(p)) tv.disabled.add(p);
      }
      final p = await plan(RestoreTarget.stock, helper: true);
      for (final s in p.actions) {
        if (s.kind == RestoreStepKind.uninstallAgent) continue;
        if (s.kind == RestoreStepKind.removeLauncherHelper) continue;
        expect(vu3.neverTouch.contains(s.pkg), isFalse, reason: s.command);
      }
      expect(p.commands.any((c) => c.contains('setupwraith')), isFalse);
      expect(p.commands.any((c) => c.contains('launcherx')), isFalse);
      expect(p.commands.any((c) => c.contains('dreamx')), isFalse);
    });

    test('already stock → nothing to run', () async {
      tv.disabled.clear();
      tv.installed.add('com.google.android.youtube.tv');
      final p = await plan(RestoreTarget.stock);
      expect(p.isEmpty, isTrue);
    });
  });

  group('undoBoretube', () {
    test('reverses only boretube\'s journaled changes', () async {
      installAgent();
      final p = await plan(
        RestoreTarget.undoBoretube,
        history: [
          entry('applyCleanup', 'com.sony.dtv.promos'),
          entry('applyCleanup', 'com.sonyliv', min: 1),
          entry('undoCleanup', 'com.sonyliv', min: 2),
          entry('disableApp', 'com.google.android.youtube.tvmusic', min: 3),
          entry('disableApp', 'com.sony.dtv.sonytab', ok: false),
          entry('stockYouTubeOff', 'com.google.android.youtube.tv', min: 4),
          entry('disableApp', 'com.google.android.tungsten.setupwraith'),
        ],
      );
      expect(p.commands, [
        'pm uninstall com.rakesh.boretube.agent',
        'pm enable com.sony.dtv.promos',
        'pm enable com.google.android.youtube.tvmusic',
        'cmd package install-existing com.google.android.youtube.tv',
      ]);
    });

    test('YouTube put back later is not reinstalled', () async {
      final p = await plan(
        RestoreTarget.undoBoretube,
        history: [
          entry('stockYouTubeOff', 'com.google.android.youtube.tv'),
          entry('stockYouTubeOn', 'com.google.android.youtube.tv', min: 1),
        ],
      );
      expect(p.commands, isEmpty);
    });

    test('baseline catches changes made while the journal was away', () async {
      final baseline = TvBaseline(
        tvId: 'tv1',
        capturedAt: t0,
        buildFingerprint: 'fp',
        // Everything the fixture disables except promos was off already.
        disabled: [
          for (final p in tv.disabled)
            if (p != 'com.sony.dtv.promos') p,
        ],
        stockYouTube: 'enabled',
      );
      final p = await plan(RestoreTarget.undoBoretube, baseline: baseline);
      expect(p.commands, [
        'pm enable com.sony.dtv.promos',
        'cmd package install-existing com.google.android.youtube.tv',
      ]);
    });

    test('with no journal and no baseline, only the agent goes', () async {
      installAgent();
      final p = await plan(RestoreTarget.undoBoretube);
      expect(p.commands, ['pm uninstall com.rakesh.boretube.agent']);
    });
  });

  group('runner', () {
    test('runs, verifies and journals every step', () async {
      installAgent();
      await journal.add(entry('applyCleanup', 'com.sony.dtv.promos'));
      await journal.add(
        entry('stockYouTubeOff', 'com.google.android.youtube.tv', min: 1),
      );
      final runner = RestoreRunner(ops, journal: journal, clock: () => t0);
      final p = await runner.plan(RestoreTarget.undoBoretube);
      final seen = <int>[];
      final results = await runner.run(p, onStep: (i, _) => seen.add(i));
      expect(seen, [0, 1, 2]);
      expect(results.every((r) => r.ok), isTrue);
      expect(tv.installed.contains(kAgentPackage), isFalse);
      expect(tv.disabled.contains('com.sony.dtv.promos'), isFalse);
      expect(tv.installed.contains('com.google.android.youtube.tv'), isTrue);
      final logged = (await journal.entries('tv1'))
          .where((e) => e.op == 'restore')
          .toList();
      expect(logged, hasLength(3));
      expect(logged[1].before, 'disabled');
      expect(logged[1].after, 'enabled');
    });

    test('a failing step is reported and the rest continue', () async {
      tv.failing.add('pm enable com.sony.dtv.promos');
      final runner = RestoreRunner(ops, journal: journal);
      final p = await runner.plan(RestoreTarget.stock);
      final results = await runner.run(p);
      final bad = results.where((r) => !r.ok).toList();
      expect(bad.single.step.pkg, 'com.sony.dtv.promos');
      expect(results.length, p.actions.length);
      expect(tv.disabled.contains('com.sony.dtv.sonytab'), isFalse);
    });

    test('helper removal is verified', () async {
      final runner = RestoreRunner(ops, journal: journal);
      final p = await runner.plan(
        RestoreTarget.stock,
        removeLauncherHelper: true,
      );
      final results = await runner.run(p);
      expect(results.last.step.kind, RestoreStepKind.removeLauncherHelper);
      expect(results.last.ok, isTrue);
      expect(tv.a11yEnabled, '0');
    });
  });

  group('baseline', () {
    test('captures read-only and round-trips', () async {
      final store = BaselineStore(await SharedPreferences.getInstance());
      final b = await store.captureIfMissing(ops, clock: () => t0);
      expect(tv.writes, isEmpty);
      expect(b.buildFingerprint, startsWith('Sony/BRAVIA_VU3'));
      expect(b.disabled, contains('com.sony.dtv.promos'));
      expect(b.uninstalled, contains('com.google.android.youtube.tv'));
      expect(b.stockYouTube, 'notInstalled');
      expect(b.ttsVersion, contains('20251028'));
      expect(b.a11yServices, ['com.gathin.tvhome/.HomeKeyService']);
      expect(b.a11yEnabled, isTrue);
      expect(b.home, kStockHome);
      expect(b.agentInstalled, isFalse);
      final back = store.read('tv1')!;
      expect(back.toJson(), b.toJson());
      expect(back.export(), contains('"buildFingerprint"'));
    });

    test('first baseline is kept', () async {
      final store = BaselineStore(await SharedPreferences.getInstance());
      await store.captureIfMissing(ops, clock: () => t0);
      tv.fingerprint = 'changed';
      final again = await store.captureIfMissing(ops);
      expect(again.buildFingerprint, isNot('changed'));
      expect(again.capturedAt, t0);
    });
  });
}
