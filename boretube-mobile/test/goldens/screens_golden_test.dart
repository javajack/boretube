// Screenshots of the main screens on a 360×800 dp phone for visual review.
// Regenerate with: flutter test --update-goldens test/goldens
@Tags(['golden'])
library;

import 'dart:async';

import 'package:boretube_mobile/adb/adb_session.dart';
import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/screens/restore_screen.dart';
import 'package:boretube_mobile/screens/rules_tab.dart';
import 'package:boretube_mobile/screens/rules/rules_editor.dart';
import 'package:boretube_mobile/screens/tv/apps_section.dart';
import 'package:boretube_mobile/screens/tv/clean_tv.dart';
import 'package:boretube_mobile/screens/tv/tv_guard_card.dart';
import 'package:boretube_mobile/ui/components.dart';
import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/adb_guide_screen.dart';
import 'package:boretube_mobile/screens/history_screen.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/tv/capabilities.dart';
import 'package:boretube_mobile/screens/lock_screen.dart';
import 'package:boretube_mobile/screens/onboarding_screen.dart';
import 'package:boretube_mobile/screens/shell_screen.dart';
import 'package:boretube_mobile/security/pin_store.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../agent/fake_agent.dart' show fakeBundle;
import '../ops/fake_tv.dart';
import '../widget/helpers.dart';

AgentLink guardLink({
  bool buildChanged = false,
  bool breakActive = false,
  DateTime? endsAt,
}) =>
    AgentLink(
      AgentLinkKind.up,
      lastOk: DateTime.now(),
      status: AgentStatus(
        agentId: 'agent-1',
        version: '1.0.0',
        uptimeSec: 5 * 3600,
        activeRulesVersion: 7,
        soundPath: 'audioManager',
        buildFingerprint:
            'Sony/BRAVIA_VU3/BRAVIA_VU3:14/UKR1.240726.002/2411:user',
        buildChangedSinceApproval: buildChanged,
        watchdogPending: buildChanged ? 3 : 0,
        activeReasons: const ['Volume capped at 30%'],
        breakState: AgentBreak(active: breakActive, endsAt: endsAt),
        health: const [
          AgentHealth(
            id: 'usageAccess',
            status: AgentHealthStatus.ok,
            detail: 'Granted',
          ),
          AgentHealth(
            id: 'watchdog',
            status: AgentHealthStatus.warn,
            detail: '3 clean-up changes wait for approval',
          ),
        ],
      ),
    );

List<Override> guardOverrides(AgentLink link) => [
      agentStatusProvider
          .overrideWith((ref) => AgentStatusNotifier.fixed(link)),
      agentBundleLoaderProvider.overrideWithValue(() async => fakeBundle()),
    ];

AgentRules goldenRules(DateTime now) => AgentRules(
      version: 7,
      updatedBy: 'Rakesh\'s Pixel',
      updatedAt: DateTime.now()
          .subtract(const Duration(hours: 2))
          .toUtc()
          .toIso8601String(),
      allowedApps: const AllowedApps(
        mode: AppsMode.allowlist,
        packages: ['org.smarttube.stable', 'com.netflix.ninja'],
      ),
      volumeLimit: const VolumeLimit(maxPercent: 30, enabled: true),
      tvTime: const TvTime(
        schedule: [
          ScheduleRow(days: [1, 2, 3, 4, 5], from: '21:00', to: '07:00'),
          ScheduleRow(days: [6, 7], from: '22:30', to: '08:00'),
        ],
        dailyLimitMin: 120,
      ),
      overrides: [
        RuleOverride(
          kind: OverrideKind.muteUntil,
          until: now.add(const Duration(minutes: 25)).toUtc().toIso8601String(),
        ),
      ],
    );

const playing = NowPlaying(
  online: true,
  id: 'org.smarttube.stable',
  appName: 'SmartTube',
  volume: 24,
  muted: false,
  source: 'adb',
);

final journal = [
  JournalEntry(
    tvId: adbSony.id,
    time: DateTime.now().subtract(const Duration(minutes: 3)),
    op: 'stopApp',
    target: 'org.smarttube.stable',
    before: 'pid 3479',
    after: 'not running',
    ok: true,
  ),
  JournalEntry(
    tvId: adbSony.id,
    time: DateTime.now().subtract(const Duration(hours: 2)),
    op: 'applyCleanup',
    target: 'com.google.android.youtube.tvmusic',
    before: 'enabled',
    after: 'disabled',
    ok: true,
  ),
];

final checks = [
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
    detail: '20/22 disabled (pending: tvrecommendations, partnerbrowser)',
    fix: () async {},
  ),
  HealthCheck(
    id: 'stockYouTube',
    title: 'Stock YouTube',
    status: HealthStatus.warn,
    detail: 'Installed',
    fix: () async {},
  ),
  const HealthCheck(
    id: 'speech',
    title: 'Speech services',
    status: HealthStatus.ok,
    detail: 'At known-good version (20251028)',
  ),
  const HealthCheck(
    id: 'launcher',
    title: 'Home launcher',
    status: HealthStatus.ok,
    detail: 'Home opens the launcher',
  ),
];

/// A Wednesday, ten to seven in the evening: bedtime is at nine.
final evening = DateTime(2026, 10, 28, 18, 50);

final agentJournal = [
  AgentJournalEntry(
    time: DateTime.now().subtract(const Duration(hours: 1)),
    op: 'closeApp',
    target: 'com.google.android.youtube.tv',
    before: 'schedule',
    after: 'home',
    ok: true,
    source: JournalSource.rule,
  ),
  AgentJournalEntry(
    time: DateTime.now().subtract(const Duration(minutes: 50)),
    op: 'closeApp',
    target: 'com.google.android.youtube.tv',
    before: 'schedule',
    after: 'home',
    ok: true,
    source: JournalSource.rule,
  ),
  AgentJournalEntry(
    time: DateTime.now().subtract(const Duration(minutes: 40)),
    op: 'closeApp',
    target: 'com.google.android.youtube.tv',
    before: 'schedule',
    after: 'home',
    ok: true,
    source: JournalSource.rule,
  ),
];

CapabilityProber quietProber() => CapabilityProber(
      adbProbe: (_, __, ___) async => const ProbeOutcome(false, 'closed'),
    );

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 8);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$name.png'),
    );
  }

  /// Runs [body] once per theme; goldens get a _light / _dark suffix.
  void both(
    String description,
    Future<void> Function(WidgetTester tester, bool dark, String suffix) body,
  ) {
    for (final dark in [false, true]) {
      testWidgets('$description (${dark ? 'dark' : 'light'})',
          (tester) => body(tester, dark, dark ? '_dark' : '_light'));
    }
  }

  List<Override> homeOverrides(TestEnv env, {AgentLink? link}) => [
        ...env.overrides(
          now: playing,
          probeCaps: adbSony.capabilities,
          clock: () => evening,
        ),
        journalEntriesProvider.overrideWith((ref) async => journal),
        if (link != null) ...[
          ...guardOverrides(link),
          rulesProvider.overrideWith((ref) async => goldenRules(evening)),
        ],
      ];

  both('Home · calm, Always On', (tester, dark, sfx) async {
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {
        GoalsNotifier.key: ['shorts', 'bedtime'],
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1100),
      overrides: homeOverrides(env, link: guardLink()),
    );
    await shot(tester, 'home_calm$sfx');
  });

  AgentLink mediaLink({bool armed = false}) {
    final base = guardLink().status!;
    return AgentLink(
      AgentLinkKind.up,
      lastOk: DateTime.now(),
      status: AgentStatus(
        agentId: base.agentId,
        version: '1.1.0',
        uptimeSec: base.uptimeSec,
        activeRulesVersion: base.activeRulesVersion,
        health: base.health,
        media: const AgentMedia(
          pkg: 'org.smarttube.stable',
          title: 'Bluey · The Creek | Full Episode',
          artist: 'Bluey - Official Channel',
          state: MediaState.playing,
          positionMs: 312000,
          durationMs: 1260000,
          remainingMs: 948000,
          source: MediaSource.listener,
        ),
        endAfter: armed
            ? AgentEndAfter(
                armed: true,
                title: 'Bluey · The Creek | Full Episode',
                pkg: 'org.smarttube.stable',
                capAt: evening.add(const Duration(minutes: 45)),
                breakMin: 60,
              )
            : const AgentEndAfter(),
        shorts: const AgentShorts(mode: ShortsMode.budget, todayCount: 3),
      ),
    );
  }

  both('Home · what\'s playing, When this ends', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1100),
      overrides: homeOverrides(env, link: mediaLink()),
    );
    await shot(tester, 'home_media_playing$sfx');
  });

  both('Home · pausing after this one', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1100),
      overrides: homeOverrides(env, link: mediaLink(armed: true)),
    );
    await shot(tester, 'home_end_after_armed$sfx');
  });

  testWidgets('Home · Home mode with the plan', (tester) async {
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {
        GoalsNotifier.key: ['ads'],
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
      size: const Size(360, 1500),
      overrides: [
        ...homeOverrides(env),
        ...guardOverrides(AgentLink.none),
      ],
    );
    await shot(tester, 'home_plan_light');
  });

  both('Home · paused, kept by the TV', (tester, dark, sfx) async {
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {
        BreakController.keyFor(adbSony.id): evening
            .add(const Duration(minutes: 12, seconds: 40))
            .toIso8601String(),
        BreakController.flagsKeyFor(adbSony.id): 'tv',
        BreakStartLog.keyFor(adbSony.id):
            evening.subtract(const Duration(minutes: 17)).toIso8601String(),
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      overrides: [
        ...env.overrides(
          now: const NowPlaying(
            online: true,
            appName: 'Home screen',
            isHome: true,
            volume: 24,
            muted: true,
            source: 'adb',
          ),
          probeCaps: adbSony.capabilities,
          clock: () => evening,
        ),
        ...guardOverrides(guardLink()),
        rulesProvider.overrideWith((ref) async => goldenRules(evening)),
        journalEntriesProvider.overrideWith(
          (ref) async => [
            JournalEntry(
              tvId: adbSony.id,
              time: evening.subtract(const Duration(minutes: 12)),
              op: 'break',
              target: 'closed SmartTube',
              before: '',
              after: 'done via adb',
              ok: true,
            ),
          ],
        ),
      ],
    );
    await shot(tester, 'home_paused$sfx');
  });

  testWidgets('Home · paused from this phone', (tester) async {
    final env = await TestEnv.create(
      tvs: [castOnlySony],
      prefs: {
        BreakController.keyFor(castOnlySony.id): evening
            .add(const Duration(minutes: 29, seconds: 5))
            .toIso8601String(),
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: env.overrides(
        now: const NowPlaying(
          online: true,
          appName: 'Home screen',
          isHome: true,
          muted: true,
          source: 'cast',
        ),
        probeCaps: castOnlySony.capabilities,
        clock: () => evening,
      ),
    );
    await shot(tester, 'home_paused_phone_light');
  });

  both('Home · something broke, while you were away',
      (tester, dark, sfx) async {
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {
        'app.lastVisit':
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1100),
      overrides: [
        ...homeOverrides(env, link: const AgentLink(AgentLinkKind.down)),
        agentJournalProvider.overrideWith((ref) async => agentJournal),
      ],
    );
    await shot(tester, 'home_problem$sfx');
  });

  testWidgets('Home · TV off', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: env.overrides(
        now: NowPlaying(
          lastSeen: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
        probeCaps: adbSony.capabilities,
      ),
    );
    await shot(tester, 'home_offline_light');
  });

  testWidgets('Home · Remote TV, 1.3× text', (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      textScale: 1.3,
      overrides: env.overrides(
        now: const NowPlaying(
          online: true,
          id: 'com.netflix.ninja',
          appName: 'Netflix',
          volume: 12,
          muted: false,
          source: 'cast',
        ),
        probeCaps: castOnlySony.capabilities,
      ),
    );
    await shot(tester, 'home_remote_text130_light');
  });

  both('What works right now (Home mode)', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      overrides: [...homeOverrides(env), ...guardOverrides(AgentLink.none)],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('mode-badge')));
    await shot(tester, 'what_works$sfx');
  });

  testWidgets('Volume sheet', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: [...homeOverrides(env), ...guardOverrides(AgentLink.none)],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('action-volume')));
    await shot(tester, 'volume_sheet_light');
  });

  both('Routines · Lock for a while', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 800),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(AgentLink.none),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab-Routines')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('classic-what')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('classic-mode-apps')));
    await settle(tester);
    await shot(tester, 'routines_lock_sheet$sfx');
    await tester.tap(find.byKey(const Key('classic-sheet-done')));
    await settle(tester);
    await shot(tester, 'routines_lock$sfx');
  });

  both('Routines (Always On rules)', (tester, dark, sfx) async {
    final now = DateTime(2026, 10, 28, 19, 5);
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1000),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(guardLink()),
        rulesProvider.overrideWith((ref) async => goldenRules(now)),
        rulesClockProvider.overrideWithValue(() => now),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab-Routines')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('rules-always-mute')));
    await settle(tester);
    await shot(tester, 'routines_rules$sfx');
    await tester.tap(find.byKey(const Key('rules-tv-time')));
    await settle(tester);
    await shot(tester, 'routines_bedtime$sfx');
  });

  both('Routines · Video hopping', (tester, dark, sfx) async {
    final now = DateTime(2026, 10, 28, 19, 5);
    final env = await TestEnv.create(tvs: [adbSony]);
    final rules = goldenRules(now).copyWith(
      style: RuleStyle.explicit,
      shorts: const ShortsRule(mode: ShortsMode.cooldown),
    );
    final link = guardLink();
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1000),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(
          AgentLink(
            AgentLinkKind.up,
            lastOk: link.lastOk,
            status: AgentStatus(
              agentId: 'agent-1',
              version: '1.3.0',
              shorts: AgentShorts(
                mode: ShortsMode.cooldown,
                todayCount: 4,
                lastDetectedAt: DateTime(2026, 10, 28, 18, 42),
              ),
            ),
          ),
        ),
        rulesProvider.overrideWith((ref) async => rules),
        rulesClockProvider.overrideWithValue(() => now),
        routinesFocusProvider.overrideWith((ref) => 'shorts'),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab-Routines')));
    await settle(tester);
    await shot(tester, 'routines_shorts$sfx');
  });

  both('Better TV · health with Always On', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      dark: dark,
      size: const Size(360, 1500),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(guardLink(buildChanged: true)),
        healthProvider.overrideWith((ref) async => checks),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab-Better TV')));
    await shot(tester, 'better_tv$sfx');
  });

  testWidgets('Better TV · Remote only, preview cards', (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      size: const Size(360, 1300),
      overrides: [
        ...env.overrides(probeCaps: castOnlySony.capabilities),
        ...guardOverrides(AgentLink.none),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab-Better TV')));
    await shot(tester, 'better_tv_preview_light');
  });

  both('Always On card', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [TvGuardCard(), SizedBox(height: 16), _InviteCard()],
        ),
      ),
      scaffold: true,
      dark: dark,
      size: const Size(360, 1250),
      overrides: [
        ...env.overrides(),
        ...guardOverrides(guardLink(buildChanged: true)),
      ],
    );
    await shot(tester, 'always_on_card$sfx');
  });

  both('Clean TV', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const CleanTvScreen(),
      dark: dark,
      size: const Size(360, 1900),
      overrides: [
        ...env.overrides(
          ops: TvOps(
            adb: FakeTv(),
            profile: loadProfile('sony-bravia-vu3'),
            tvId: adbSony.id,
          ),
        ),
        ...guardOverrides(AgentLink.none),
      ],
    );
    await shot(tester, 'clean_tv$sfx');
  });

  testWidgets('YouTube without Shorts', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const YouTubeScreen(),
      size: const Size(360, 1000),
      overrides: [
        ...env.overrides(
          ops: TvOps(
            adb: FakeTv(),
            profile: loadProfile('sony-bravia-vu3'),
            tvId: adbSony.id,
          ),
        ),
        ...guardOverrides(guardLink()),
        rulesProvider.overrideWith((ref) async => goldenRules(evening)),
      ],
    );
    await shot(tester, 'youtube_light');
  });

  testWidgets('Rules conflict sheet', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final mine = goldenRules(evening);
    final theirs = mine.copyWith(
      version: 8,
      updatedBy: 'Priya\'s phone',
      updatedAt: DateTime(2026, 10, 28, 19, 20).toUtc().toIso8601String(),
      alwaysMute: true,
      volumeLimit: const VolumeLimit(maxPercent: 20, enabled: true),
    );
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showBtSheet<void>(
              context,
              builder: (_) => ConflictSheet(theirs: theirs, mine: mine),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      scaffold: true,
      overrides: env.overrides(),
    );
    await tester.tap(find.text('open'));
    await shot(tester, 'rules_conflict_light');
  });

  testWidgets('History', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const HistoryScreen(),
      overrides: [
        ...env.overrides(),
        journalEntriesProvider.overrideWith((ref) async => journal),
      ],
    );
    await shot(tester, 'history_light');
  });

  testWidgets('Always On setup stepper', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final c = StreamController<InstallProgress>();
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showAgentSetupSheet(
              context,
              title: 'Setting up Always On',
              start: () => c.stream,
            ),
            child: const Text('open'),
          ),
        ),
      ),
      scaffold: true,
      overrides: env.overrides(),
    );
    await tester.tap(find.text('open'));
    await settle(tester, 4);
    c.add(
      InstallProgress(
        steps: [
          for (final id in AgentInstaller.installSteps)
            InstallStep(
              id,
              switch (id) {
                InstallStepId.approve => SetupStepState.waiting,
                InstallStepId.profile ||
                InstallStepId.check =>
                  SetupStepState.pending,
                InstallStepId.grant => SetupStepState.warn,
                _ => SetupStepState.done,
              },
              switch (id) {
                InstallStepId.verify => 'v1.0.0 · 1016 KB · checksum OK',
                InstallStepId.push => '1016 KB copied',
                InstallStepId.install => 'Installed',
                InstallStepId.grant => 'Not granted: WRITE_SECURE_SETTINGS',
                InstallStepId.start => 'Running',
                InstallStepId.token => 'Paired',
                InstallStepId.approve =>
                  'Look at the TV and choose "Always allow"',
                _ => '',
              },
            ),
        ],
      ),
    );
    await shot(tester, 'always_on_setup_light');
    await c.close();
  });

  both('Put the TV back', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final fake = FakeTv();
    await pumpScreen(
      tester,
      const RestoreScreen(),
      dark: dark,
      size: const Size(360, 2800),
      overrides: [
        ...env.overrides(
          ops: TvOps(
            adb: fake,
            profile: loadProfile('sony-bravia-vu3'),
            tvId: adbSony.id,
            clock: () => DateTime(2026, 10, 28, 12),
          ),
        ),
        ...guardOverrides(AgentLink.none),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('restore-stock')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('restore-helper')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('restore-show-commands')));
    await settle(tester, 12);
    final confirm = find.byKey(const Key('restore-confirm'));
    if (confirm.evaluate().isNotEmpty) {
      await tester.enterText(confirm, 'RESTORE');
    }
    await shot(tester, 'restore$sfx');
  });

  both('Lock screen', (tester, dark, sfx) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await PinStore(store: env.secrets).setPin('1357');
    await pumpScreen(
      tester,
      const LockScreen(),
      dark: dark,
      overrides: env.overrides(),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('pin-key-1')));
    await tester.tap(find.byKey(const Key('pin-key-3')));
    await shot(tester, 'lock$sfx');
  });

  both('Onboarding · welcome', (tester, dark, sfx) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(),
      dark: dark,
      overrides: env.overrides(),
    );
    await shot(tester, 'onboarding_welcome$sfx');
  });

  both('Onboarding · find your TV', (tester, dark, sfx) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      dark: dark,
      overrides: env.overrides(
        discovery: FakeDiscovery(
          const [
            Tv(
              id: 'udn:a',
              name: 'Living Room TV',
              manufacturer: 'Sony',
              model: 'BRAVIA VU3',
              ip: '192.168.1.3',
            ),
            Tv(
              id: 'udn:b',
              name: 'Bedroom TV',
              manufacturer: 'TCL',
              model: 'C645',
              ip: '192.168.1.7',
            ),
          ],
          keepSearching: true,
        ),
      ),
    );
    await shot(tester, 'onboarding_find$sfx');
  });

  both('Onboarding · first win', (tester, dark, sfx) async {
    final env = await TestEnv.create();
    final actions = ScriptedActions();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
      dark: dark,
      overrides: env.overrides(
        discovery: FakeDiscovery(const [
          Tv(
            id: 'udn:a',
            name: 'Living Room TV',
            manufacturer: 'Sony',
            model: 'BRAVIA VU3',
            ip: '192.168.1.3',
          ),
        ]),
        probeCaps: {TvCapability.cast, TvCapability.dial},
        actions: actions,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);
    await shot(tester, 'onboarding_first_win$sfx');
    await tester.tap(find.byKey(const Key('first-win-mute')));
    await tester.pump();
    actions.answer(const ActionResult(true, ActionTransport.cast));
    await settle(tester, 25);
    await shot(tester, 'onboarding_first_win_done$sfx');
  });

  both('Onboarding · goals', (tester, dark, sfx) async {
    final env = await TestEnv.create(
      prefs: {
        GoalsNotifier.key: ['shorts', 'bedtime'],
      },
    );
    await pumpScreen(
      tester,
      const OnboardingScreen(),
      dark: dark,
      overrides: env.overrides(
        discovery: FakeDiscovery(const [
          Tv(id: 'udn:a', name: 'Living Room TV', ip: '192.168.1.3'),
        ]),
        probeCaps: {TvCapability.cast},
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await settle(tester, 10);
    await tester.ensureVisible(find.byKey(const Key('first-win-continue')));
    await tester.tap(find.byKey(const Key('first-win-continue')));
    await shot(tester, 'onboarding_goals$sfx');
  });

  Future<void> guideAt(
    WidgetTester tester, {
    required int step,
    int presses = 0,
    bool dark = false,
    List<Override> extra = const [],
  }) async {
    final env = await TestEnv.create(
      tvs: [castOnlySony],
      prefs: {
        HelperProgress.keyFor(castOnlySony.id): step,
        HelperProgress.presses(castOnlySony.id): presses,
      },
    );
    await pumpScreen(
      tester,
      const AdbGuideScreen(),
      dark: dark,
      overrides: [
        ...env.overrides(keyPending: true, prober: quietProber()),
        ...extra,
      ],
    );
    await settle(tester);
  }

  both('Home mode guide · why', (tester, dark, sfx) async {
    await guideAt(tester, step: 0, dark: dark);
    await shot(tester, 'helper_why$sfx');
  });

  both('Home mode guide · press OK 7 times', (tester, dark, sfx) async {
    await guideAt(tester, step: 2, presses: 3, dark: dark);
    await shot(tester, 'helper_press_ok$sfx');
  });

  both('Home mode guide · rehearse the prompt', (tester, dark, sfx) async {
    await guideAt(tester, step: 4, dark: dark);
    await shot(tester, 'helper_rehearse$sfx');
  });

  both('Home mode guide · look at your TV', (tester, dark, sfx) async {
    await guideAt(
      tester,
      step: 4,
      dark: dark,
      extra: [
        adbStateProvider.overrideWith(
          (ref) => Stream.value(const AdbAwaitingApproval()),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('adb-connect')));
    await shot(tester, 'helper_look_at_tv$sfx');
  });
}

/// The not-installed invitation, shown under the installed card.
class _InviteCard extends StatelessWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: [
          agentStatusProvider
              .overrideWith((ref) => AgentStatusNotifier.fixed(AgentLink.none)),
        ],
        child: const TvGuardCard(),
      );
}
