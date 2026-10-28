// Screenshots of the main screens on a 360×800 dp phone for visual review.
// Regenerate with: flutter test --update-goldens test/goldens
@Tags(['golden'])
library;

import 'package:boretube_mobile/adb/adb_session.dart';
import 'package:boretube_mobile/ops/health.dart';
import 'package:boretube_mobile/ops/journal.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/providers/tv_providers.dart';
import 'package:boretube_mobile/screens/adb_guide_screen.dart';
import 'package:boretube_mobile/screens/lock_screen.dart';
import 'package:boretube_mobile/screens/onboarding_screen.dart';
import 'package:boretube_mobile/screens/shell_screen.dart';
import 'package:boretube_mobile/security/pin_store.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

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

  testWidgets('Rules placeholder', (tester) async {
    final env = await TestEnv.create(tvs: [adbSony]);
    await pumpScreen(
      tester,
      const ShellScreen(),
      overrides: env.overrides(now: playing, probeCaps: adbSony.capabilities),
    );
    await settle(tester);
    await tester.tap(find.text('Rules'));
    await shot(tester, 'rules');
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
