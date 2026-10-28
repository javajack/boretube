import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/screens/home/home_tab.dart';
import 'package:boretube_mobile/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const playing = NowPlaying(
  online: true,
  id: 'org.smarttube.stable',
  appName: 'SmartTube',
  volume: 24,
  muted: false,
  source: 'adb',
);

const ok = ActionResult(true, ActionTransport.adb);

Finder ring(String tileKey) => find.descendant(
      of: find.byKey(Key(tileKey)),
      matching: find.byType(CircularProgressIndicator),
    );

Finder inTile(String tileKey, String text) => find.descendant(
      of: find.byKey(Key(tileKey)),
      matching: find.text(text),
    );

void main() {
  testWidgets('Mute flips at once; ring only if slow; no success feedback',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const HomeTab(),
      scaffold: true,
      overrides: env.overrides(now: playing, actions: actions),
    );
    await settle(tester);
    expect(inTile('action-mute', 'Quiet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('action-mute')));
    await tester.pump();

    // Before the TV answers: already muted everywhere.
    expect(actions.calls, ['mute']);
    expect(inTile('action-mute', 'Unmute'), findsOneWidget);
    expect(find.text('Muted'), findsOneWidget);
    // The ring only appears once the action has run for 1.5 s.
    expect(ring('action-mute'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(ring('action-mute'), findsOneWidget);
    // Unrelated tiles stay usable; conflicting ones wait.
    await tester.tap(find.byKey(const Key('action-stop')));
    await tester.pump();
    expect(actions.calls, ['mute', 'stop']);
    expect(find.text('Home screen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-more')));
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('action-bore')));
    await tester.pump();
    expect(actions.calls, ['mute', 'stop'], reason: 'bore conflicts');
    // The Pause button waits too (it touches sound and the app).
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const Key('action-break')))
          .onPressed,
      isNull,
    );

    actions.answer(ok);
    await tester.pump();
    actions.answer(ok);
    await tester.pump();
    // Let the ring cross-fade out.
    await tester.pump(const Duration(milliseconds: 250));
    expect(ring('action-mute'), findsNothing);
    expect(inTile('action-mute', 'Unmute'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('action-mute')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed action rolls back and says why', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const HomeTab(),
      scaffold: true,
      overrides: env.overrides(now: playing, actions: actions),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('action-mute')));
    await tester.pump();
    expect(inTile('action-mute', 'Unmute'), findsOneWidget);

    actions.answer(
      const ActionResult(false, ActionTransport.adb, detail: 'TV said no'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(inTile('action-mute', 'Quiet'), findsOneWidget);
    expect(ring('action-mute'), findsNothing);
    expect(find.text('Didn\'t work: TV said no'), findsOneWidget);
  });

  testWidgets('a failed Stop puts the app back on the hero card',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const HomeTab(),
      scaffold: true,
      overrides: env.overrides(now: playing, actions: actions),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-stop')));
    await tester.pump();
    expect(find.text('Home screen'), findsOneWidget);
    actions.answer(const ActionResult(false, ActionTransport.none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SmartTube'), findsOneWidget);
    expect(find.text('Didn\'t work: TV unreachable'), findsOneWidget);
  });

  group('Pause TV', () {
    final t0 = DateTime(2026, 10, 28, 19);

    testWidgets('chip + Pause: amber hero and countdown, at once',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      final actions = ScriptedActions();
      await pumpScreen(
        tester,
        const HomeTab(),
        scaffold: true,
        size: const Size(360, 1200),
        overrides: env.overrides(
          now: playing,
          actions: actions,
          clock: () => t0,
        ),
      );
      await settle(tester);
      // 30 minutes is the default choice.
      expect(
        tester.widget<BtChip>(find.byKey(const Key('pause-30'))).selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('pause-15')));
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('action-break')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(actions.calls, ['break 15']);
      expect(find.byKey(const Key('break-banner')), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('Home screen'), findsNothing, reason: 'hero swapped');
      expect(
        env.prefs.getString(BreakController.keyFor(adbSony.id)),
        t0.add(const Duration(minutes: 15)).toIso8601String(),
      );
      actions.answer(ok);
      await settle(tester);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('Keep this app open'), findsOneWidget);
    });

    testWidgets('resumes from prefs, counts down live, End break restores',
        (tester) async {
      var now = t0;
      final until = t0.add(const Duration(minutes: 12, seconds: 40));
      final env = await TestEnv.create(
        tvs: [adbSony],
        prefs: {
          BreakController.keyFor(adbSony.id): until.toIso8601String(),
        },
      );
      final actions = ScriptedActions();
      await pumpScreen(
        tester,
        const HomeTab(),
        scaffold: true,
        size: const Size(360, 1200),
        overrides: env.overrides(
          now: playing,
          actions: actions,
          clock: () => now,
        ),
      );
      await tester.pump();
      expect(find.text('12:40'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('12:39'), findsOneWidget);

      await tester.tap(find.byKey(const Key('break-end')));
      await tester.pump();
      expect(actions.calls, ['restore']);
      actions.answer(ok);
      await settle(tester);
      expect(find.byKey(const Key('break-banner')), findsNothing);
      expect(find.byKey(const Key('home-hero')), findsOneWidget);
      expect(
        env.prefs.getString(BreakController.keyFor(adbSony.id)),
        isNull,
      );
    });

    testWidgets('+15 min extends; a refusal keeps the break', (tester) async {
      var now = t0;
      final until = t0.add(const Duration(minutes: 10));
      final env = await TestEnv.create(
        tvs: [adbSony],
        prefs: {
          BreakController.keyFor(adbSony.id): until.toIso8601String(),
        },
      );
      final actions = ScriptedActions();
      await pumpScreen(
        tester,
        const HomeTab(),
        scaffold: true,
        size: const Size(360, 1200),
        overrides: env.overrides(
          now: playing,
          actions: actions,
          clock: () => now,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('break-extend')));
      await tester.pump();
      expect(actions.calls, ['break 25']);
      actions.answer(const ActionResult(false, ActionTransport.adb));
      await settle(tester);
      expect(find.text('10:00'), findsOneWidget, reason: 'kept as it was');

      await tester.tap(find.byKey(const Key('break-extend')));
      await tester.pump();
      actions.answer(ok);
      await settle(tester);
      expect(find.text('25:00'), findsOneWidget);
    });
  });
}
