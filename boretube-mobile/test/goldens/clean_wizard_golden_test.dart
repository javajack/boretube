// The guided clean-up, light theme, on a 360×800 dp phone.
// Regenerate with: flutter test --update-goldens test/goldens
@Tags(['golden'])
library;

import 'package:boretube_mobile/ops/clean_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/clean_wizard_test.dart' show WizardRig, pumpWizard, tap;
import '../widget/helpers.dart';
import '../widget/structure.dart';

const _sony = WizardBatch(
  group: 'sony',
  title: 'Sony promos',
  pkgs: ['com.sony.dtv.sonyselect', 'com.sony.dtv.multiscreendemo'],
);
const _ads = WizardBatch(
  group: 'ads',
  title: 'Ads and tracking',
  pkgs: ['com.android.adservices.api'],
);

final _t0 = DateTime(2026, 10, 29, 10);

WizardProgress _batch(
  BatchPhase phase, {
  Duration ago = Duration.zero,
  List<WizardCheck> checks = const [],
}) =>
    WizardProgress(
      step: WizardStep.batch,
      batches: const [_sony, _ads],
      phase: phase,
      phaseAt: _t0.subtract(ago),
      checks: checks,
    );

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 8);
    // Every wizard screen keeps the calm structure: ≤ 2 raised surfaces,
    // ≤ 1 coral primary, no uppercase eyebrows.
    expectCalmStructure(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$name.png'),
    );
  }

  Future<WizardRig> open(
    WidgetTester tester,
    WizardProgress p, {
    List<bool> back = const [false],
  }) async {
    final rig = await WizardRig.create(progress: p);
    rig.back = back;
    // The batch's apps are off, as after a real run.
    rig.tv.disabled.addAll([..._sony.pkgs, ..._ads.pkgs]);
    await pumpWizard(tester, rig, size: const Size(360, 800));
    return rig;
  }

  testWidgets('Clean up · choose', (tester) async {
    final rig = await WizardRig.create(
      progress: const WizardProgress(step: WizardStep.choose),
    );
    // A mostly clean TV: one group is done already.
    rig.tv.disabled.add('com.android.adservices.api');
    await pumpWizard(tester, rig, size: const Size(360, 1150));
    await shot(tester, 'clean_wizard_choose_light');
  });

  testWidgets('Clean up · saving on the TV', (tester) async {
    await open(
      tester,
      _batch(BatchPhase.saving, ago: const Duration(seconds: 18)),
    );
    await shot(tester, 'clean_wizard_saving_light');
  });

  testWidgets('Clean up · restarting', (tester) async {
    await open(
      tester,
      _batch(BatchPhase.restarting, ago: const Duration(seconds: 72)),
    );
    await shot(tester, 'clean_wizard_restarting_light');
  });

  testWidgets('Clean up · checks passed', (tester) async {
    await open(tester, _batch(BatchPhase.restart), back: const [true]);
    await tap(tester, 'wizard-skip-restart');
    await shot(tester, 'clean_wizard_checks_pass_light');
  });

  testWidgets('Clean up · a check failed', (tester) async {
    await open(
      tester,
      _batch(
        BatchPhase.failed,
        checks: const [
          WizardCheck(
            WizardCheckId.appsOff,
            ok: false,
            detail: 'Sony Select',
            count: 1,
          ),
          WizardCheck(WizardCheckId.connected, ok: true),
          WizardCheck(WizardCheckId.home, ok: true),
        ],
      ),
    );
    await shot(tester, 'clean_wizard_checks_fail_light');
  });

  testWidgets('Clean up · done', (tester) async {
    await open(
      tester,
      const WizardProgress(
        step: WizardStep.done,
        batches: [_sony, _ads],
        kept: [0, 1],
      ),
    );
    await shot(tester, 'clean_wizard_done_light');
  });
}
