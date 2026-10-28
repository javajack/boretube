import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/adb_guide_screen.dart';
import 'package:boretube_mobile/tv/capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A prober whose developer port opens after [closedFor] checks.
CapabilityProber switchAfter(int closedFor, List<int> calls) =>
    CapabilityProber(
      adbProbe: (_, __, ___) async {
        calls.add(1);
        return calls.length > closedFor
            ? const ProbeOutcome(false, 'needs approval')
            : const ProbeOutcome(false, 'closed');
      },
    );

Future<void> pumpGuide(
  WidgetTester tester,
  TestEnv env, {
  CapabilityProber? prober,
}) async {
  await pumpScreen(
    tester,
    const AdbGuideScreen(),
    size: const Size(360, 1000),
    overrides: [
      ...env.overrides(prober: prober),
      helperPollIntervalProvider.overrideWithValue(
        const Duration(seconds: 1),
      ),
    ],
  );
  await settle(tester);
}

void main() {
  testWidgets('why → TV steps; moves on by itself once the switch is on',
      (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    final calls = <int>[];
    await pumpGuide(tester, env, prober: switchAfter(2, calls));

    expect(find.byKey(const Key('helper-why')), findsOneWidget);
    expect(find.text('We can put the TV back'), findsOneWidget);
    expect(find.byKey(const Key('helper-skip')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('helper-start')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('helper-start')));
    await settle(tester);

    expect(find.byKey(const Key('helper-open-about')), findsOneWidget);
    expect(find.text('DO THIS ON THE TV NOW'), findsOneWidget);
    expect(find.text('← here'), findsOneWidget);
    expect(find.byKey(const Key('helper-watching')), findsOneWidget);
    // Progress is saved per TV.
    expect(env.prefs.getInt(HelperProgress.keyFor(castOnlySony.id)), 1);

    // Two quiet checks find it closed; the third finds the switch on.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('helper-open-about')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester, 6);
    expect(find.byKey(const Key('helper-rehearse')), findsOneWidget);
    expect(find.byKey(const Key('helper-detected')), findsOneWidget);
    expect(find.text('Always allow from this computer'), findsOneWidget);
    expect(find.byKey(const Key('adb-connect')), findsOneWidget);
    expect(env.prefs.getInt(HelperProgress.keyFor(castOnlySony.id)), 4);
    // No more polling once it moved on.
    final n = calls.length;
    await tester.pump(const Duration(seconds: 3));
    expect(calls.length, n);
  });

  testWidgets('the 7 OK presses: a counter the parent taps, then onwards',
      (tester) async {
    final env = await TestEnv.create(
      tvs: [castOnlySony],
      prefs: {HelperProgress.keyFor(castOnlySony.id): 2},
    );
    await pumpGuide(tester, env, prober: switchAfter(1000, []));
    expect(find.byKey(const Key('helper-press-ok')), findsOneWidget);
    expect(find.text('0 of 7'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('helper-ok-counter')));
      await tester.pump();
    }
    expect(find.text('3 of 7'), findsOneWidget);
    expect(env.prefs.getInt(HelperProgress.presses(castOnlySony.id)), 3);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('helper-ok-counter')));
      await tester.pump();
    }
    expect(find.text('You\'re a developer!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await settle(tester, 4);
    expect(find.byKey(const Key('helper-debugging')), findsOneWidget);
  });

  testWidgets('"I don\'t see that" opens the troubleshooting sheet',
      (tester) async {
    final env = await TestEnv.create(
      tvs: [castOnlySony],
      prefs: {HelperProgress.keyFor(castOnlySony.id): 3},
    );
    await pumpGuide(tester, env, prober: switchAfter(1000, []));
    await tester.tap(find.byKey(const Key('helper-help')));
    await settle(tester);
    expect(find.byKey(const Key('helper-trouble')), findsOneWidget);
    expect(find.text('I can\'t find Developer options'), findsOneWidget);
  });
}
