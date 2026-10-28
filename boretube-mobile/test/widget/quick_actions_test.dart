import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/screens/now/now_tab.dart';
import 'package:boretube_mobile/screens/shell_screen.dart';
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
  testWidgets('Mute flips at once, shows a small ring, no success snack',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const NowTab(),
      scaffold: true,
      overrides: env.overrides(now: playing, actions: actions),
    );
    await settle(tester);
    expect(inTile('action-mute', 'Mute'), findsOneWidget);

    await tester.tap(find.byKey(const Key('action-mute')));
    await tester.pump();

    // Before the TV answers: already muted everywhere, ring on the tile.
    expect(actions.calls, ['mute']);
    expect(inTile('action-mute', 'Unmute'), findsOneWidget);
    expect(inTile('action-mute', 'Muted'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsWidgets);
    expect(ring('action-mute'), findsOneWidget);
    // Unrelated tiles stay usable; conflicting ones wait.
    await tester.tap(find.byKey(const Key('action-stop')));
    await tester.pump();
    expect(actions.calls, ['mute', 'stop']);
    expect(find.text('Home screen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('action-bore')));
    await tester.pump();
    expect(actions.calls, ['mute', 'stop'], reason: 'bore conflicts');

    actions.answer(ok);
    await tester.pump();
    actions.answer(ok);
    await tester.pump();
    expect(ring('action-mute'), findsNothing);
    expect(inTile('action-mute', 'Unmute'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('a failed action rolls back and says why', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const NowTab(),
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
    expect(inTile('action-mute', 'Mute'), findsOneWidget);
    expect(inTile('action-mute', 'Sound on'), findsOneWidget);
    expect(ring('action-mute'), findsNothing);
    expect(find.text('Didn\'t work: TV said no'), findsOneWidget);
  });

  testWidgets('a failed Stop puts the app back on the hero card',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const NowTab(),
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

  group('Break', () {
    final t0 = DateTime(2026, 10, 28, 19);

    testWidgets('sheet starts a break: banner, muted tile, at once',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      final actions = ScriptedActions();
      await pumpScreen(
        tester,
        const NowTab(),
        scaffold: true,
        overrides: env.overrides(
          now: playing,
          actions: actions,
          clock: () => t0,
        ),
      );
      await settle(tester);
      expect(inTile('action-break', 'Break'), findsOneWidget);
      expect(inTile('action-break', '15 · 30 · 60 min'), findsOneWidget);

      await tester.tap(find.byKey(const Key('action-break')));
      await settle(tester);
      expect(
        find.text('Closes the app and mutes now. Sound comes back '
            'automatically.'),
        findsOneWidget,
      );
      expect(find.textContaining('TV Guard (coming soon)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('break-15')));
      await settle(tester);

      expect(actions.calls, ['break 15']);
      expect(find.text('Break · 15:00 left'), findsOneWidget);
      expect(inTile('action-mute', 'On break'), findsOneWidget);
      expect(find.text('Home screen'), findsOneWidget);
      expect(
        env.prefs.getString(BreakController.keyFor(adbSony.id)),
        t0.add(const Duration(minutes: 15)).toIso8601String(),
      );
      actions.answer(ok);
      await settle(tester);
      expect(find.text('Break · 15:00 left'), findsOneWidget);
    });

    testWidgets('resumes from prefs, counts down live, End now restores',
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
        const Column(
          children: [
            GuardPill(),
            Expanded(child: NowTab()),
          ],
        ),
        scaffold: true,
        overrides: env.overrides(
          now: playing,
          actions: actions,
          clock: () => now,
        ),
      );
      await tester.pump();
      expect(find.text('Break · 12:40 left'), findsOneWidget);
      expect(find.text('☕ Break'), findsOneWidget);
      expect(inTile('action-mute', 'Unmute'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Break · 12:39 left'), findsOneWidget);

      await tester.tap(find.byKey(const Key('break-end')));
      await tester.pump();
      expect(find.byKey(const Key('break-banner')), findsNothing);
      expect(actions.calls, ['restore']);
      actions.answer(ok);
      await settle(tester);
      expect(find.byKey(const Key('break-banner')), findsNothing);
      expect(find.text('Not guarded'), findsOneWidget);
      expect(
        env.prefs.getString(BreakController.keyFor(adbSony.id)),
        isNull,
      );
    });
  });
}
