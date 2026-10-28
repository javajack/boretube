import 'package:boretube_mobile/ops/clean_wizard.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/clean_wizard_providers.dart';
import 'package:boretube_mobile/screens/tv/clean_tv.dart';
import 'package:boretube_mobile/screens/tv/clean_wizard.dart';
import 'package:boretube_mobile/ui/tubby.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../agent/fake_agent.dart' show fakeBundle;
import '../ops/fake_tv.dart';
import 'helpers.dart';
import 'structure.dart';

/// A VU3 with a few clean-up apps still showing, and a hand-wound clock.
class WizardRig {
  final FakeTv tv = FakeTv();
  DateTime now = DateTime(2026, 10, 29, 10);
  late final TvOps ops;
  final TestEnv env;

  /// What the "is the TV back?" probe answers, in order (last repeats).
  List<bool> back = [true];
  int backCalls = 0;
  bool? guard;

  WizardRig(this.env, {String profile = 'sony-bravia-vu3'}) {
    tv.disabled.removeAll(const [
      'com.sony.dtv.sonyselect',
      'com.sony.dtv.multiscreendemo',
      'com.android.adservices.api',
      'com.google.android.feedback',
      'com.sonyliv',
    ]);
    ops = TvOps(
      adb: tv,
      profile: loadProfile(profile),
      tvId: adbSony.id,
      journal: Journal(Future.value(env.prefs)),
      clock: () => now,
    );
  }

  static Future<WizardRig> create({
    String profile = 'sony-bravia-vu3',
    WizardProgress? progress,
  }) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    if (progress != null) {
      await WizardProgressStore(env.prefs).write(adbSony.id, progress);
    }
    return WizardRig(env, profile: profile);
  }

  List<Override> get overrides => [
        ...env.overrides(ops: ops),
        agentStatusProvider
            .overrideWith((ref) => AgentStatusNotifier.fixed(AgentLink.none)),
        agentBundleLoaderProvider.overrideWithValue(() async => fakeBundle()),
        wizardClockProvider.overrideWithValue(() => now),
        wizardProbesProvider.overrideWithValue(
          WizardProbes(
            tvBack: () async {
              final i = backCalls++;
              return back[i < back.length ? i : back.length - 1];
            },
            guardHealthy: () async => guard,
          ),
        ),
      ];

  WizardProgress? get saved => WizardProgressStore(env.prefs).read(adbSony.id);

  /// Moves the clock and the frames on together, a second at a time.
  Future<void> advance(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester);
  }
}

Future<void> pumpWizard(
  WidgetTester tester,
  WizardRig rig, {
  Size size = const Size(360, 1400),
}) async {
  await pumpScreen(
    tester,
    const CleanWizardScreen(),
    size: size,
    overrides: rig.overrides,
  );
  await settle(tester);
}

Future<void> tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

const sonyBatch = WizardBatch(
  group: 'sony',
  title: 'Sony promos',
  pkgs: ['com.sony.dtv.sonyselect', 'com.sony.dtv.multiscreendemo'],
);

void main() {
  testWidgets('restore point, then the grouped choice', (tester) async {
    final rig = await WizardRig.create();
    await pumpWizard(tester, rig);
    expect(find.byKey(const Key('wizard-restore')), findsOneWidget);
    expect(find.text('You can undo all of this anytime.'), findsOneWidget);
    expectCalmStructure(tester);
    await tap(tester, 'wizard-restore-save');
    expect(rig.tv.writes, isEmpty, reason: 'a restore point only reads');
    expect(rig.saved!.step, WizardStep.choose);

    expect(find.byKey(const Key('wizard-choose')), findsOneWidget);
    // "Sony promos" is both the group and an app in it.
    for (final g in ['Sony promos', 'Ads and tracking', 'Google leftovers']) {
      expect(find.text(g), findsWidgets);
    }
    expect(find.text('Optional apps'), findsOneWidget);
    // Plain names and one line each; already-off apps shown as done.
    expect(find.text('Sony Select'), findsOneWidget);
    expect(find.text('Sony\'s app store and its ads'), findsOneWidget);
    // Apps already off fold into one quiet row per group.
    expect(find.text('Already tidied away'), findsNothing);
    expect(find.text('Sony tab'), findsNothing);
    expect(find.text('5 already tidied away'), findsOneWidget);
    expect(find.text('3 already tidied away'), findsOneWidget);
    expect(find.text('6 already tidied away'), findsOneWidget);
    expect(find.text('2 already tidied away'), findsOneWidget);
    expect(find.text('Clean up · Step 2 of 4'), findsOneWidget);
    await tap(tester, 'wizard-done-sony');
    expect(find.byKey(const Key('wizard-done-sony-list')), findsOneWidget);
    expect(find.text('Sony tab'), findsOneWidget);
    await tap(tester, 'wizard-done-sony');
    expect(find.text('Sony tab'), findsNothing);
    // Optional apps start unticked: 4 core apps are on.
    expect(find.text('Tidy 4 apps'), findsOneWidget);
    // Never-touch packages are never offered.
    expect(find.text('Home (custom launcher)'), findsNothing);
    expectCalmStructure(tester);

    await tap(tester, 'wizard-pick-com.sonyliv');
    expect(find.text('Tidy 5 apps'), findsOneWidget);
    expect(rig.saved!.selected, contains('com.sonyliv'));
  });

  testWidgets('a batch end to end: off, save, restart, back, checks, done',
      (tester) async {
    final rig = await WizardRig.create(
      progress: const WizardProgress(step: WizardStep.choose),
    );
    rig.back = [false, true];
    await pumpWizard(tester, rig);
    // Just the Sony group.
    await tap(tester, 'wizard-pick-com.android.adservices.api');
    await tap(tester, 'wizard-pick-com.google.android.feedback');
    expect(find.text('Tidy 2 apps'), findsOneWidget);
    await tap(tester, 'wizard-start');

    expect(rig.tv.writes, [
      'pm disable-user --user 0 com.sony.dtv.sonyselect',
      'pm disable-user --user 0 com.sony.dtv.multiscreendemo',
    ]);
    expect(find.byKey(const Key('wizard-saving')), findsOneWidget);
    expect(find.text('Saving on the TV'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expectCalmStructure(tester);
    await rig.advance(tester, 30);
    expect(find.text('0:30'), findsOneWidget);
    expect(rig.saved!.phase, BatchPhase.saving);
    await rig.advance(tester, 30);

    expect(find.byKey(const Key('wizard-restart')), findsOneWidget);
    expect(find.byKey(const Key('wizard-skip-restart')), findsOneWidget);
    expectCalmStructure(tester);
    await tap(tester, 'wizard-restart-tv');
    expect(rig.tv.reboots, 1);
    expect(find.byKey(const Key('wizard-restarting')), findsOneWidget);
    expect(rig.saved!.phase, BatchPhase.restarting);
    expectCalmStructure(tester);
    // First look at 15 s: gone. Next at 20 s: back.
    await rig.advance(tester, 21);
    expect(rig.backCalls, 2);

    expect(find.byKey(const Key('wizard-checks-passed')), findsOneWidget);
    // One stable total for the run; the group is the sub-line.
    expect(find.text('Clean up · Step 3 of 4'), findsOneWidget);
    expect(find.text('Group 1 of 1 · Sony promos'), findsOneWidget);
    for (final id in ['appsOff', 'connected', 'home']) {
      expect(find.byKey(Key('wizard-check-$id')), findsOneWidget);
    }
    expect(find.byKey(const Key('wizard-check-guard')), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expectCalmStructure(tester);
    await tap(tester, 'wizard-next');

    expect(find.byKey(const Key('wizard-done')), findsOneWidget);
    expect(find.text('2 apps tidied away'), findsOneWidget);
    expectCalmStructure(tester);
    final ops = (await Journal(Future.value(rig.env.prefs)).entries(adbSony.id))
        .map((e) => e.op);
    expect(ops, ['disableApp', 'disableApp', 'restartTv', 'cleanWizard']);
    await tap(tester, 'wizard-finish');
    expect(rig.saved, isNull);
  });

  testWidgets('a failed check stops; undo puts the batch back', (tester) async {
    final rig = await WizardRig.create(
      progress: WizardProgress(
        step: WizardStep.batch,
        batches: const [sonyBatch],
        phase: BatchPhase.restart,
        phaseAt: DateTime(2026, 10, 29, 9),
      ),
    );
    rig.tv.disabled.addAll(sonyBatch.pkgs);
    await pumpWizard(tester, rig);
    await tap(tester, 'wizard-restart-tv');
    // The TV came back without one of the changes.
    rig.tv.disabled.remove('com.sony.dtv.sonyselect');
    rig.back = [false, true];
    await rig.advance(tester, 21);

    expect(find.byKey(const Key('wizard-checks-failed')), findsOneWidget);
    expect(find.text('1 app switched itself back on'), findsOneWidget);
    expect(find.text('Sony Select'), findsOneWidget);
    expect(find.text('Sony promos still off'), findsNothing);
    expect(
      tester.widget<Tubby>(find.byType(Tubby)).mood,
      TubbyMood.concerned,
    );
    expect(find.byKey(const Key('wizard-keep-going')), findsOneWidget);
    expectCalmStructure(tester);
    expect(rig.saved!.phase, BatchPhase.failed);

    rig.tv.ran.clear();
    await tap(tester, 'wizard-undo');
    expect(rig.tv.writes, ['pm enable com.sony.dtv.multiscreendemo']);
    expect(find.byKey(const Key('wizard-undone')), findsOneWidget);
    expectCalmStructure(tester);
    await tap(tester, 'wizard-next');
    expect(find.text('0 apps tidied away'), findsOneWidget);
    expect(find.text('Sony promos · put back'), findsOneWidget);
  });

  testWidgets('a whole group done is one quiet row', (tester) async {
    final rig = await WizardRig.create(
      progress: const WizardProgress(step: WizardStep.choose),
    );
    rig.tv.disabled.add('com.android.adservices.api');
    await pumpWizard(tester, rig);
    expect(
      find.descendant(
        of: find.byKey(const Key('wizard-done-ads')),
        matching: find.text('All tidied away'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('wizard-group-ads')), findsNothing);
    expect(find.byKey(const Key('wizard-done-ads')), findsOneWidget);
    expectCalmStructure(tester);
  });

  testWidgets('everything already off: Nothing to tidy, then Done',
      (tester) async {
    final clean = await WizardRig.create(
      progress: const WizardProgress(step: WizardStep.choose),
    );
    clean.tv.disabled.addAll(const [
      'com.sony.dtv.sonyselect',
      'com.sony.dtv.multiscreendemo',
      'com.android.adservices.api',
      'com.google.android.feedback',
      'com.sonyliv',
    ]);
    await pumpWizard(tester, clean);
    expect(find.byKey(const Key('wizard-all-tidy')), findsOneWidget);
    expect(find.text('Nothing to tidy'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expectCalmStructure(tester);
  });

  testWidgets('two apps back on reads in the plural', (tester) async {
    final rig = await WizardRig.create(
      progress: const WizardProgress(
        step: WizardStep.batch,
        batches: [sonyBatch, sonyBatch],
        current: 1,
        phase: BatchPhase.failed,
        checks: [
          WizardCheck(
            WizardCheckId.appsOff,
            ok: false,
            detail: 'Sony Select, Store demo',
            count: 2,
          ),
          WizardCheck(WizardCheckId.connected, ok: true),
          WizardCheck(WizardCheckId.home, ok: true),
        ],
      ),
    );
    await pumpWizard(tester, rig);
    expect(find.text('2 apps switched themselves back on'), findsOneWidget);
    expect(find.text('Sony Select, Store demo'), findsOneWidget);
    expect(find.text('Clean up · Step 3 of 4'), findsOneWidget);
    expect(find.text('Group 2 of 2 · Sony promos'), findsOneWidget);
  });

  testWidgets('Keep going after a failed check moves on', (tester) async {
    final rig = await WizardRig.create(
      progress: const WizardProgress(
        step: WizardStep.batch,
        batches: [sonyBatch],
        phase: BatchPhase.failed,
        checks: [
          WizardCheck(WizardCheckId.appsOff, ok: true),
          WizardCheck(WizardCheckId.connected, ok: true),
          WizardCheck(
            WizardCheckId.home,
            ok: false,
            detail: 'Home opens something else',
          ),
        ],
      ),
    );
    await pumpWizard(tester, rig);
    expect(find.text('Home opens something else'), findsOneWidget);
    await tap(tester, 'wizard-keep-going');
    expect(find.text('2 apps tidied away'), findsOneWidget);
    expect(rig.tv.writes, isEmpty);
  });

  testWidgets('resume mid-batch: back on the save with the time left',
      (tester) async {
    final rig = await WizardRig.create(
      progress: WizardProgress(
        step: WizardStep.batch,
        batches: const [sonyBatch],
        phase: BatchPhase.saving,
        phaseAt: DateTime(2026, 10, 29, 10).subtract(
          const Duration(seconds: 18),
        ),
      ),
    );
    await pumpWizard(tester, rig);
    expect(find.byKey(const Key('wizard-saving')), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('Clean up · Step 3 of 4'), findsOneWidget);
    expect(rig.tv.writes, isEmpty, reason: 'resume sends nothing new');
  });

  testWidgets('resume while restarting: no second reboot, waits, times out',
      (tester) async {
    final rig = await WizardRig.create(
      progress: WizardProgress(
        step: WizardStep.batch,
        batches: const [sonyBatch],
        phase: BatchPhase.restarting,
        phaseAt: DateTime(2026, 10, 29, 10),
      ),
    );
    rig.back = [false];
    await pumpWizard(tester, rig);
    expect(find.byKey(const Key('wizard-restarting')), findsOneWidget);
    await rig.advance(tester, 241);
    expect(find.byKey(const Key('wizard-restart-late')), findsOneWidget);
    expect(find.text('The TV is taking a while'), findsOneWidget);
    expect(rig.tv.reboots, 0);
    expectCalmStructure(tester);
    await tap(tester, 'wizard-keep-waiting');
    expect(find.byKey(const Key('wizard-restarting')), findsOneWidget);
  });

  testWidgets('other TVs: no tested list, a link to Apps on your TV',
      (tester) async {
    final rig = await WizardRig.create(profile: 'generic');
    await pumpWizard(tester, rig);
    expect(find.byKey(const Key('wizard-generic')), findsOneWidget);
    expect(find.text('No tested list for this TV yet'), findsOneWidget);
    expect(find.byKey(const Key('wizard-restore')), findsNothing);
    expectCalmStructure(tester);
    await tap(tester, 'wizard-open-apps');
    expect(find.text('Apps on your TV'), findsWidgets);
    expect(rig.tv.writes, isEmpty);
  });

  testWidgets('Clean TV keeps its one-tap Fix and opens the wizard',
      (tester) async {
    final rig = await WizardRig.create();
    await pumpScreen(
      tester,
      const CleanTvScreen(),
      size: const Size(360, 1900),
      overrides: rig.overrides,
    );
    await settle(tester);
    expect(find.byKey(const Key('clean-fix')), findsOneWidget);
    expectCalmStructure(tester);
    await tap(tester, 'clean-wizard');
    expect(find.byKey(const Key('wizard-restore')), findsOneWidget);
  });
}
