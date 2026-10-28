import 'package:boretube_mobile/agent/agent_models.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/nudges.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thursday 29 Oct 2026, 7 pm.
final now = DateTime(2026, 10, 29, 19);

DateTime daysAgo(int d, int h, [int m = 0]) =>
    DateTime(now.year, now.month, now.day - d, h, m);

ActivityItem item(
  String op, {
  String target = '',
  DateTime? at,
  bool ok = true,
  JournalSource source = JournalSource.phone,
}) =>
    ActivityItem(
      JournalEntry(
        tvId: 'tv',
        time: at ?? now.subtract(const Duration(hours: 1)),
        op: op,
        target: target,
        before: '',
        after: '',
        ok: ok,
      ),
      source,
    );

const bedtimeRules = AgentRules(
  tvTime: TvTime(schedule: [ScheduleRow()]),
);

HealthCheck check(String id, HealthStatus s) =>
    HealthCheck(id: id, title: id, status: s, detail: '');

void main() {
  group('1 · bedtime', () {
    final pauses = [daysAgo(2, 20, 10), daysAgo(1, 20, 40), daysAgo(0, 20)];

    test('same hour three days running', () {
      final n = bedtimeNudge(NudgeInputs(now: now, pauses: pauses));
      expect(n?.id, NudgeId.bedtime);
      expect(n!.message, contains('8:00 pm'));
      expect(n.target, NudgeTarget.routines);
    });

    test('a run ending yesterday counts too', () {
      final shifted = [
        for (final p in pauses) p.subtract(const Duration(days: 1))
      ];
      expect(bedtimeNudge(NudgeInputs(now: now, pauses: shifted)), isNotNull);
    });

    test('not with a gap day, a far-off hour, or a bedtime set', () {
      expect(
        bedtimeNudge(
          NudgeInputs(now: now, pauses: [pauses[0], pauses[2]]),
        ),
        isNull,
      );
      expect(
        bedtimeNudge(
          NudgeInputs(
            now: now,
            pauses: [daysAgo(2, 17), daysAgo(1, 20, 40), daysAgo(0, 20)],
          ),
        ),
        isNull,
      );
      expect(
        bedtimeNudge(
          NudgeInputs(now: now, pauses: pauses, rules: bedtimeRules),
        ),
        isNull,
      );
    });
  });

  group('2 · volume limit', () {
    final downs = [daysAgo(5, 18), daysAgo(3, 19), daysAgo(0, 18)];

    test('three times this week', () {
      final n = volumeLimitNudge(NudgeInputs(now: now, volumeDowns: downs));
      expect(n?.id, NudgeId.volumeLimit);
      expect(n!.message, contains('3 times'));
    });

    test('not when older, fewer, or already limited', () {
      expect(
        volumeLimitNudge(
          NudgeInputs(
              now: now, volumeDowns: [daysAgo(9, 18), ...downs.skip(1)]),
        ),
        isNull,
      );
      expect(
        volumeLimitNudge(
          NudgeInputs(
            now: now,
            volumeDowns: downs,
            rules: const AgentRules(volumeLimit: VolumeLimit(enabled: true)),
          ),
        ),
        isNull,
      );
    });
  });

  group('3 · YouTube without Shorts', () {
    test('stock YouTube is back after boretube removed it', () {
      final n = noShortsNudge(
        NudgeInputs(
          now: now,
          activity: [item('stockYouTubeOff', at: daysAgo(4, 10))],
          stockYouTubeInstalled: true,
        ),
      );
      expect(n?.title, 'YouTube came back');
      expect(n!.focus, 'noShorts');
    });

    test('YouTube stopped five times this week', () {
      final n = noShortsNudge(
        NudgeInputs(
          now: now,
          activity: [
            for (var d = 0; d < 5; d++)
              item(
                'closeApp',
                target: kStockYouTubePkg,
                at: daysAgo(d, 18),
                source: JournalSource.rule,
              ),
          ],
        ),
      );
      expect(n?.title, 'YouTube keeps getting closed');
    });

    test('not when the parent brought it back on purpose', () {
      expect(
        noShortsNudge(
          NudgeInputs(
            now: now,
            activity: [
              item('stockYouTubeOff', at: daysAgo(4, 10)),
              item('stockYouTubeOn', at: daysAgo(2, 10)),
            ],
            stockYouTubeInstalled: true,
          ),
        ),
        isNull,
      );
    });
  });

  group('4 · Clean TV', () {
    final health = [check('cleanup', HealthStatus.warn)];

    test('Home mode new and the TV still untidy', () {
      final n = cleanTvNudge(
        NudgeInputs(
          now: now,
          hasAdb: true,
          adbSince: now.subtract(const Duration(hours: 3)),
          health: health,
        ),
      );
      expect(n?.id, NudgeId.cleanTv);
      expect(n!.focus, 'cleanTv');
    });

    test('not after two days, when tidy, or without Home mode', () {
      expect(
        cleanTvNudge(
          NudgeInputs(
            now: now,
            hasAdb: true,
            adbSince: now.subtract(const Duration(days: 3)),
            health: health,
          ),
        ),
        isNull,
      );
      expect(
        cleanTvNudge(
          NudgeInputs(
            now: now,
            hasAdb: true,
            adbSince: now,
            health: [check('cleanup', HealthStatus.ok)],
          ),
        ),
        isNull,
      );
      expect(
        cleanTvNudge(NudgeInputs(now: now, adbSince: now, health: health)),
        isNull,
      );
    });
  });

  group('5 · Always On (routine missed while away)', () {
    // Paused around 8 pm on Monday and Tuesday; the app was then closed
    // from Tuesday 9 pm until now (Thursday 7 pm): Wednesday's 8 pm went
    // by with no pause.
    final pauses = [daysAgo(3, 20), daysAgo(2, 20, 10)];

    test('the usual pause hour passed while the app was closed', () {
      final n = alwaysOnNudge(
        NudgeInputs(now: now, pauses: pauses, lastVisit: daysAgo(2, 21)),
      );
      expect(n?.id, NudgeId.alwaysOn);
      expect(n!.focus, 'alwaysOn');
      expect(n.message, contains('8:10 pm'));
    });

    test('not with Always On, or when the app was open through it', () {
      expect(
        alwaysOnNudge(
          NudgeInputs(
            now: now,
            pauses: pauses,
            lastVisit: daysAgo(2, 21),
            alwaysOn: true,
          ),
        ),
        isNull,
      );
      expect(
        alwaysOnNudge(
          NudgeInputs(
            now: now,
            pauses: [...pauses, daysAgo(1, 20)],
            lastVisit: daysAgo(0, 9),
          ),
        ),
        isNull,
      );
    });
  });

  group('6 · friendly message', () {
    List<ActivityItem> reopened(int n) => [
          for (var i = 0; i < n; i++)
            item(
              'closeApp',
              target: 'org.smarttube.stable',
              at: daysAgo(1, 18, i * 10),
              source: JournalSource.rule,
            ),
        ];

    test('one app closed 3 times in a day, TV says no quietly', () {
      final n = friendlyMessageNudge(
        NudgeInputs(
          now: now,
          rules: const AgentRules(),
          activity: reopened(4),
        ),
      );
      expect(n?.title, 'SmartTube was reopened 3×');
    });

    test('not twice, or with the friendly message already on', () {
      expect(
        friendlyMessageNudge(
          NudgeInputs(
              now: now, rules: const AgentRules(), activity: reopened(2)),
        ),
        isNull,
      );
      expect(
        friendlyMessageNudge(
          NudgeInputs(
            now: now,
            rules: const AgentRules(style: RuleStyle.explicit),
            activity: reopened(4),
          ),
        ),
        isNull,
      );
    });
  });

  group('7 · weekend preset', () {
    NudgeInputs calm({
      List<ActivityItem> activity = const [],
      AgentRules rules = bedtimeRules,
      bool problem = false,
      int days = 8,
    }) =>
        NudgeInputs(
          now: now,
          alwaysOn: true,
          rules: rules,
          activity: activity,
          problem: problem,
          firstOpen: now.subtract(Duration(days: days)),
        );

    test('a week with nothing going wrong', () {
      expect(weekendPresetNudge(calm())?.id, NudgeId.weekendPreset);
    });

    test('not after a failure, too soon, or with weekends set', () {
      expect(
        weekendPresetNudge(calm(activity: [item('stopApp', ok: false)])),
        isNull,
      );
      expect(weekendPresetNudge(calm(days: 3)), isNull);
      expect(weekendPresetNudge(calm(problem: true)), isNull);
      expect(
        weekendPresetNudge(
          calm(
            rules: const AgentRules(
              tvTime: TvTime(
                schedule: [
                  ScheduleRow(days: [6, 7])
                ],
              ),
            ),
          ),
        ),
        isNull,
      );
    });
  });

  group('8 · TV update', () {
    test('agent or Home mode saw a new build', () {
      expect(
        reviewUpdateNudge(
          NudgeInputs(
            now: now,
            status: const AgentStatus(
              agentId: 'a',
              version: '1',
              buildChangedSinceApproval: true,
            ),
          ),
        )?.focus,
        'health',
      );
      expect(
        reviewUpdateNudge(NudgeInputs(now: now, buildChanged: true)),
        isNotNull,
      );
    });

    test('not when nothing changed or the Home banner already says so', () {
      expect(reviewUpdateNudge(NudgeInputs(now: now)), isNull);
      expect(
        reviewUpdateNudge(
          NudgeInputs(now: now, buildChanged: true, problem: true),
        ),
        isNull,
      );
    });
  });

  group('9 · speech', () {
    test('speech check failed', () {
      expect(
        fixSpeechNudge(
          NudgeInputs(now: now, health: [check('speech', HealthStatus.fail)]),
        )?.id,
        NudgeId.fixSpeech,
      );
    });

    test('a warning is not broken', () {
      expect(
        fixSpeechNudge(
          NudgeInputs(now: now, health: [check('speech', HealthStatus.warn)]),
        ),
        isNull,
      );
    });
  });

  group('10 · new TV', () {
    test('an unsaved TV on the Wi-Fi', () {
      final n = newTvNudge(NudgeInputs(now: now, unsavedTvs: 1));
      expect(n?.target, NudgeTarget.addTv);
    });

    test('none seen', () {
      expect(newTvNudge(NudgeInputs(now: now)), isNull);
    });
  });

  test('candidates come in priority order', () {
    final list = nudgeCandidates(
      NudgeInputs(
        now: now,
        unsavedTvs: 1,
        health: [check('speech', HealthStatus.fail)],
        volumeDowns: [daysAgo(1, 1), daysAgo(1, 2), daysAgo(1, 3)],
      ),
    );
    expect(
      [for (final n in list) n.id],
      [NudgeId.fixSpeech, NudgeId.volumeLimit, NudgeId.newTv],
    );
  });

  group('session and backoff', () {
    late NudgeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = NudgeStore(await SharedPreferences.getInstance());
    });

    final a = nudgeCandidates(
      NudgeInputs(now: now, unsavedTvs: 1),
    ).single;
    final b = fixSpeechNudge(
      NudgeInputs(now: now, health: [check('speech', HealthStatus.fail)]),
    )!;

    test('at most one per app open, and stable while it lasts', () async {
      final s = NudgeSession(store);
      expect(s.choose([a], now: now)?.id, NudgeId.newTv);
      // A higher-priority nudge appearing later doesn't replace it.
      expect(s.choose([b, a], now: now)?.id, NudgeId.newTv);
      await s.notNow(now);
      expect(s.choose([b, a], now: now), isNull);
    });

    test('never during an action, without spending the open', () {
      final s = NudgeSession(store);
      expect(s.choose([a], now: now, busy: true), isNull);
      expect(s.choose([a], now: now)?.id, NudgeId.newTv);
      expect(s.choose([a], now: now, busy: true), isNull);
      expect(s.choose([a], now: now)?.id, NudgeId.newTv);
    });

    test('hidden when its reason goes away', () {
      final s = NudgeSession(store);
      expect(s.choose([a], now: now), isNotNull);
      expect(s.choose(const [], now: now), isNull);
    });

    test('Not now backs off 7 days, then 30, then never', () async {
      final id = NudgeId.newTv;
      await store.notNow(id, now);
      expect(store.eligible(id, now.add(const Duration(days: 6))), isFalse);
      expect(store.eligible(id, now.add(const Duration(days: 7))), isTrue);

      final second = now.add(const Duration(days: 7));
      await store.notNow(id, second);
      expect(store.eligible(id, second.add(const Duration(days: 29))), isFalse);
      expect(store.eligible(id, second.add(const Duration(days: 30))), isTrue);

      await store.notNow(id, second.add(const Duration(days: 30)));
      expect(store.eligible(id, now.add(const Duration(days: 999))), isFalse);

      // It survives a restart (read back from prefs).
      final again = NudgeStore(await SharedPreferences.getInstance());
      expect(again.snoozes(id), 3);
      expect(again.eligible(id, now.add(const Duration(days: 999))), isFalse);
    });

    test('acting on a nudge retires it', () async {
      final s = NudgeSession(store);
      s.choose([a], now: now);
      await s.acted();
      expect(store.eligible(NudgeId.newTv, now), isFalse);
    });

    test('a snoozed nudge lets the next one through on a new open', () async {
      await store.notNow(NudgeId.fixSpeech, now);
      expect(NudgeSession(store).choose([b, a], now: now)?.id, NudgeId.newTv);
    });

    test('logs keep three weeks', () async {
      await store.logPause(now.subtract(const Duration(days: 30)));
      await store.logPause(now);
      expect(store.pauses, [now]);
      await store.logVolumeDown(now);
      expect(store.volumeDowns, [now]);
    });

    test('a new TV build re-arms the update nudge', () async {
      expect(store.noteBuild('tv', 'A'), isFalse);
      expect(store.noteBuild('tv', 'A'), isFalse);
      await store.acted(NudgeId.reviewUpdate);
      expect(store.noteBuild('tv', 'B'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(store.eligible(NudgeId.reviewUpdate, now), isTrue);
      expect(store.noteBuild('tv', 'B'), isTrue);
      await store.buildReviewed('tv');
      expect(store.noteBuild('tv', 'B'), isFalse);
    });
  });
}
