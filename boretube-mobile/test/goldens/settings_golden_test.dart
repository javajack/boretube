// Settings (light and dark) on a 360 dp phone, Advanced open.
// Regenerate with: flutter test --update-goldens test/goldens
@Tags(['golden'])
library;

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/screens/settings_screen.dart';
import 'package:boretube_mobile/watch/always_on_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';
import '../watch/fakes.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final dark in [false, true]) {
    testWidgets('Settings (${dark ? 'dark' : 'light'})', (tester) async {
      final env = await TestEnv.create(
        tvs: [adbSony, castOnlySony],
        prefs: {kAlertsKey: true},
      );
      await env.store.setActive(adbSony.id);
      await pumpScreen(
        tester,
        const SettingsScreen(),
        dark: dark,
        size: const Size(360, 3300),
        overrides: [
          ...env.overrides(probeCaps: adbSony.capabilities),
          alertNotifierProvider.overrideWithValue(FakeAlertNotifier()),
          watchSchedulerProvider.overrideWithValue(FakeScheduler()),
          agentStatusProvider.overrideWith(
            (ref) => AgentStatusNotifier.fixed(
              AgentLink(
                AgentLinkKind.up,
                status: const AgentStatus(
                  agentId: 'agent-1',
                  version: '1.0.1',
                ),
                lastOk: DateTime(2026, 10, 29, 20),
              ),
            ),
          ),
        ],
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('settings-advanced')));
      await settle(tester, 8);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('settings_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
