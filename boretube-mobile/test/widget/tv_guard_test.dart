import 'dart:async';
import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/screens/restore_screen.dart';
import 'package:boretube_mobile/screens/rules_tab.dart';
import 'package:boretube_mobile/screens/rules/rules_editor.dart';
import 'package:boretube_mobile/screens/tv/tv_guard_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../agent/agent_client_test.dart' show contractRules;
import '../agent/fake_agent.dart' show fakeBundle;
import '../ops/fake_tv.dart';
import 'helpers.dart';

AgentStatus agentStatus({
  AgentMode mode = AgentMode.normal,
  SelfAdb selfAdb = SelfAdb.ok,
  bool buildChanged = false,
}) =>
    AgentStatus(
      agentId: 'agent-1',
      version: '1.0.0',
      uptimeSec: 3 * 3600,
      selfAdb: selfAdb,
      mode: mode,
      activeRulesVersion: 3,
      buildFingerprint: 'Sony/BRAVIA_VU3/UKR1.240726.002',
      buildChangedSinceApproval: buildChanged,
      health: const [
        AgentHealth(
          id: 'youtube',
          status: AgentHealthStatus.ok,
          detail: 'Removed',
        ),
      ],
    );

List<Override> agentOverrides(AgentLink link, {bool missing = false}) => [
      agentStatusProvider
          .overrideWith((ref) => AgentStatusNotifier.fixed(link)),
      agentBundleLoaderProvider.overrideWithValue(
        () async => missing ? throw const AgentBundleMissing() : fakeBundle(),
      ),
    ];

void main() {
  group('TV Guard card', () {
    Future<void> pumpCard(
      WidgetTester tester,
      AgentLink link, {
      bool missing = false,
    }) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const SingleChildScrollView(child: TvGuardCard()),
        scaffold: true,
        overrides: [
          ...env.overrides(),
          ...agentOverrides(link, missing: missing),
        ],
      );
      await settle(tester);
    }

    testWidgets('not installed: explains and offers install', (tester) async {
      await pumpCard(tester, AgentLink.none);
      expect(find.byKey(const Key('tv-guard-invite')), findsOneWidget);
      expect(find.textContaining('even when your'), findsOneWidget);
      final b = tester.widget<FilledButton>(
        find.byKey(const Key('tv-guard-install')),
      );
      expect(b.onPressed, isNotNull);
    });

    testWidgets('bundle missing: install disabled with a reason',
        (tester) async {
      await pumpCard(tester, AgentLink.none, missing: true);
      final b = tester.widget<FilledButton>(
        find.byKey(const Key('tv-guard-install')),
      );
      expect(b.onPressed, isNull);
      expect(find.text(AgentBundleMissing.message), findsOneWidget);
    });

    testWidgets('on: version, mode and the kill switches', (tester) async {
      await pumpCard(
        tester,
        AgentLink(AgentLinkKind.up, status: agentStatus()),
      );
      expect(find.text('v1.0.0 · up 3 h'), findsOneWidget);
      expect(find.text('Enforcing'), findsOneWidget);
      expect(find.text('Allowed'), findsOneWidget);
      for (final k in ['pause', 'safe', 'repair', 'uninstall']) {
        expect(find.byKey(Key('tv-guard-$k')), findsOneWidget, reason: k);
      }
      expect(find.byKey(const Key('tv-guard-approve-banner')), findsNothing);
    });

    testWidgets('paused shows Resume; limited asks for Allow', (tester) async {
      await pumpCard(
        tester,
        AgentLink(
          AgentLinkKind.up,
          status: agentStatus(
            mode: AgentMode.paused,
            selfAdb: SelfAdb.needsApproval,
          ),
        ),
      );
      expect(find.byKey(const Key('tv-guard-resume')), findsOneWidget);
      expect(find.byKey(const Key('tv-guard-pause')), findsNothing);
      expect(find.textContaining('Always allow'), findsOneWidget);
    });

    testWidgets('safe mode offers to leave it', (tester) async {
      await pumpCard(
        tester,
        AgentLink(AgentLinkKind.up, status: agentStatus(mode: AgentMode.safe)),
      );
      expect(find.text('Leave safe mode'), findsOneWidget);
      expect(find.byKey(const Key('tv-guard-safe')), findsNothing);
      expect(find.text('🛟 Safe mode'), findsOneWidget);
    });

    testWidgets('down: red banner and Repair', (tester) async {
      await pumpCard(tester, const AgentLink(AgentLinkKind.down));
      expect(find.byKey(const Key('tv-guard-down')), findsOneWidget);
      expect(find.text('TV Guard down'), findsOneWidget);
      expect(find.byKey(const Key('tv-guard-repair')), findsOneWidget);
    });

    testWidgets('TV update pending approval', (tester) async {
      await pumpCard(
        tester,
        AgentLink(AgentLinkKind.up, status: agentStatus(buildChanged: true)),
      );
      expect(find.byKey(const Key('tv-guard-approve-banner')), findsOneWidget);
      expect(find.text('Approve this TV update'), findsOneWidget);
    });
  });

  group('install stepper', () {
    testWidgets('shows each step and the Look at the TV moment',
        (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      final c = StreamController<InstallProgress>();
      await pumpScreen(
        tester,
        AgentSetupSheet(title: 'Installing TV Guard', start: () => c.stream),
        scaffold: true,
        overrides: env.overrides(),
      );
      List<InstallStep> steps(
        Map<InstallStepId, SetupStepState> s, [
        String approveDetail = '',
      ]) =>
          [
            for (final id in AgentInstaller.installSteps)
              InstallStep(
                id,
                s[id] ?? SetupStepState.pending,
                id == InstallStepId.approve ? approveDetail : '',
              ),
          ];
      final done = {
        for (final id in AgentInstaller.installSteps.take(6))
          id: SetupStepState.done,
      };
      c.add(InstallProgress(steps: steps(done)));
      await settle(tester, 3);
      expect(find.text('Installing TV Guard'), findsOneWidget);
      expect(find.text('6/9'), findsOneWidget);
      expect(find.byKey(const Key('setup-look-at-tv')), findsNothing);

      c.add(
        InstallProgress(
          steps: steps(
            {...done, InstallStepId.approve: SetupStepState.waiting},
            'Look at the TV and choose "Always allow"',
          ),
        ),
      );
      await settle(tester, 3);
      expect(find.byKey(const Key('setup-look-at-tv')), findsOneWidget);
      expect(find.text('Look at the TV'), findsOneWidget);
      expect(find.text('Allow TV Guard on the TV'), findsOneWidget);

      c.add(
        InstallProgress(
          steps: steps({
            for (final id in AgentInstaller.installSteps)
              id: SetupStepState.done,
          }),
          finished: true,
          ok: true,
        ),
      );
      await settle(tester, 3);
      expect(find.byKey(const Key('setup-look-at-tv')), findsNothing);
      expect(find.text('TV Guard is ready'), findsOneWidget);
      expect(find.byKey(const Key('setup-done')), findsOneWidget);
      await c.close();
    });

    testWidgets('failure offers Try again', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      var runs = 0;
      await pumpScreen(
        tester,
        AgentSetupSheet(
          title: 'Repairing TV Guard',
          start: () {
            runs++;
            return Stream.value(
              const InstallProgress(
                steps: [
                  InstallStep(
                    InstallStepId.diagnose,
                    SetupStepState.failed,
                    'not answering',
                  ),
                ],
                finished: true,
                error: 'diagnose: not answering',
              ),
            );
          },
        ),
        scaffold: true,
        overrides: env.overrides(),
      );
      await settle(tester, 3);
      expect(find.text('Didn\'t finish'), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup-retry')));
      await settle(tester, 3);
      expect(runs, 2);
    });
  });

  group('Rules editor', () {
    late List<http.Request> sent;
    late Map<String, dynamic> onTv;
    late bool conflictOnce;

    http.Client mock() => MockClient((r) async {
          sent.add(r);
          if (r.url.path != '/v1/rules') return http.Response('{}', 404);
          if (r.method == 'GET') return http.Response(jsonEncode(onTv), 200);
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          if (conflictOnce || body['version'] != onTv['version']) {
            conflictOnce = false;
            return http.Response(jsonEncode(onTv), 409);
          }
          onTv = {...body, 'version': (body['version'] as int) + 1};
          return http.Response(jsonEncode(onTv), 200);
        });

    Future<void> pumpRules(WidgetTester tester) async {
      sent = [];
      onTv = {...contractRules};
      final env = await TestEnv.create(tvs: [adbSony]);
      await AgentTokenStore(env.secrets).write(adbSony.id, 'tok');
      await pumpScreen(
        tester,
        const RulesTab(),
        scaffold: true,
        size: const Size(360, 2400),
        overrides: [
          ...env.overrides(),
          agentStatusProvider.overrideWith(
            (ref) => AgentStatusNotifier.fixed(
              AgentLink(AgentLinkKind.up, status: agentStatus()),
            ),
          ),
          agentHttpClientProvider.overrideWithValue(mock()),
          rulesAuthorProvider.overrideWithValue('Test phone'),
          rulesClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 28, 19, 30),
          ),
        ],
      );
      await settle(tester);
    }

    testWidgets('loads the TV\'s rules and saves an edit with its version',
        (tester) async {
      conflictOnce = false;
      await pumpRules(tester);
      expect(find.text('Rules on Living Room TV'), findsOneWidget);
      expect(find.textContaining('Rakesh\'s Pixel'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
      expect(find.text('SmartTube'), findsOneWidget);
      expect(find.byKey(const Key('rules-save-bar')), findsNothing);

      await tester.tap(find.byKey(const Key('rules-always-mute')));
      await settle(tester);
      expect(find.byKey(const Key('rules-save-bar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('rules-save')));
      await settle(tester);

      final put = sent.lastWhere((r) => r.method == 'PUT');
      final body = jsonDecode(put.body) as Map<String, dynamic>;
      expect(body['version'], 3);
      expect(body['alwaysMute'], isTrue);
      expect(body['updatedBy'], 'Test phone');
      expect(body['updatedAt'], '2026-10-28T19:30:00.000Z');
      expect(find.text('Saved to the TV'), findsOneWidget);
      expect(find.byKey(const Key('rules-save-bar')), findsNothing);
      expect(find.text('v4'), findsOneWidget);
    });

    testWidgets('409: shows who changed it; Overwrite resends on top',
        (tester) async {
      conflictOnce = false;
      await pumpRules(tester);
      // Another phone saves version 4 meanwhile.
      onTv = {
        ...contractRules,
        'version': 4,
        'updatedBy': 'Other phone',
        'updatedAt': '2026-10-28T19:20:00.000Z',
      };
      await tester.tap(find.byKey(const Key('rules-always-mute')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('rules-save')));
      await settle(tester);

      expect(find.byKey(const Key('rules-conflict')), findsOneWidget);
      expect(find.text('TV has newer rules'), findsOneWidget);
      expect(find.textContaining('Changed by Other phone'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rules-overwrite')));
      await settle(tester);

      final puts = sent.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(2));
      final second = jsonDecode(puts[1].body) as Map<String, dynamic>;
      expect(second['version'], 4);
      expect(second['alwaysMute'], isTrue);
      expect(find.text('v5'), findsOneWidget);
    });

    testWidgets('409: Reload shows the TV\'s rules and drops the draft',
        (tester) async {
      conflictOnce = false;
      await pumpRules(tester);
      onTv = {
        ...contractRules,
        'version': 4,
        'updatedBy': 'Other phone',
        'style': 'explicit',
      };
      await tester.tap(find.byKey(const Key('rules-always-mute')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('rules-save')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('rules-reload')));
      await settle(tester);
      expect(sent.where((r) => r.method == 'PUT'), hasLength(1));
      expect(find.text('v4'), findsOneWidget);
      expect(find.textContaining('Other phone'), findsOneWidget);
      expect(find.byKey(const Key('rules-save-bar')), findsNothing);
      expect(find.textContaining('A friendly card'), findsOneWidget);
    });

    testWidgets('quick overrides save at once', (tester) async {
      conflictOnce = false;
      await pumpRules(tester);
      await tester.tap(find.byKey(const Key('rules-mute-30')));
      await settle(tester);
      final body = jsonDecode(
        sent.lastWhere((r) => r.method == 'PUT').body,
      ) as Map<String, dynamic>;
      final overrides = body['overrides'] as List;
      // The expired contract overrides are pruned; the new one is kept.
      expect(overrides, hasLength(1));
      expect(overrides.single['kind'], 'muteUntil');
      expect(overrides.single['until'], '2026-10-28T20:00:00.000Z');
      expect(find.textContaining('Muted · until'), findsOneWidget);
    });

    testWidgets('add a quiet-hours row', (tester) async {
      conflictOnce = false;
      await pumpRules(tester);
      expect(find.byKey(const Key('rules-schedule-1')), findsNothing);
      await tester.tap(find.byKey(const Key('rules-add-schedule')));
      await settle(tester);
      expect(find.byKey(const Key('rules-schedule-1')), findsOneWidget);
      expect(find.byKey(const Key('rules-save-bar')), findsOneWidget);
    });

    testWidgets('no TV Guard: explainer with install', (tester) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      await pumpScreen(
        tester,
        const RulesTab(),
        scaffold: true,
        overrides: [...env.overrides(), ...agentOverrides(AgentLink.none)],
      );
      await settle(tester);
      expect(find.text('Rules run on TV Guard'), findsOneWidget);
      expect(find.byKey(const Key('rules-install')), findsOneWidget);
    });
  });

  group('Restore TV', () {
    testWidgets('preview, typed confirmation, progress and summary',
        (tester) async {
      final tv = FakeTv();
      final env = await TestEnv.create(tvs: [adbSony]);
      final ops = TvOps(
        adb: tv,
        profile: loadProfile('sony-bravia-vu3'),
        tvId: adbSony.id,
      );
      await pumpScreen(
        tester,
        const RestoreScreen(),
        size: const Size(360, 6000),
        overrides: [
          ...env.overrides(ops: ops),
          ...agentOverrides(AgentLink.none),
        ],
      );
      await settle(tester);

      // Undo Boretube with an empty journal: nothing to do.
      expect(find.text('Nothing to change'), findsOneWidget);
      await tester.tap(find.byKey(const Key('restore-stock')));
      await settle(tester);
      expect(find.text('Turn on Sony promo banners'), findsOneWidget);
      expect(find.text('Put back YouTube'), findsOneWidget);
      expect(find.text('pm enable com.sony.dtv.promos'), findsNothing);
      await tester.tap(find.byKey(const Key('restore-show-commands')));
      await settle(tester);
      expect(find.text('pm enable com.sony.dtv.promos'), findsOneWidget);

      Finder run() => find.byKey(const Key('restore-run'));
      expect(tester.widget<FilledButton>(run()).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('restore-confirm')),
        'restor',
      );
      await settle(tester, 2);
      expect(tester.widget<FilledButton>(run()).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('restore-confirm')),
        'RESTORE',
      );
      await settle(tester, 2);
      expect(tester.widget<FilledButton>(run()).onPressed, isNotNull);
      expect(find.textContaining('23 steps'), findsOneWidget);

      tv.failing.add('pm enable com.sonyliv');
      await tester.tap(run());
      await settle(tester, 12);
      expect(find.byKey(const Key('restore-summary')), findsOneWidget);
      expect(find.text('22 of 23 steps worked'), findsOneWidget);
      expect(find.byKey(const Key('restore-ok')), findsNWidgets(22));
      expect(find.byKey(const Key('restore-failed')), findsOneWidget);
      expect(tv.disabled.contains('com.sony.dtv.promos'), isFalse);
      expect(tv.installed.contains('com.google.android.youtube.tv'), isTrue);
    });
  });
}
