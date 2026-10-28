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
import 'package:boretube_mobile/screens/tv/tv_guard_card.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/adb_guide_screen.dart';
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

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 8);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$name.png'),
    );
  }

  testWidgets('Now tab (ADB TV)', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        journalEntriesProvider.overrideWith((ref) async => journal),
      ],
    );
    await shot(tester, 'now_adb');
  });

  testWidgets('Now tab during a break', (tester) async {
    final t0 = DateTime(2026, 10, 28, 19);
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {
        BreakController.keyFor(adbSony.id):
            t0.add(const Duration(minutes: 12, seconds: 40)).toIso8601String(),
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
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
          clock: () => t0,
        ),
        journalEntriesProvider.overrideWith((ref) async => journal),
      ],
    );
    await shot(tester, 'now_break');
  });

  testWidgets('Now tab (Cast-only TV), 1.3× text', (tester) async {
    final env = await TestEnv.create(tvs: [castOnlySony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      textScale: 1.3,
      overrides: env.overrides(
        now: const NowPlaying(
          online: true,
          appName: 'Home screen',
          isHome: true,
          volume: 12,
          muted: true,
          source: 'cast',
        ),
        probeCaps: castOnlySony.capabilities,
      ),
    );
    await shot(tester, 'now_cast_only_text130');
  });

  testWidgets('Now tab scrolled to the Classic lock', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      size: const Size(360, 1700),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        journalEntriesProvider.overrideWith((ref) async => journal),
      ],
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('classic-mode-apps')));
    await shot(tester, 'now_full_classic_lock');
  });

  testWidgets('TV › Health', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        healthProvider.overrideWith((ref) async => checks),
      ],
    );
    await settle(tester);
    await tester.tap(find.text('TV'));
    await shot(tester, 'tv_health');
  });

  testWidgets('TV › Settings', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony, castOnlySony]);
    await env.store.setActive(adbSony.id);
    await pumpScreen(
      tester,
      const ShellScreen(),
      size: const Size(360, 1500),
      overrides: env.overrides(
        now: playing,
        probeCaps: adbSony.capabilities,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('TV'));
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await shot(tester, 'tv_settings');
  });

  testWidgets('Rules without TV Guard', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(AgentLink.none),
      ],
    );
    await settle(tester);
    await tester.tap(find.text('Rules'));
    await shot(tester, 'rules_no_guard');
  });

  testWidgets('Rules editor (TV Guard)', (tester) async {
    final now = DateTime(2026, 10, 28, 19, 5);
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      size: const Size(360, 2300),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(guardLink()),
        rulesProvider.overrideWith((ref) async => goldenRules(now)),
        rulesClockProvider.overrideWithValue(() => now),
      ],
    );
    await settle(tester);
    await tester.tap(find.text('Rules'));
    await settle(tester);
    // An unsaved edit shows the save bar.
    await tester.tap(find.byKey(const Key('rules-always-mute')));
    await shot(tester, 'rules');
  });

  testWidgets('TV › Health with TV Guard', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      size: const Size(360, 1500),
      overrides: [
        ...env.overrides(now: playing, probeCaps: adbSony.capabilities),
        ...guardOverrides(guardLink(buildChanged: true)),
        healthProvider.overrideWith((ref) async => checks),
      ],
    );
    await settle(tester);
    await tester.tap(find.text('TV'));
    await shot(tester, 'tv_guard_card');
  });

  testWidgets('TV Guard install stepper', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final c = StreamController<InstallProgress>();
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showAgentSetupSheet(
              context,
              title: 'Installing TV Guard',
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
    await shot(tester, 'tv_guard_install');
    await c.close();
  });

  testWidgets('Restore TV', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    final fake = FakeTv();
    await pumpScreen(
      tester,
      const RestoreScreen(),
      size: const Size(360, 2600),
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
    await shot(tester, 'restore');
  });

  testWidgets('Now tab: break enforced by TV Guard', (tester) async {
    final t0 = DateTime(2026, 10, 28, 19);
    final env = await TestEnv.create(
      tvs: [adbSony],
      prefs: {
        BreakController.keyFor(adbSony.id):
            t0.add(const Duration(minutes: 24, seconds: 10)).toIso8601String(),
        BreakController.flagsKeyFor(adbSony.id): 'tv',
      },
    );
    await pumpScreen(
      tester,
      const ShellScreen(),
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
          clock: () => t0,
        ),
        ...guardOverrides(guardLink()),
        journalEntriesProvider.overrideWith((ref) async => journal),
      ],
    );
    await shot(tester, 'now_break_tv');
  });

  testWidgets('Lock screen', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await PinStore(store: env.secrets).setPin('1357');
    await pumpScreen(tester, const LockScreen(), overrides: env.overrides());
    await settle(tester);
    await tester.tap(find.byKey(const Key('pin-key-1')));
    await tester.tap(find.byKey(const Key('pin-key-3')));
    await shot(tester, 'lock');
  });

  testWidgets('Onboarding welcome', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(),
      overrides: env.overrides(),
    );
    await shot(tester, 'onboarding_welcome');
  });

  testWidgets('Onboarding › Find TVs', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
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
    await shot(tester, 'onboarding_find');
  });

  testWidgets('Onboarding › Connect (capabilities)', (tester) async {
    final env = await TestEnv.create();
    await pumpScreen(
      tester,
      const OnboardingScreen(addMode: true),
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
        probeCaps: {
          TvCapability.cast,
          TvCapability.dial,
          TvCapability.sonyRest,
        },
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Living Room TV'));
    await shot(tester, 'onboarding_connect');
  });

  testWidgets('ADB guide › Look at the TV', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const AdbGuideScreen(),
      overrides: [
        ...env.overrides(keyPending: true),
        adbStateProvider.overrideWith(
          (ref) => Stream.value(const AdbAwaitingApproval()),
        ),
      ],
    );
    await settle(tester);
    await shot(tester, 'adb_steps');
    await tester.tap(find.byKey(const Key('adb-connect')));
    await shot(tester, 'adb_look_at_tv');
  });
}
