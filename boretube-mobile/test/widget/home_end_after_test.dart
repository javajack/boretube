import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/home/home_logic.dart';
import 'package:boretube_mobile/screens/home/home_tab.dart';
import 'package:boretube_mobile/screens/rules_tab.dart';
import 'package:boretube_mobile/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

const playing = NowPlaying(
  online: true,
  id: 'org.smarttube.stable',
  appName: 'SmartTube',
  volume: 24,
  muted: false,
  source: 'agent',
);

const episode = AgentMedia(
  pkg: 'org.smarttube.stable',
  title: 'Bluey · The Creek, and a much longer title that keeps on going',
  artist: 'Bluey Official • 2M views',
  state: MediaState.playing,
  positionMs: 312000,
  durationMs: 1260000,
  remainingMs: 948000,
  source: MediaSource.listener,
);

/// Wednesday 18:50; bedtime 21:00.
final t0 = DateTime(2026, 10, 28, 18, 50);

AgentLink linkWith({
  AgentMedia? media,
  AgentEndAfter endAfter = const AgentEndAfter(),
  AgentBreak breakState = const AgentBreak(),
  AgentShorts? shorts,
  AgentMode mode = AgentMode.normal,
}) =>
    AgentLink(
      AgentLinkKind.up,
      lastOk: t0,
      status: AgentStatus(
        agentId: 'a',
        version: '1.1.0',
        mode: mode,
        media: media,
        endAfter: endAfter,
        breakState: breakState,
        shorts: shorts,
      ),
    );

Finder key(String k) => find.byKey(Key(k), skipOffstage: false);

void main() {
  late List<http.Request> sent;
  late Map<String, dynamic> reply;

  http.Client mock() => MockClient((r) async {
        sent.add(r);
        if (r.url.path == '/v1/rules') {
          return http.Response(
            jsonEncode(
              const AgentRules(
                version: 2,
                tvTime: TvTime(
                  schedule: [
                    ScheduleRow(
                      days: [1, 2, 3, 4, 5],
                      from: '21:00',
                      to: '07:00',
                    ),
                  ],
                ),
              ).toJson(),
            ),
            200,
          );
        }
        if (r.url.path == '/v1/journal') return http.Response('[]', 200);
        return http.Response(jsonEncode(reply), 200);
      });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required AgentLink link,
    NowPlaying now = playing,
    DateTime? at,
    bool agent = true,
    List<Override> extra = const [],
  }) async {
    sent = [];
    reply = {'ok': true, 'detail': 'following'};
    final env = await TestEnv.create(tvs: [adbSony]);
    if (agent) await AgentTokenStore(env.secrets).write(adbSony.id, 'tok');
    await pumpScreen(
      tester,
      const HomeTab(),
      scaffold: true,
      size: const Size(360, 1400),
      overrides: [
        ...env.overrides(now: now, clock: () => at ?? t0),
        if (agent)
          agentStatusProvider.overrideWith(
            (ref) => AgentStatusNotifier.fixed(link),
          ),
        agentHttpClientProvider.overrideWithValue(mock()),
        ...extra,
      ],
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(HomeTab)));
  }

  group('hero shows what is playing', () {
    testWidgets('title (2 lines), channel and a progress line', (tester) async {
      await pump(tester, link: linkWith(media: episode));
      final title = tester.widget<Text>(find.text(episode.title!));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.text('Watching on SmartTube'), findsOneWidget);
      expect(find.text('Bluey Official • 2M views'), findsOneWidget);
      expect(key('hero-progress'), findsOneWidget);
      expect(find.text('about 16 min left'), findsOneWidget);
    });

    testWidgets('no duration: no progress line and no time', (tester) async {
      await pump(
        tester,
        link: linkWith(
          media: const AgentMedia(
            pkg: 'org.smarttube.stable',
            title: 'Some video',
            state: MediaState.playing,
            positionMs: 40000,
            source: MediaSource.dumpsys,
          ),
        ),
      );
      expect(find.text('Some video'), findsOneWidget);
      expect(key('hero-progress'), findsNothing);
      expect(find.textContaining('min left'), findsNothing);
    });
  });

  group('When this ends chip', () {
    testWidgets('duration known: "When this ends · about N min"',
        (tester) async {
      await pump(tester, link: linkWith(media: episode));
      expect(find.text('When this ends · about 16 min'), findsOneWidget);
    });

    testWidgets('duration unknown: an honest "After this one"', (tester) async {
      await pump(
        tester,
        link: linkWith(
          media: const AgentMedia(
            pkg: 'org.smarttube.stable',
            title: 'Some video',
            state: MediaState.playing,
            source: MediaSource.dumpsys,
          ),
        ),
      );
      expect(find.text('After this one'), findsOneWidget);
      expect(find.textContaining('When this ends'), findsNothing);
    });

    testWidgets('no Always On: no chip, no fake behaviour', (tester) async {
      await pump(tester, link: AgentLink.none, agent: false);
      expect(key('pause-end-after'), findsNothing);
      expect(key('action-break'), findsOneWidget);
    });

    testWidgets('Always On without a video: no chip', (tester) async {
      await pump(tester, link: linkWith());
      expect(key('pause-end-after'), findsNothing);
    });

    testWidgets('Always On paused: no chip', (tester) async {
      await pump(
        tester,
        link: linkWith(media: episode, mode: AgentMode.paused),
      );
      expect(key('pause-end-after'), findsNothing);
    });

    testWidgets('tap arms it (cap 45, break 60) and shows Cancel',
        (tester) async {
      await pump(tester, link: linkWith(media: episode));
      await tester.tap(key('pause-end-after'));
      await settle(tester);
      final post = sent.singleWhere((r) => r.url.path == '/v1/action');
      expect(jsonDecode(post.body), {
        'action': 'endAfter',
        'capMin': 45,
        'breakMin': 60,
      });
      expect(key('end-after-armed'), findsOneWidget);
      expect(
        find.textContaining('Pausing after this one'),
        findsOneWidget,
      );
      expect(find.text('At the latest by 7:35 pm'), findsOneWidget);
      // Armed: the chip steps aside; Pause TV still works now.
      expect(key('pause-end-after'), findsNothing);
      expect(key('action-break'), findsOneWidget);

      await tester.tap(key('end-after-cancel'));
      await settle(tester);
      expect(
        jsonDecode(sent.last.body),
        {'action': 'cancelEndAfter'},
      );
      expect(key('end-after-armed'), findsNothing);
      expect(key('pause-end-after'), findsOneWidget);
    });

    testWidgets('during bedtime the break lasts until bedtime ends',
        (tester) async {
      // Wednesday 22:00: bedtime until 07:00 → 540 min.
      await pump(
        tester,
        link: linkWith(media: episode),
        at: DateTime(2026, 10, 28, 22),
        extra: [
          rulesProvider.overrideWith(
            (ref) async => const AgentRules(
              version: 2,
              tvTime: TvTime(
                schedule: [
                  ScheduleRow(
                    days: [1, 2, 3, 4, 5],
                    from: '21:00',
                    to: '07:00',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      await tester.tap(key('pause-end-after'));
      await settle(tester);
      final post = sent.singleWhere((r) => r.url.path == '/v1/action');
      expect(jsonDecode(post.body)['breakMin'], 540);
    });

    testWidgets('the TV can\'t follow it: rolled back with a reason',
        (tester) async {
      await pump(tester, link: linkWith(media: episode));
      reply = {'ok': false, 'detail': 'no foreground video to follow'};
      await tester.tap(key('pause-end-after'));
      await settle(tester);
      expect(key('end-after-armed'), findsNothing);
      expect(
          find.textContaining('couldn\'t follow this video'), findsOneWidget);
    });

    testWidgets('armed by the TV → paused when the break starts',
        (tester) async {
      final c = await pump(
        tester,
        link: linkWith(
          media: episode,
          endAfter: AgentEndAfter(
            armed: true,
            title: 'Bluey · The Creek',
            capAt: t0.add(const Duration(minutes: 45)),
            breakMin: 60,
          ),
        ),
      );
      expect(
        find.text('Pausing after this one · Bluey · The Creek'),
        findsOneWidget,
      );
      expect(key('break-banner'), findsNothing);

      // The video ended: the agent starts the break and disarms.
      c.read(agentStatusProvider.notifier).debugSet(
            linkWith(
              breakState: AgentBreak(
                active: true,
                endsAt: t0.add(const Duration(minutes: 60)),
              ),
            ),
          );
      await settle(tester);
      expect(key('break-banner'), findsOneWidget);
      expect(find.text('Kept by the TV, even if you close this app'),
          findsOneWidget);
      expect(key('end-after-armed'), findsNothing);
      expect(c.read(breakProvider).byTv, isTrue);
    });
  });

  group('Today: Shorts', () {
    testWidgets('a count when the TV only reports', (tester) async {
      await pump(
        tester,
        link: linkWith(
          shorts: const AgentShorts(mode: ShortsMode.report, todayCount: 7),
        ),
      );
      expect(find.text('Shorts today: 7'), findsOneWidget);
    });

    testWidgets('budget shows the allowance', (tester) async {
      await pump(
        tester,
        link: linkWith(
          shorts: const AgentShorts(
            mode: ShortsMode.budget,
            todayCount: 3,
            perDay: 5,
          ),
        ),
      );
      expect(find.text('Shorts today: 3 of 5'), findsOneWidget);
    });

    testWidgets('stops come from the TV\'s journal', (tester) async {
      await pump(
        tester,
        link: linkWith(
          shorts: const AgentShorts(mode: ShortsMode.block, todayCount: 9),
        ),
        extra: [
          agentJournalProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 3; i++)
                AgentJournalEntry(
                  time: t0.subtract(Duration(minutes: 10 * i + 1)),
                  op: 'shorts',
                  target: 'org.smarttube.stable',
                  before: 'shortsBlock',
                  after: 'closing; today 9',
                  source: JournalSource.rule,
                ),
            ],
          ),
        ],
      );
      expect(find.text('Shorts stopped 3× today'), findsOneWidget);
    });

    testWidgets('off: no Shorts line', (tester) async {
      await pump(
        tester,
        link: linkWith(
          shorts: const AgentShorts(todayCount: 4),
        ),
      );
      expect(find.textContaining('Shorts today:'), findsNothing);
      expect(find.textContaining('Shorts stopped'), findsNothing);
      expect(find.text('No Shorts today'), findsNothing);
    });
  });

  testWidgets('the nudge opens Routines at the Shorts card', (tester) async {
    await pump(
      tester,
      link: linkWith(
        shorts: const AgentShorts(todayCount: 4),
      ),
    );
    expect(find.text('Shorts keep sneaking in…'), findsOneWidget);
    expect(find.textContaining('4 Shorts today'), findsOneWidget);
    await tester.tap(find.text('Choose for Shorts'));
    await settle(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeTab)));
    expect(c.read(routinesFocusProvider), 'shorts');
    expect(c.read(shellTabProvider), 1);
  });

  test('labels stay honest', () {
    expect(endAfterLabel(episode), 'When this ends · about 16 min');
    expect(
      endAfterLabel(
        const AgentMedia(pkg: 'x', state: MediaState.playing),
      ),
      'After this one',
    );
    expect(aboutMinutes(const Duration(seconds: 10)), 'about 1 min');
    expect(
      endAfterBreakMinutes(const [], t0),
      60,
    );
  });

  testWidgets('armed hero fits 360 dp at 1.3× text', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await AgentTokenStore(env.secrets).write(adbSony.id, 'tok');
    await pumpScreen(
      tester,
      const HomeTab(),
      scaffold: true,
      textScale: 1.3,
      size: const Size(360, 1600),
      overrides: [
        ...env.overrides(now: playing, clock: () => t0),
        agentStatusProvider.overrideWith(
          (ref) => AgentStatusNotifier.fixed(
            linkWith(
              media: episode,
              endAfter: AgentEndAfter(
                armed: true,
                title: episode.title,
                capAt: t0.add(const Duration(minutes: 45)),
              ),
            ),
          ),
        ),
      ],
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(PrimaryButton), findsWidgets);
  });
}
