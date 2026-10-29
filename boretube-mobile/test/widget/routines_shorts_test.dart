import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/ui_providers.dart';
import 'package:boretube_mobile/screens/rules/presets.dart';
import 'package:boretube_mobile/screens/rules/rules_editor.dart';
import 'package:boretube_mobile/screens/rules_tab.dart';
import 'package:boretube_mobile/ui/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../agent/agent_client_test.dart' show contractRules;
import 'helpers.dart';

Finder key(String k) => find.byKey(Key(k));

void main() {
  late List<http.Request> sent;
  late Map<String, dynamic> onTv;
  final now = DateTime(2026, 10, 28, 19, 30);

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
    AgentShorts? shorts,
    String? focus,
    double textScale = 1,
    double height = 3200,
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
      size: Size(360, height),
      overrides: [
        ...env.overrides(),
        agentStatusProvider.overrideWith(
          (ref) => AgentStatusNotifier.fixed(
            AgentLink(
              AgentLinkKind.up,
              status: AgentStatus(
                agentId: 'a',
                version: '1.1.0',
                shorts: shorts,
              ),
            ),
          ),
        ),
        agentHttpClientProvider.overrideWithValue(mock()),
        rulesClockProvider.overrideWithValue(() => now),
        if (focus != null) routinesFocusProvider.overrideWith((ref) => focus),
      ],
    );
    await settle(tester);
  }

  Future<void> show(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await settle(tester, 3);
  }

  /// Opens the Video hopping sheet from its row.
  Future<void> open(WidgetTester tester) async {
    await show(tester, 'rules-shorts');
    await tester.tap(key('rules-shorts'));
    await settle(tester);
    expect(key('rules-sheet-shorts'), findsOneWidget);
  }

  Map<String, dynamic> lastPut() =>
      jsonDecode(sent.lastWhere((r) => r.method == 'PUT').body)
          as Map<String, dynamic>;

  Future<void> save(WidgetTester tester) async {
    if (key('rules-sheet-done').evaluate().isNotEmpty) {
      await tester.tap(key('rules-sheet-done'));
      await settle(tester);
    }
    await tester.ensureVisible(key('rules-save'));
    await tester.tap(key('rules-save'));
    await settle(tester);
  }

  testWidgets('a row right after Allowed apps; ⓘ in its sheet', (tester) async {
    await pump(tester, {...contractRules});
    final apps = tester.getTopLeft(key('rules-apps')).dy;
    final shorts = tester.getTopLeft(key('rules-shorts')).dy;
    final sound = tester.getTopLeft(key('rules-sound')).dy;
    expect(apps < shorts && shorts < sound, isTrue);
    expect(
      find.descendant(of: key('rules-shorts'), matching: find.text('Off')),
      findsOneWidget,
    );
    await open(tester);
    expect(
      find.descendant(
        of: key('rules-sheet-shorts'),
        matching: key('info-shorts'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('modes, helper copy and the TV preview', (tester) async {
    await pump(tester, {...contractRules, 'style': 'explicit'});
    await open(tester);
    expect(find.textContaining('Videos play as usual'), findsOneWidget);
    expect(key('rules-shorts-preview'), findsNothing);
    // "Allow a few" is not offered on a TV that doesn't have it.
    expect(key('rules-shorts-budget'), findsNothing);

    await tester.tap(key('rules-shorts-block'));
    await settle(tester);
    expect(find.text('Gentle nudge'), findsWidgets);
    expect(find.text('That\'s a lot of quick videos.'), findsOneWidget);
    expect(find.text('Pick a full video instead.'), findsOneWidget);
    expect(key('rules-shorts-cool-min'), findsNothing);

    await tester.tap(key('rules-shorts-cooldown'));
    await settle(tester);
    expect(find.text('Time for a video break.'), findsOneWidget);
    expect(find.text('Video apps are back in 10 min.'), findsOneWidget);
    expect(find.byType(CountStepper), findsOneWidget);

    await tester.tap(key('rules-shorts-report'));
    await settle(tester);
    expect(find.textContaining('Nothing stops'), findsOneWidget);
    expect(key('rules-shorts-preview'), findsNothing);
  });

  testWidgets('quiet style says the app just closes', (tester) async {
    await pump(tester, {...contractRules});
    await open(tester);
    await tester.tap(key('rules-shorts-block'));
    await settle(tester);
    expect(find.textContaining('the app just closes'), findsOneWidget);
  });

  testWidgets('cool-down minutes step by 5 within 5–30 and save',
      (tester) async {
    await pump(tester, {...contractRules});
    await open(tester);
    await tester.tap(key('rules-shorts-cooldown'));
    await settle(tester);
    final stepper = find.byType(CountStepper);
    expect(tester.widget<CountStepper>(stepper).value, 10);
    for (var i = 0; i < 6; i++) {
      await tester.tap(key('rules-shorts-cool-min-plus'));
      await tester.pump();
    }
    await settle(tester);
    expect(tester.widget<CountStepper>(stepper).value, 30);
    for (var i = 0; i < 8; i++) {
      await tester.tap(key('rules-shorts-cool-min-minus'));
      await tester.pump();
    }
    await settle(tester);
    expect(tester.widget<CountStepper>(stepper).value, 5);
    await tester.tap(key('rules-shorts-cool-min-plus'));
    await settle(tester);
    await save(tester);
    expect(
      lastPut()['shorts'],
      {'mode': 'cooldown', 'perDay': 5, 'cooldownMin': 10},
    );
  });

  testWidgets('a budget rule stays readable and its stepper saves perDay',
      (tester) async {
    await pump(tester, {
      ...contractRules,
      'shorts': {'mode': 'budget', 'perDay': 2},
    });
    expect(find.text('2 a day'), findsOneWidget);
    await open(tester);
    expect(key('rules-shorts-budget'), findsOneWidget);
    await show(tester, 'rules-shorts-per-day');
    await tester.tap(key('rules-shorts-per-day-minus'));
    await settle(tester);
    expect(find.text('1 a day'), findsOneWidget);
    final minus = tester.widget<CountStepper>(key('rules-shorts-per-day'));
    expect(minus.value, 1);
    await tester.tap(key('rules-shorts-per-day-minus'));
    await settle(tester);
    expect(find.text('1 a day'), findsOneWidget);
    for (var i = 0; i < 25; i++) {
      await tester.tap(key('rules-shorts-per-day-plus'));
      await tester.pump();
    }
    await settle(tester);
    expect(find.text('20 a day'), findsOneWidget);
    await save(tester);
    expect(lastPut()['shorts'], {'mode': 'budget', 'perDay': 20});
  });

  testWidgets('saving another rule keeps rules.shorts', (tester) async {
    await pump(tester, {
      ...contractRules,
      'shorts': {'mode': 'block', 'perDay': 10, 'later': true},
    });
    await tester.tap(key('rules-always-mute'));
    await settle(tester);
    await save(tester);
    expect(lastPut()['alwaysMute'], isTrue);
    expect(lastPut()['shorts'], {'mode': 'block', 'perDay': 10, 'later': true});
  });

  testWidgets('back to Off on a TV without the rule is not an edit',
      (tester) async {
    await pump(tester, {...contractRules});
    await open(tester);
    await tester.tap(key('rules-shorts-block'));
    await settle(tester);
    expect(key('rules-save-bar'), findsOneWidget);
    await tester.tap(key('rules-shorts-off'));
    await settle(tester);
    expect(key('rules-save-bar'), findsNothing);
  });

  testWidgets('presets never touch video hopping', (tester) async {
    await pump(tester, {
      ...contractRules,
      'shorts': {'mode': 'budget', 'perDay': 3},
    });
    await show(tester, 'preset-schoolNight');
    await tester.tap(key('preset-schoolNight'));
    await settle(tester);
    expect(
      find.textContaining('video hopping and Tonight only stay'),
      findsOneWidget,
    );
    await tester.tap(key('preset-confirm'));
    await settle(tester);
    expect(lastPut()['shorts'], {'mode': 'budget', 'perDay': 3});
  });

  test('preset comparison and the 409 diff', () {
    const a = AgentRules(shorts: ShortsRule(mode: ShortsMode.block));
    expect(
      applyPreset(a, RulePreset.schoolNight).shorts!.mode,
      ShortsMode.block,
    );
    expect(
      detectPreset(
        applyPreset(a, RulePreset.weekend).copyWith(
          shorts: const ShortsRule(mode: ShortsMode.report),
        ),
      ),
      RulePreset.weekend,
    );
    expect(rulesDiff(a, const AgentRules()), contains('Video hopping'));
    expect(rulesDiff(a, a), isNot(contains('Video hopping')));
    const c = AgentRules(shorts: ShortsRule(mode: ShortsMode.cooldown));
    expect(
      rulesDiff(
        c,
        const AgentRules(
          shorts: ShortsRule(mode: ShortsMode.cooldown, cooldownMin: 20),
        ),
      ),
      contains('Video hopping'),
    );
    expect(
        hoppingLabel(const ShortsRule(mode: ShortsMode.block)), 'Gentle nudge');
  });

  testWidgets('today and last time, in the sheet', (tester) async {
    await pump(
      tester,
      {...contractRules},
      shorts: AgentShorts(
        todayCount: 7,
        lastDetectedAt: DateTime(2026, 10, 28, 18, 42),
      ),
    );
    expect(find.text('7 today'), findsOneWidget);
    await open(tester);
    await show(tester, 'rules-shorts-today');
    expect(
        find.text('Video hopping today: 7 · last at 6:42 pm'), findsOneWidget);
  });

  testWidgets('a nudge opens the Video hopping sheet', (tester) async {
    await pump(tester, {...contractRules}, focus: 'shorts', height: 700);
    await settle(tester, 6);
    expect(key('rules-sheet-shorts'), findsOneWidget);
    await tester.tap(key('rules-sheet-done'));
    await settle(tester);
    // Once only.
    expect(key('rules-sheet-shorts'), findsNothing);
  });

  testWidgets('fits 360 dp at 1.3× text', (tester) async {
    await pump(
      tester,
      {
        ...contractRules,
        'shorts': {'mode': 'budget', 'perDay': 5},
      },
      textScale: 1.3,
    );
    await open(tester);
    expect(tester.takeException(), isNull);
  });
}
