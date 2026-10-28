import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:boretube_mobile/models/tv_status.dart';
import 'package:boretube_mobile/models/whitelist_entry.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/providers.dart';
import 'package:boretube_mobile/screens/now/classic_lock_card.dart';
import 'package:boretube_mobile/screens/rules/presets.dart';
import 'package:boretube_mobile/screens/rules/rules_editor.dart';
import 'package:boretube_mobile/screens/rules_tab.dart';
import 'package:boretube_mobile/services/tv_service.dart';
import 'package:boretube_mobile/ui/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../agent/agent_client_test.dart' show contractRules;
import 'helpers.dart';

/// Records what Lock for a while asks the service to do.
class RecordingLockService extends FakeLockService {
  Map<String, Object>? started;

  @override
  Future<void> start({
    required String host,
    required int castPort,
    required int dialPort,
    required bool lockApps,
    required bool lockVolume,
    required int maxVolume,
    required int intervalSeconds,
    required int durationMinutes,
    required List<WhitelistEntry> whitelist,
  }) async {
    started = {
      'host': host,
      'lockApps': lockApps,
      'lockVolume': lockVolume,
      'maxVolume': maxVolume,
      'interval': intervalSeconds,
      'duration': durationMinutes,
      'whitelist': [for (final e in whitelist) e.appId],
    };
  }
}

class FixedTvService extends TvService {
  final TvStatus? status;
  FixedTvService(this.status) : super(host: '192.168.1.3');

  @override
  Future<TvStatus?> getStatus() async => status;
}

void main() {
  group('presets', () {
    const base = AgentRules(
      version: 4,
      allowedApps: AllowedApps(
        mode: AppsMode.allowlist,
        packages: ['org.smarttube.stable'],
      ),
      stockYouTubeAllowed: true,
      overrides: [
        RuleOverride(kind: OverrideKind.muteUntil, until: '2099-01-01'),
      ],
    );

    test('each preset applied is detected as itself', () {
      for (final p in RulePreset.values) {
        expect(detectPreset(applyPreset(base, p)), p, reason: p.name);
      }
    });

    test('a preset keeps apps, stock YouTube and Tonight only', () {
      final r = applyPreset(base, RulePreset.schoolNight);
      expect(r.allowedApps.packages, ['org.smarttube.stable']);
      expect(r.allowedApps.mode, AppsMode.allowlist);
      expect(r.stockYouTubeAllowed, isTrue);
      expect(r.overrides, hasLength(1));
      expect(r.version, 4);
    });

    test('window order does not matter; any edit makes it Custom', () {
      final r = applyPreset(base, RulePreset.weekend);
      final flipped = r.copyWith(
        tvTime: r.tvTime.copyWith(
          schedule: r.tvTime.schedule.reversed.toList(),
        ),
      );
      expect(detectPreset(flipped), RulePreset.weekend);
      expect(
        detectPreset(r.copyWith(tvTime: r.tvTime.copyWith(dailyLimitMin: 45))),
        isNull,
      );
      expect(detectPreset(r.copyWith(alwaysMute: true)), isNull);
      expect(detectPreset(r.copyWith(style: RuleStyle.sneaky)), isNull);
      expect(
        detectPreset(
          r.copyWith(volumeLimit: const VolumeLimit(maxPercent: 55)),
        ),
        isNull,
      );
      expect(detectPreset(base), isNull);
      expect(isBlankRoutine(base), isTrue);
    });

    test('days and summaries read naturally', () {
      expect(daysLabel([1, 2, 3, 4, 7]), 'Sun–Thu');
      expect(daysLabel([5, 6]), 'Fri & Sat');
      expect(daysLabel([1, 2, 3, 4, 5]), 'Weekdays');
      expect(daysLabel([1, 3]), 'Mon, Wed');
      expect(daysLabel([1, 2, 3, 4, 5, 6, 7]), 'Every day');
      expect(
        shapeSummary(RulePreset.schoolNight.shape).first,
        'Bedtime Sun–Thu: 9:00 pm – 7:00 am',
      );
      expect(
        rulesDiff(base, base.copyWith(alwaysMute: true)),
        ['Keep it silent'],
      );
    });
  });

  group('Routines with Always On', () {
    late List<http.Request> sent;
    late Map<String, dynamic> onTv;

    http.Client mock() => MockClient((r) async {
          sent.add(r);
          if (r.method == 'GET') return http.Response(jsonEncode(onTv), 200);
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          onTv = {...body, 'version': (body['version'] as int) + 1};
          return http.Response(jsonEncode(onTv), 200);
        });

    Future<void> pump(
      WidgetTester tester,
      Map<String, dynamic> rules, {
      double textScale = 1,
    }) async {
      sent = [];
      onTv = rules;
      final env = await TestEnv.create(tvs: [adbSony]);
      await AgentTokenStore(env.secrets).write(adbSony.id, 'tok');
      await pumpScreen(
        tester,
        const RulesTab(),
        scaffold: true,
        textScale: textScale,
        size: const Size(360, 3200),
        overrides: [
          ...env.overrides(),
          agentStatusProvider.overrideWith(
            (ref) => AgentStatusNotifier.fixed(
              const AgentLink(
                AgentLinkKind.up,
                status: AgentStatus(agentId: 'a', version: '1'),
              ),
            ),
          ),
          agentHttpClientProvider.overrideWithValue(mock()),
          rulesClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 28, 19, 30),
          ),
        ],
      );
      await settle(tester);
    }

    bool selected(WidgetTester tester, String key) =>
        tester.widget<InkPill>(find.byKey(Key(key))).selected;

    testWidgets('picking a preset shows a summary, then saves it',
        (tester) async {
      await pump(tester, {...contractRules});
      expect(selected(tester, 'preset-custom'), isTrue);
      await tester.tap(find.byKey(const Key('preset-schoolNight')));
      await settle(tester);
      expect(find.byKey(const Key('preset-sheet')), findsOneWidget);
      expect(find.text('Daily TV time: 2 h'), findsOneWidget);
      await tester.tap(find.byKey(const Key('preset-confirm')));
      await settle(tester);

      final body = jsonDecode(sent.lastWhere((r) => r.method == 'PUT').body)
          as Map<String, dynamic>;
      expect(body['tvTime']['dailyLimitMin'], 120);
      expect(body['style'], 'explicit');
      expect(body['allowedApps']['packages'], ['org.smarttube.stable']);
      expect(find.text('Saved to the TV ✓'), findsOneWidget);
      expect(selected(tester, 'preset-schoolNight'), isTrue);
      expect(selected(tester, 'preset-custom'), isFalse);

      // Editing any routine field turns it into Custom.
      await tester.tap(find.byKey(const Key('rules-always-mute')));
      await settle(tester);
      expect(selected(tester, 'preset-schoolNight'), isFalse);
      expect(selected(tester, 'preset-custom'), isTrue);
    });

    testWidgets('Keep my settings changes nothing', (tester) async {
      await pump(tester, {...contractRules});
      await tester.tap(find.byKey(const Key('preset-movieNight')));
      await settle(tester);
      await tester.tap(find.text('Keep my settings'));
      await settle(tester);
      expect(sent.where((r) => r.method == 'PUT'), isEmpty);
      expect(find.byKey(const Key('rules-save-bar')), findsNothing);
    });

    testWidgets('blank rules teach with templates', (tester) async {
      await pump(tester, {
        'version': 1,
        'tvTime': {'schedule': [], 'dailyLimitMin': 0},
      });
      expect(find.byKey(const Key('rules-templates')), findsOneWidget);
      await tester.tap(find.byKey(const Key('template-weekend')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('preset-confirm')));
      await settle(tester);
      expect(find.byKey(const Key('rules-templates')), findsNothing);
      expect(selected(tester, 'preset-weekend'), isTrue);
    });

    testWidgets('apps mode, days and the TV preview', (tester) async {
      await pump(tester, {...contractRules});
      await tester.tap(find.byKey(const Key('rules-apps-blocklist')));
      await settle(tester);
      expect(find.textContaining('close as soon as they open'), findsOneWidget);
      // Toggle Saturday on the first window.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('rules-schedule-0')),
          matching: find.byKey(const Key('day-6')),
        ),
      );
      await settle(tester);
      expect(find.text('Mon–Sat'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rules-style-explicit')));
      await settle(tester);
      expect(find.textContaining('A friendly card from Tubby'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('rules-save')));
      await tester.tap(find.byKey(const Key('rules-save')));
      await settle(tester);
      final body = jsonDecode(sent.lastWhere((r) => r.method == 'PUT').body)
          as Map<String, dynamic>;
      expect(body['allowedApps']['mode'], 'blocklist');
      expect(body['tvTime']['schedule'][0]['days'], [1, 2, 3, 4, 5, 6]);
      expect(body['style'], 'explicit');
    });

    testWidgets('fits 360 dp at 1.3× text', (tester) async {
      await pump(tester, {...contractRules}, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lock for a while', () {
    Future<RecordingLockService> pump(
      WidgetTester tester, {
      TvStatus? playing,
      double textScale = 1,
    }) async {
      final env = await TestEnv.create(tvs: [adbSony]);
      final ls = RecordingLockService();
      await pumpScreen(
        tester,
        const SingleChildScrollView(child: ClassicLockCard()),
        scaffold: true,
        textScale: textScale,
        size: const Size(360, 2000),
        overrides: [
          ...env.overrides(),
          lockServiceProvider.overrideWith((ref) => ls),
          tvServiceProvider.overrideWithValue(FixedTvService(playing)),
        ],
      );
      await settle(tester);
      return ls;
    }

    testWidgets('apps lock sends every field, interval from Advanced',
        (tester) async {
      final ls = await pump(tester);
      await tester.tap(find.byKey(const Key('classic-mode-apps')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('classic-duration-120')));
      await settle(tester);
      expect(find.text('Lock for 2 hours'), findsOneWidget);
      await tester.tap(find.byKey(const Key('classic-advanced')));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('classic-interval')),
          matching: find.byType(TextField),
        ),
        '999',
      );
      await tester.tap(find.byKey(const Key('classic-start-stop')));
      await settle(tester);
      expect(ls.started, {
        'host': adbSony.ip,
        'lockApps': true,
        'lockVolume': false,
        'maxVolume': 15,
        'interval': 300,
        'duration': 120,
        'whitelist': ['E8C28D3C'],
      });
    });

    testWidgets('volume lock with a custom duration', (tester) async {
      final ls = await pump(tester);
      await tester.tap(find.byKey(const Key('classic-mode-volume')));
      await settle(tester);
      expect(find.text('15%'), findsOneWidget);
      await tester.tap(find.byKey(const Key('classic-duration-other')));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('classic-duration')),
          matching: find.byType(TextField),
        ),
        '45',
      );
      await settle(tester);
      expect(find.text('Lock for 45 min'), findsOneWidget);
      await tester.tap(find.byKey(const Key('classic-start-stop')));
      await settle(tester);
      expect(ls.started!['lockVolume'], isTrue);
      expect(ls.started!['lockApps'], isFalse);
      expect(ls.started!['duration'], 45);
      expect(ls.started!['interval'], 10);
      expect(ls.started!['maxVolume'], 15);
    });

    testWidgets('What\'s playing → allow adds it to the whitelist',
        (tester) async {
      await pump(
        tester,
        playing: const TvStatus(
          volume: 10,
          muted: false,
          appId: '233637DE',
          appName: 'YouTube',
          isIdle: false,
        ),
      );
      await tester.tap(find.byKey(const Key('classic-mode-apps')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('classic-whats-playing')));
      await settle(tester);
      expect(find.text('Not allowed yet: the lock would stop it.'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('whats-playing-allow')));
      await settle(tester);
      expect(find.text('YouTube'), findsOneWidget);
    });

    testWidgets('fits 360 dp at 1.3× text', (tester) async {
      await pump(tester, textScale: 1.3);
      await tester.tap(find.byKey(const Key('classic-mode-apps')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
