import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/providers/nudges.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final now = DateTime(2026, 10, 29, 19);

const playing = NowPlaying(
  online: true,
  id: 'org.smarttube.stable',
  appName: 'SmartTube',
  volume: 24,
  muted: false,
  source: 'adb',
);

Map<String, Object> threeVolumeDowns() => {
      'nudge.log.volumeDown': [
        for (final d in [1, 2, 3])
          now.subtract(Duration(days: d)).toIso8601String(),
      ],
    };

void main() {
  Future<TestEnv> pumpHome(
    WidgetTester tester, {
    double textScale = 1,
    Map<String, Object> prefs = const {},
    List<Override> extra = const [],
  }) async {
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {...threeVolumeDowns(), ...prefs},
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
      textScale: textScale,
      size: const Size(360, 1400),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        agentStatusProvider.overrideWith(
          (ref) => AgentStatusNotifier.fixed(AgentLink.none),
        ),
        nudgeClockProvider.overrideWithValue(() => now),
        ...extra,
      ],
    );
    await settle(tester);
    return env;
  }

  testWidgets('a nudge sits at the top of Home; Do it goes there',
      (tester) async {
    final env = await pumpHome(tester);
    expect(find.byKey(const Key('home-nudge')), findsOneWidget);
    expect(find.text('Turning it down again?'), findsOneWidget);
    // Above the hero.
    expect(
      tester.getTopLeft(find.byKey(const Key('home-nudge'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('home-hero'))).dy),
    );

    await tester.tap(find.byKey(const Key('nudge-act')));
    await settle(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ShellScreen)),
    );
    expect(c.read(shellTabProvider), 1);
    expect(find.byKey(const Key('home-nudge')), findsNothing);
    expect(env.prefs.getBool(NudgeStore.doneKey(NudgeId.volumeLimit)), isTrue);
  });

  testWidgets('Not now hides it for 7 days and spends this open',
      (tester) async {
    final env = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('nudge-not-now')));
    await settle(tester);
    expect(find.byKey(const Key('home-nudge')), findsNothing);
    expect(env.prefs.getInt(NudgeStore.snoozesKey(NudgeId.volumeLimit)), 1);
    expect(
      DateTime.parse(
        env.prefs.getString(NudgeStore.untilKey(NudgeId.volumeLimit))!,
      ),
      now.add(const Duration(days: 7)),
    );
  });

  testWidgets('a snoozed nudge stays away', (tester) async {
    await pumpHome(
      tester,
      prefs: {
        NudgeStore.untilKey(NudgeId.volumeLimit):
            now.add(const Duration(days: 2)).toIso8601String(),
      },
    );
    expect(find.byKey(const Key('home-nudge')), findsNothing);
  });

  testWidgets('Home at 360 dp and 1.3× text: nothing overflows',
      (tester) async {
    await pumpHome(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('home-nudge')), findsOneWidget);
    expect(find.byKey(const Key('action-break')), findsOneWidget);
  });
}
