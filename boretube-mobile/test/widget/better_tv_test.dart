import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/better_tv_tab.dart';
import 'package:boretube_mobile/screens/tv/clean_tv.dart';
import 'package:boretube_mobile/screens/tv/health_copy.dart';
import 'package:boretube_mobile/screens/tv/health_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../agent/fake_agent.dart' show fakeBundle;
import '../ops/fake_tv.dart';
import 'helpers.dart';

List<HealthCheck> sampleChecks(void Function() onFix) => [
      const HealthCheck(
        id: 'adb',
        title: 'ADB connection',
        status: HealthStatus.ok,
        detail: 'Connected',
      ),
      HealthCheck(
        id: 'cleanup',
        title: 'Bloat cleanup',
        status: HealthStatus.warn,
        detail: '20/22 disabled (pending: a, b)',
        fix: () async => onFix(),
      ),
      HealthCheck(
        id: 'stockYouTube',
        title: 'Stock YouTube',
        status: HealthStatus.warn,
        detail: 'Installed',
        fix: () async => onFix(),
      ),
      const HealthCheck(
        id: 'launcher',
        title: 'Home launcher',
        status: HealthStatus.ok,
        detail: 'Home opens the launcher',
      ),
    ];

List<Override> noAgent() => [
      agentStatusProvider
          .overrideWith((ref) => AgentStatusNotifier.fixed(AgentLink.none)),
      agentBundleLoaderProvider.overrideWithValue(() async => fakeBundle()),
    ];

void main() {
  group('Better TV summary', () {
    testWidgets('N need attention, Fix all asks then fixes every one',
        (tester) async {
      var fixed = 0;
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const BetterTvTab(),
        scaffold: true,
        size: const Size(360, 1600),
        overrides: [
          ...env.overrides(),
          ...noAgent(),
          healthProvider.overrideWith((ref) async => sampleChecks(() {
                fixed++;
              })),
        ],
      );
      await settle(tester);
      expect(find.text('2 things to fix'), findsOneWidget);
      expect(find.text('2 of 4 checks passed'), findsOneWidget);
      // Clean TV and YouTube have their own destination rows, so they are
      // reported there (with their state) and never twice in the checklist.
      for (final id in ['cleanup', 'stockYouTube']) {
        expect(find.byKey(Key('better-tv-check-$id')), findsNothing);
      }
      expect(find.byKey(const Key('better-tv-cleanTv')), findsOneWidget);
      expect(find.byKey(const Key('better-tv-noShorts')), findsOneWidget);
      expect(find.text('Checking the TV…'), findsNothing);
      expect(find.byKey(const Key('better-tv-health')), findsOneWidget);
      // Technical names stay out of the main screens.
      expect(find.textContaining('ADB'), findsNothing);

      await tester.tap(find.byKey(const Key('health-fix-all')));
      await settle(tester);
      expect(find.text('Fix 2 things?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(fixed, 0);

      await tester.tap(find.byKey(const Key('health-fix-all')));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Fix'),
        ),
      );
      await settle(tester);
      expect(fixed, 2);
      expect(find.text('All fixed'), findsOneWidget);
    });

    testWidgets('fixable and not: "Fix 2 now" and a "Needs you" row',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const BetterTvTab(),
        scaffold: true,
        size: const Size(360, 1600),
        overrides: [
          ...env.overrides(),
          agentStatusProvider.overrideWith(
            (ref) => AgentStatusNotifier.fixed(
              const AgentLink(
                AgentLinkKind.up,
                status: AgentStatus(
                  agentId: 'a',
                  version: '1.1.0',
                  health: [
                    AgentHealth(
                      id: 'watchdog',
                      status: AgentHealthStatus.warn,
                      detail: '3 changes wait for approval',
                    ),
                  ],
                ),
              ),
            ),
          ),
          agentBundleLoaderProvider.overrideWithValue(() async => fakeBundle()),
          healthProvider.overrideWith((ref) async => sampleChecks(() {})),
        ],
      );
      await settle(tester);
      expect(find.text('3 things to fix'), findsOneWidget);
      expect(find.text('Fix 2 now'), findsOneWidget);
      expect(find.textContaining('Fix all'), findsNothing);
      expect(find.byKey(const Key('health-needs-you')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('health-needs-you')),
          matching: find.text('Tidy-up after TV updates'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Needs you · '), findsOneWidget);
      await tester.tap(find.byKey(const Key('health-needs-you')));
      await settle(tester);
      expect(find.byType(HealthScreen), findsOneWidget);
      final screen = tester.widget<HealthScreen>(find.byType(HealthScreen));
      expect(screen.focus, 'agent.watchdog');
    });

    testWidgets('one fixable thing alone is "Fix it"', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const BetterTvTab(),
        scaffold: true,
        size: const Size(360, 1600),
        overrides: [
          ...env.overrides(),
          ...noAgent(),
          healthProvider.overrideWith(
            (ref) async => sampleChecks(() {}).sublist(0, 2),
          ),
        ],
      );
      await settle(tester);
      expect(find.text('1 thing to fix'), findsOneWidget);
      expect(find.text('Fix it'), findsOneWidget);
      expect(find.byKey(const Key('health-needs-you')), findsNothing);
    });

    testWidgets('all good: no Fix all', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const BetterTvTab(),
        scaffold: true,
        size: const Size(360, 1600),
        overrides: [
          ...env.overrides(),
          ...noAgent(),
          healthProvider.overrideWith(
            (ref) async => [sampleChecks(() {}).first],
          ),
        ],
      );
      await settle(tester);
      expect(find.text('All good'), findsOneWidget);
      expect(find.text('1 check passed'), findsOneWidget);
      expect(find.byKey(const Key('health-fix-all')), findsNothing);
    });

    testWidgets('without Home mode: preview cards that unlock', (tester) async {
      final env = await TestEnv.create(tvs: [castOnlySony]);
      await pumpScreen(
        tester,
        const BetterTvTab(),
        scaffold: true,
        size: const Size(360, 1600),
        overrides: [...env.overrides(), ...noAgent()],
      );
      await settle(tester);
      expect(find.byKey(const Key('better-tv-preview')), findsOneWidget);
      expect(find.text('Unlock Home mode'), findsOneWidget);
      expect(find.text('Unlock'), findsNWidgets(4));
      expect(find.byKey(const Key('health-summary')), findsNothing);
    });

    testWidgets('fits at 360 dp with 1.3× text', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const BetterTvTab(),
        scaffold: true,
        textScale: 1.3,
        size: const Size(360, 2400),
        overrides: [
          ...env.overrides(),
          ...noAgent(),
          healthProvider.overrideWith((ref) async => sampleChecks(() {})),
        ],
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('TV health in plain words', () {
    test('ops ids map to parent copy; ADB never shows', () {
      final looks = [for (final c in sampleChecks(() {})) healthLook(c)];
      expect(looks.map((l) => l.title), [
        'Home mode connection',
        'Clean TV',
        'YouTube without Shorts',
        'Home button',
      ]);
      expect(looks[1].detail, '2 promo and ad apps are back');
      for (final l in looks) {
        expect('${l.title} ${l.detail}', isNot(contains('ADB')));
      }
      expect(
        healthLook(
          const HealthCheck(
            id: 'speech',
            title: 'Speech services',
            status: HealthStatus.fail,
            detail: 'x',
          ),
        ).title,
        'Voice search',
      );
    });

    testWidgets('detail page: rows, Fix one, technical details',
        (tester) async {
      var fixed = 0;
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const HealthScreen(),
        size: const Size(360, 1400),
        overrides: [
          ...env.overrides(),
          ...noAgent(),
          healthProvider.overrideWith((ref) async => sampleChecks(() {
                fixed++;
              })),
        ],
      );
      await settle(tester);
      expect(find.text('Home mode connection'), findsOneWidget);
      expect(find.text('ADB connection'), findsNothing);
      await tester.tap(find.byKey(const Key('health-fix-cleanup')));
      await settle(tester);
      expect(find.text('Fix Clean TV?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Fix'),
        ),
      );
      await settle(tester);
      expect(fixed, 1);
      expect(find.text('Clean TV fixed'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('health-technical')));
      await settle(tester);
      expect(find.text('20/22 disabled (pending: a, b)'), findsOneWidget);
    });

    test('Always On checks get parent titles', () {
      final rows = agentHealthChecks(
        const AgentLink(
          AgentLinkKind.up,
          status: AgentStatus(
            agentId: 'a',
            version: '1',
            health: [
              AgentHealth(id: 'selfAdb', status: AgentHealthStatus.ok),
            ],
          ),
        ),
      );
      expect(healthLook(rows.first).title, 'Always On');
      expect(healthLook(rows.last).title, 'Can close apps on the TV');
    });
  });

  group('Clean TV', () {
    final profile = loadProfile('sony-bravia-vu3');

    test('groups the preview in plain words and skips absent apps', () {
      final status = CleanupStatus(
        present: const [
          'com.sony.dtv.promos',
          'com.android.adservices.api',
          'com.google.android.feedback',
          'com.sonyliv',
        ],
        disabled: const ['com.sony.dtv.promos'],
        pending: const [
          'com.android.adservices.api',
          'com.google.android.feedback',
          'com.sonyliv',
        ],
        absent: const ['com.sony.dtv.sonytab'],
      );
      final g = cleanGroups(profile, status);
      expect(g.keys, [
        CleanGroup.sony,
        CleanGroup.ads,
        CleanGroup.google,
        CleanGroup.optional,
      ]);
      expect(g[CleanGroup.sony]!.single.label, 'Sony promo banners');
      expect(g[CleanGroup.sony]!.single.state, CleanState.tidied);
      expect(g[CleanGroup.ads]!.single.label, 'Ad personalisation');
      expect(g[CleanGroup.ads]!.single.state, CleanState.showing);
      expect(g[CleanGroup.optional]!.single.pkg, 'com.sonyliv');
      expect(
        [for (final l in g.values) ...l].any(
          (i) => i.pkg == 'com.sony.dtv.sonytab',
        ),
        isFalse,
      );
    });

    testWidgets('preview, Fix tidies, Undo brings back', (tester) async {
      final tv = FakeTv()
        ..disabled.removeAll({
          'com.sony.dtv.promos',
          'com.android.adservices.api',
        });
      final env = await TestEnv.create(tvs: [adbSony]);
      final ops = TvOps(adb: tv, profile: profile, tvId: adbSony.id);
      final before = (await ops.cleanupStatus()).pending;
      expect(before, hasLength(2));
      await pumpScreen(
        tester,
        const CleanTvScreen(),
        size: const Size(360, 3000),
        overrides: [...env.overrides(ops: ops), ...noAgent()],
      );
      await settle(tester);
      for (final g in ['sony', 'ads', 'google']) {
        expect(find.byKey(Key('clean-group-$g')), findsOneWidget, reason: g);
      }
      final fix = find.byKey(const Key('clean-fix'));
      {
        expect(
            find.text('Tidy ${before.length} app'
                '${before.length == 1 ? '' : 's'}'),
            findsOneWidget);
        await tester.tap(fix);
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Tidy'),
          ),
        );
        await settle(tester, 10);
        await tester.tap(find.text('Done'));
        await settle(tester, 10);
        expect((await ops.cleanupStatus()).pending, isEmpty);
      }
      await tester.tap(find.byKey(const Key('clean-undo')));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Bring back'),
        ),
      );
      await settle(tester, 10);
      expect((await ops.cleanupStatus()).disabled, isEmpty);
    });
  });
}
