import 'package:boretube_mobile/ops/baseline.dart';
import 'package:boretube_mobile/ops/clean_wizard.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_tv.dart';

const sony = WizardBatch(
  group: 'sony',
  title: 'Sony promos',
  pkgs: ['com.sony.dtv.promos', 'com.sony.dtv.sonyselect'],
);
const ads = WizardBatch(
  group: 'ads',
  title: 'Ads and tracking',
  pkgs: ['com.android.adservices.api'],
);

void main() {
  final vu3 = loadProfile('sony-bravia-vu3');
  late FakeTv tv;
  late DateTime now;
  late TvOps ops;
  late Journal journal;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    journal = Journal(Future.value(prefs));
    tv = FakeTv();
    now = DateTime(2026, 10, 29, 10);
    ops = TvOps(
      adb: tv,
      profile: vu3,
      tvId: 'tv1',
      journal: journal,
      clock: () => now,
    );
  });

  group('restartTv', () {
    test('refuses within 60 s of a package write, then reboots', () async {
      tv.disabled.remove('com.sony.dtv.promos');
      await ops.setAppEnabled('com.sony.dtv.promos', false);
      expect(ops.lastPackageWrite, now);
      expect(
        ops.restartTv,
        throwsA(
          isA<RestartTooSoonException>().having(
            (e) => e.wait,
            'wait',
            const Duration(seconds: 60),
          ),
        ),
      );
      now = now.add(const Duration(seconds: 59));
      await expectLater(
        ops.restartTv(),
        throwsA(isA<RestartTooSoonException>()),
      );
      expect(tv.reboots, 0);
      now = now.add(const Duration(seconds: 1));
      final e = await ops.restartTv();
      expect(e.op, 'restartTv');
      expect(e.ok, isTrue);
      expect(tv.reboots, 1);
      final logged = await journal.entries('tv1');
      expect(logged.last.op, 'restartTv');
    });

    test('every package write resets the clock', () async {
      tv.disabled.removeAll(['com.sony.dtv.promos', 'com.sonyliv']);
      await ops.applyCleanup();
      now = now.add(const Duration(seconds: 50));
      await ops.setAppEnabled('com.sonyliv', false);
      now = now.add(const Duration(seconds: 30));
      expect(ops.restartWait, const Duration(seconds: 30));
      await expectLater(
        ops.restartTv(),
        throwsA(isA<RestartTooSoonException>()),
      );
    });

    test('with no writes it reboots at once; only `reboot` is written',
        () async {
      final e = await ops.restartTv();
      expect(e.after, 'restarting');
      expect(tv.writes, ['reboot']);
    });

    test('the connection dropping during the reboot counts as sent', () async {
      tv.dropOnReboot = true;
      final e = await ops.restartTv();
      expect(e.ok, isTrue);
      expect(e.after, contains('dropped'));
      expect(tv.reboots, 1);
    });

    test('an unreachable TV throws before anything is sent', () async {
      tv.unreachable = true;
      await expectLater(ops.restartTv(), throwsA(isA<StateError>()));
      expect(tv.reboots, 0);
    });

    test('read-only (generic) profile refuses', () async {
      final g = TvOps(adb: tv, profile: loadProfile('generic'), tvId: 'x');
      await expectLater(
        g.restartTv(),
        throwsA(isA<ReadOnlyProfileException>()),
      );
      expect(tv.reboots, 0);
    });
  });

  group('post-reboot checks', () {
    late PackageSnapshot snap;
    late LauncherHealth home;

    setUp(() async {
      snap = await ops.packages();
      home = await ops.launcherHealth();
    });

    test('all pass; no TV Guard row when it is not installed', () {
      final c = evaluateChecks(
        batch: sony,
        connected: true,
        packages: snap,
        launcher: home,
      );
      expect(c.map((c) => c.id), [
        WizardCheckId.appsOff,
        WizardCheckId.connected,
        WizardCheckId.home,
      ]);
      expect(checksPassed(c), isTrue);
    });

    test('an app back on fails and is named', () async {
      tv.disabled.remove('com.sony.dtv.sonyselect');
      final c = evaluateChecks(
        batch: sony,
        connected: true,
        packages: await ops.packages(),
        launcher: home,
        guardHealthy: true,
        label: (p) => p == 'com.sony.dtv.sonyselect' ? 'Sony Select' : p,
      );
      expect(checksPassed(c), isFalse);
      final apps = c.firstWhere((c) => c.id == WizardCheckId.appsOff);
      expect(apps.ok, isFalse);
      expect(apps.detail, 'Sony Select');
      expect(apps.count, 1);
      expect(c.last.id, WizardCheckId.guard);
      expect(c.last.ok, isTrue);
    });

    test('TV not back: nothing could be read, every row fails', () {
      final c = evaluateChecks(batch: sony, connected: false);
      expect(c.where((c) => c.ok), isEmpty);
    });

    test('Home resolving elsewhere fails; TV Guard down fails', () async {
      tv.a11y = 'null';
      final c = evaluateChecks(
        batch: sony,
        connected: true,
        packages: snap,
        launcher: await ops.launcherHealth(),
        guardHealthy: false,
      );
      expect(
        {for (final x in c) x.id: x.ok},
        {
          WizardCheckId.appsOff: true,
          WizardCheckId.connected: true,
          WizardCheckId.home: false,
          WizardCheckId.guard: false,
        },
      );
    });

    test('a TV that still answers right after reboot is not "back"', () {
      final t = ComebackTracker();
      expect(
        t.look(answered: true, sinceRestart: const Duration(seconds: 15)),
        isFalse,
      );
      expect(
        t.look(answered: false, sinceRestart: const Duration(seconds: 20)),
        isFalse,
      );
      expect(
        t.look(answered: true, sinceRestart: const Duration(seconds: 60)),
        isTrue,
      );
      // On resume nobody saw it go down: trusted after 90 s.
      expect(
        ComebackTracker().look(
          answered: true,
          sinceRestart: const Duration(seconds: 95),
        ),
        isTrue,
      );
    });
  });

  group('progress', () {
    test('round-trips through the store, per TV', () async {
      final store = WizardProgressStore(prefs);
      final p = WizardProgress(
        step: WizardStep.batch,
        selected: const {'com.sony.dtv.promos', 'com.android.adservices.api'},
        batches: const [sony, ads],
        current: 1,
        phase: BatchPhase.saving,
        phaseAt: now,
        kept: const [0],
        checks: const [
          WizardCheck(WizardCheckId.home, ok: false, detail: 'x'),
        ],
        undoResult: const {'a': true},
        restartSkipped: true,
      );
      await store.write('tv1', p);
      final back = store.read('tv1')!;
      expect(back.step, WizardStep.batch);
      expect(back.selected, p.selected);
      expect(back.batches.map((b) => b.title), [
        'Sony promos',
        'Ads and '
            'tracking'
      ]);
      expect(back.batches.first.pkgs, sony.pkgs);
      expect(back.current, 1);
      expect(back.phase, BatchPhase.saving);
      expect(back.phaseAt, now);
      expect(back.kept, [0]);
      expect(back.checks.single.id, WizardCheckId.home);
      expect(back.undoResult, {'a': true});
      expect(back.restartSkipped, isTrue);
      final fail = WizardCheck.fromJson(
        const WizardCheck(
          WizardCheckId.appsOff,
          ok: false,
          detail: 'A, B',
          count: 2,
        ).toJson(),
      )!;
      expect(fail.count, 2);
      expect(store.read('tv2'), isNull);
      await prefs.setString(WizardProgressStore.keyFor('tv2'), '{nope');
      expect(store.read('tv2'), isNull);
    });

    test('planBatches keeps group order and drops empty groups', () {
      final b = planBatches(
        const [sony, ads],
        {'com.sony.dtv.sonyselect'},
      );
      expect(b.single.group, 'sony');
      expect(b.single.pkgs, ['com.sony.dtv.sonyselect']);
    });
  });

  group('controller', () {
    CleanWizard wizard({WizardProbes? probes}) => CleanWizard(
          tvId: 'tv1',
          store: WizardProgressStore(prefs),
          ops: () async => ops,
          probes: probes ??
              WizardProbes(
                tvBack: () async => true,
                guardHealthy: () async => null,
              ),
          journal: journal,
          baselines: BaselineStore(prefs),
          clock: () => now,
        );

    test('restore point: captured fresh, and kept as the first baseline',
        () async {
      final w = wizard();
      await w.captureRestorePoint();
      expect(w.progress.step, WizardStep.choose);
      final store = WizardProgressStore(prefs);
      expect(store.restorePoint('tv1')!.profileId, vu3.id);
      expect(BaselineStore(prefs).read('tv1'), isNotNull);
      expect(store.read('tv1')!.step, WizardStep.choose);
      expect(tv.writes, isEmpty, reason: 'a restore point only reads');
      w.dispose();
    });

    test('a batch: each app off and verified, then the 60 s save', () async {
      tv.disabled.removeAll(sony.pkgs);
      final w = wizard();
      await w.start(const [sony, ads]);
      expect(tv.writes, [
        for (final p in sony.pkgs) 'pm disable-user --user 0 $p',
      ]);
      expect(w.live.values, everyElement(isTrue));
      expect(w.progress.phase, BatchPhase.saving);
      expect(w.progress.phaseAt, now);
      expect(w.saveLeft, const Duration(seconds: 60));
      final entries = await journal.entries('tv1');
      expect(entries.map((e) => e.op), ['disableApp', 'disableApp']);
      w.dispose();
    });

    test('resume mid-save picks up the time left', () async {
      await WizardProgressStore(prefs).write(
        'tv1',
        WizardProgress(
          step: WizardStep.batch,
          batches: const [sony],
          phase: BatchPhase.saving,
          phaseAt: now.subtract(const Duration(seconds: 20)),
        ),
      );
      final w = wizard();
      await w.resume();
      expect(w.progress.phase, BatchPhase.saving);
      expect(w.saveLeft, const Duration(seconds: 40));
      w.dispose();
    });

    test('resume after the save moves to the restart step', () async {
      await WizardProgressStore(prefs).write(
        'tv1',
        WizardProgress(
          step: WizardStep.batch,
          batches: const [sony],
          phase: BatchPhase.saving,
          phaseAt: now.subtract(const Duration(minutes: 5)),
        ),
      );
      final w = wizard();
      await w.resume();
      await Future<void>.delayed(Duration.zero);
      expect(w.progress.phase, BatchPhase.restart);
      w.dispose();
    });

    test('a restart refused as too soon goes back to saving', () async {
      tv.disabled.removeAll(sony.pkgs);
      final w = wizard();
      await w.start(const [sony]);
      // Pretend the screen skipped ahead.
      await WizardProgressStore(prefs).write(
        'tv1',
        w.progress.copyWith(phase: BatchPhase.restart),
      );
      w.progress = w.progress.copyWith(phase: BatchPhase.restart);
      now = now.add(const Duration(seconds: 25));
      await w.restart();
      expect(tv.reboots, 0);
      expect(w.progress.phase, BatchPhase.saving);
      expect(w.saveLeft, const Duration(seconds: 35));
      w.dispose();
    });

    test('undo re-enables exactly the batch\'s apps that are off', () async {
      // promos and sonyselect are off on the fixture TV; sonytab is on and
      // not in the batch.
      tv.disabled.remove('com.sony.dtv.sonytab');
      await WizardProgressStore(prefs).write(
        'tv1',
        const WizardProgress(
          step: WizardStep.batch,
          batches: [sony, ads],
          phase: BatchPhase.failed,
        ),
      );
      final w = wizard();
      expect(undoTargets(sony, await ops.packages()), sony.pkgs);
      await w.undoBatch();
      expect(tv.writes, [for (final p in sony.pkgs) 'pm enable $p']);
      expect(w.progress.phase, BatchPhase.undone);
      expect(w.progress.undoResult.values, everyElement(isTrue));
      expect(w.progress.undone, [0]);
      w.dispose();
    });

    test('skip restart runs the checks; finishing logs one summary', () async {
      await WizardProgressStore(prefs).write(
        'tv1',
        const WizardProgress(
          step: WizardStep.batch,
          batches: [sony],
          phase: BatchPhase.restart,
        ),
      );
      final w = wizard();
      await w.skipRestart();
      expect(w.checksDone, isTrue);
      expect(tv.reboots, 0);
      await w.next();
      expect(w.progress.step, WizardStep.done);
      expect(w.progress.tidiedCount, 2);
      await w.resume(); // reopening the done screen logs nothing more
      final summary =
          (await journal.entries('tv1')).where((e) => e.op == 'cleanWizard');
      expect(summary.single.target, '2');
      await w.finish();
      expect(WizardProgressStore(prefs).read('tv1'), isNull);
      w.dispose();
    });
  });
}
