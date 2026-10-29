import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/screens/home/home_logic.dart';
import 'package:boretube_mobile/screens/home/home_tab.dart';
import 'package:boretube_mobile/screens/now/quick_actions.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:boretube_mobile/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Finder key(String k) => find.byKey(Key(k), skipOffstage: false);

AgentLink upLink({AgentMode mode = AgentMode.normal}) => AgentLink(
      AgentLinkKind.up,
      lastOk: DateTime.now(),
      status: AgentStatus(agentId: 'a', version: '1.0.0', mode: mode),
    );

Override link(AgentLink l) =>
    agentStatusProvider.overrideWith((ref) => AgentStatusNotifier.fixed(l));

Future<void> pumpHome(
  WidgetTester tester,
  TestEnv env, {
  NowPlaying now = playing,
  List<Override> extra = const [],
  double textScale = 1,
  DateTime Function()? clock,
}) async {
  await pumpScreen(
    tester,
    const HomeTab(),
    scaffold: true,
    textScale: textScale,
    size: const Size(360, 1400),
    overrides: [...env.overrides(now: now, clock: clock), ...extra],
  );
  await settle(tester);
}

List<bool> worksStates(WidgetTester tester) => [
      for (var i = 0; i < 5; i++)
        tester.widget<CheckLine>(find.byKey(Key('works-$i'))).done,
    ];

void main() {
  group('supportedActions', () {
    test('Cast-only Sony: no volume (Cast volume is wrong there)', () {
      expect(supportedActions(castOnlySony), {
        QuickAction.mute,
        QuickAction.stop,
        QuickAction.bore,
        QuickAction.takeBreak,
        QuickAction.restore,
      });
    });

    test('Cast-only non-Sony TV gets Cast volume', () {
      const tv = Tv(
        id: 'udn:x',
        name: 'Other',
        manufacturer: 'TCL',
        ip: '10.0.0.5',
        capabilities: {TvCapability.cast},
      );
      expect(supportedActions(tv), contains(QuickAction.volume));
    });

    test('ADB TV gets everything', () {
      expect(supportedActions(adbSony), QuickAction.values.toSet());
    });

    test('unprobed TV gets nothing', () {
      const tv = Tv(id: 'ip:1.2.3.4', name: 'TV', ip: '1.2.3.4');
      expect(supportedActions(tv), isEmpty);
    });
  });

  testWidgets('Remote TV: hero, Pause, Quiet/End app/More, no Volume',
      (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    await pumpHome(tester, env);

    expect(key('home-hero'), findsOneWidget);
    expect(find.text('SmartTube'), findsOneWidget);
    expect(find.text('Volume 24'), findsOneWidget);
    expect(find.text('Remote'), findsOneWidget);
    for (final k in ['action-break', 'action-mute', 'action-stop']) {
      expect(key(k), findsOneWidget, reason: k);
    }
    expect(key('action-more'), findsOneWidget);
    expect(key('action-volume'), findsNothing);
    expect(key('today-strip'), findsOneWidget);
    // No jargon on Home.
    for (final w in ['ADB', 'Cast', 'TV Guard', 'agent']) {
      expect(find.textContaining(w), findsNothing, reason: w);
    }
  });

  testWidgets('Home mode TV: Volume tile and the Home mode badge',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpHome(tester, env);
    expect(key('action-volume'), findsOneWidget);
    expect(find.text('Home mode'), findsOneWidget);
  });

  testWidgets('muted TV shows Unmute and says sound is off', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpHome(
      tester,
      env,
      now: const NowPlaying(
        online: true,
        appName: 'Home screen',
        isHome: true,
        volume: 10,
        muted: true,
        source: 'cast',
      ),
    );
    expect(find.text('Unmute'), findsOneWidget);
    expect(find.text('Muted'), findsOneWidget);
    expect(find.textContaining('Sound\u00A0off'), findsOneWidget);
  });

  testWidgets('off at the wall: can\'t reach it · last seen, controls dimmed',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpHome(
      tester,
      env,
      now: NowPlaying(
        lastSeen: DateTime.now().subtract(const Duration(minutes: 7)),
      ),
    );
    expect(find.text('Can\'t reach Living Room TV'), findsOneWidget);
    expect(find.text('Last seen 7 min ago'), findsOneWidget);
    expect(find.textContaining('off at the wall'), findsOneWidget);
    expect(key('home-retry'), findsOneWidget);
    final pause = tester.widget<PrimaryButton>(key('action-break'));
    expect(pause.onPressed, isNull);
    final quiet = tester.widget<ActionTile>(key('action-mute'));
    expect(quiet.onTap, isNull);
  });

  group('the TV\'s own power state', () {
    const down = AgentLink(AgentLinkKind.down);
    final limited = AgentLink(
      AgentLinkKind.up,
      lastOk: DateTime.now(),
      status: const AgentStatus(
        agentId: 'a',
        version: '1.4.1',
        uptimeSec: 600,
        limited: true,
      ),
    );

    testWidgets('standby: calm, asleep, no Repair and no retry',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpHome(
        tester,
        env,
        now: const NowPlaying(online: true, asleep: true, source: 'adb'),
        extra: [link(down)],
      );
      expect(find.text('Living Room TV is asleep'), findsOneWidget);
      expect(key('home-problem'), findsNothing);
      expect(key('home-retry'), findsNothing);
      final pause = tester.widget<PrimaryButton>(key('action-break'));
      expect(pause.onPressed, isNull);
    });

    testWidgets('just woke: a limited helper is not a problem yet',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpHome(
        tester,
        env,
        now: playing.withAwakeSince(
          DateTime.now().subtract(const Duration(seconds: 10)),
        ),
        extra: [link(limited)],
      );
      expect(key('home-problem'), findsNothing);
    });

    testWidgets('awake and settled: limited and silent are real problems',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpHome(tester, env, extra: [link(limited)]);
      expect(find.text('Always On can\'t close apps yet'), findsOneWidget);
    });

    testWidgets('awake and settled, helper silent: Reconnect', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpHome(tester, env, extra: [link(down)]);
      expect(find.text('Always On is off right now'), findsOneWidget);
    });
  });

  group('paused hero', () {
    final t0 = DateTime(2026, 10, 28, 19);

    Future<TestEnv> envWith({bool byTv = false}) => TestEnv.create(
          tvs: [adbSony],
          prefs: {
            BreakController.keyFor(adbSony.id): t0
                .add(const Duration(minutes: 12, seconds: 40))
                .toIso8601String(),
            if (byTv) BreakController.flagsKeyFor(adbSony.id): 'tv',
          },
        );

    testWidgets('kept by this phone: countdown, ends at, +15 / End break',
        (tester) async {
      final env = await envWith();
      await pumpHome(tester, env, clock: () => t0);
      expect(find.text('The TV is taking a break'), findsOneWidget);
      expect(find.text('12:40'), findsOneWidget);
      expect(
        find.text('left · sound returns by itself at 7:12 pm'),
        findsOneWidget,
      );
      expect(find.text('Keep this app open'), findsOneWidget);
      expect(key('break-extend'), findsOneWidget);
      expect(key('break-end'), findsOneWidget);
      expect(key('during-break'), findsOneWidget);
      expect(key('action-break'), findsNothing);
    });

    testWidgets('kept by the TV says so', (tester) async {
      final env = await envWith(byTv: true);
      await pumpHome(tester, env, clock: () => t0);
      expect(
        find.text('Kept by the TV, even if you close this app'),
        findsOneWidget,
      );
    });
  });

  testWidgets('problem: plain words, one fix, and what still works',
      (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpHome(
      tester,
      env,
      extra: [link(const AgentLink(AgentLinkKind.down))],
    );
    expect(key('home-problem'), findsOneWidget);
    expect(find.text('Always On is off right now'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text(' · about 1 minute'), findsOneWidget);
    expect(key('still-working'), findsOneWidget);
    expect(find.text('Bedtime when you\'re away'), findsOneWidget);
    // The problem replaces the hero; Pause still works.
    expect(key('home-hero'), findsNothing);
    expect(key('action-break'), findsOneWidget);
    final semantics = find
        .ancestor(
          of: find.text('Always On is off right now'),
          matching: find.byType(Semantics),
        )
        .evaluate()
        .map((e) => e.widget as Semantics);
    expect(semantics.any((s) => s.properties.liveRegion ?? false), isTrue);
  });

  testWidgets('paused Always On is a calm note, not an alarm', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpHome(
      tester,
      env,
      extra: [link(upLink(mode: AgentMode.paused))],
    );
    expect(key('home-problem'), findsNothing);
    expect(key('home-info'), findsOneWidget);
    expect(find.text('Always On is paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(key('home-hero'), findsOneWidget);
  });

  group('What works right now', () {
    testWidgets('Remote: only phone controls, offers Home mode',
        (tester) async {
      final env = await TestEnv.create(tvs: [castOnlySony]);
      await pumpHome(tester, env);
      await tester.tap(key('mode-badge'));
      await settle(tester);
      expect(find.text('What works right now'), findsOneWidget);
      expect(find.text('you are here'), findsOneWidget);
      expect(worksStates(tester), [true, true, false, false, false]);
      expect(key('works-unlock'), findsOneWidget);
    });

    testWidgets('Home mode: Shorts and Clean TV too, offers Always On',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpHome(tester, env);
      await tester.tap(key('mode-badge'));
      await settle(tester);
      expect(worksStates(tester), [true, true, true, false, false]);
      expect(key('works-always-on'), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
      expect(find.text('one step'), findsOneWidget);
    });

    testWidgets('Always On: everything, nothing more to unlock',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpHome(tester, env, extra: [link(upLink())]);
      await tester.tap(key('mode-badge'));
      await settle(tester);
      expect(worksStates(tester), [true, true, true, true, true]);
      expect(find.textContaining('You\'re all set'), findsOneWidget);
    });
  });

  test('protection levels', () {
    expect(protectionOf(castOnlySony, AgentLink.none), Protection.remote);
    expect(protectionOf(adbSony, AgentLink.none), Protection.home);
    expect(
      protectionOf(adbSony, const AgentLink(AgentLinkKind.down)),
      Protection.alwaysOn,
    );
  });

  test('next bedtime and the Until bedtime chip', () {
    const rows = [
      ScheduleRow(days: [1, 2, 3, 4, 5], from: '21:00', to: '07:00'),
    ];
    // Wednesday 18:50.
    final wed = DateTime(2026, 10, 28, 18, 50);
    final b = nextBedtime(rows, wed)!;
    expect(b.now, isFalse);
    expect(b.start, DateTime(2026, 10, 28, 21));
    expect(minutesUntilBedtime(rows, wed), 130);
    expect(spanLabel(b.start.difference(wed)), '2h 10m');
    // Thursday 06:00: still inside Wednesday night's window.
    final thu = DateTime(2026, 10, 29, 6);
    expect(nextBedtime(rows, thu)!.now, isTrue);
    expect(minutesUntilBedtime(rows, thu), isNull);
  });

  testWidgets('Home fits a 360dp phone at 1.3× text', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpHome(tester, env, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
