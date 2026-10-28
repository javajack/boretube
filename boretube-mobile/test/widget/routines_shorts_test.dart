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

  Map<String, dynamic> lastPut() =>
      jsonDecode(sent.lastWhere((r) => r.method == 'PUT').body)
          as Map<String, dynamic>;

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(key('rules-save'));
    await tester.tap(key('rules-save'));
    await settle(tester);
  }

  testWidgets('placed right after Allowed apps, with ⓘ', (tester) async {
    await pump(tester, {...contractRules});
    final apps = tester.getTopLeft(key('rules-apps')).dy;
    final shorts = tester.getTopLeft(key('rules-shorts')).dy;
    final sound = tester.getTopLeft(key('rules-sound')).dy;
    expect(apps < shorts && shorts < sound, isTrue);
    expect(
      find.descendant(
        of: key('rules-shorts'),
        matching: key('info-shorts'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('modes, helper copy and the TV preview', (tester) async {
    await pump(tester, {...contractRules, 'style': 'explicit'});
    await show(tester, 'rules-shorts');
    expect(find.textContaining('Shorts play as usual'), findsOneWidget);
    expect(key('rules-shorts-preview'), findsNothing);

    await tester.tap(key('rules-shorts-block'));
    await settle(tester);
    expect(find.textContaining('three quick Shorts in a row'), findsOneWidget);
    expect(find.text('Shorts aren\'t on in this house.'), findsOneWidget);
    expect(find.text('Pick a full video instead.'), findsOneWidget);
    expect(key('rules-shorts-per-day'), findsNothing);

    await tester.tap(key('rules-shorts-budget'));
    await settle(tester);
    expect(find.text('That\'s all the Shorts for today.'), findsOneWidget);
    expect(key('rules-shorts-per-day'), findsOneWidget);
    expect(find.text('5 a day'), findsOneWidget);

    await tester.tap(key('rules-shorts-report'));
    await settle(tester);
    expect(find.textContaining('Nothing is stopped'), findsOneWidget);
    expect(key('rules-shorts-preview'), findsNothing);
  });

  testWidgets('quiet style says the app just closes', (tester) async {
    await pump(tester, {...contractRules});
    await show(tester, 'rules-shorts');
    await tester.tap(key('rules-shorts-block'));
    await settle(tester);
    expect(find.textContaining('Pick "Friendly'), findsOneWidget);
  });

  testWidgets('the stepper stays within 1–20 and saves perDay', (tester) async {
    await pump(tester, {
      ...contractRules,
      'shorts': {'mode': 'budget', 'perDay': 2},
    });
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

  testWidgets('saving another card keeps rules.shorts', (tester) async {
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
    await show(tester, 'rules-shorts');
    await tester.tap(key('rules-shorts-block'));
    await settle(tester);
    expect(key('rules-save-bar'), findsOneWidget);
    await tester.tap(key('rules-shorts-off'));
    await settle(tester);
    expect(key('rules-save-bar'), findsNothing);
  });

  testWidgets('presets never touch Shorts', (tester) async {
    await pump(tester, {
      ...contractRules,
      'shorts': {'mode': 'budget', 'perDay': 3},
    });
    await tester.tap(key('preset-schoolNight'));
    await settle(tester);
    expect(find.textContaining('Shorts and Tonight only stay'), findsOneWidget);
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
    expect(rulesDiff(a, const AgentRules()), contains('Shorts'));
    expect(rulesDiff(a, a), isNot(contains('Shorts')));
  });

  testWidgets('status line: today and last time', (tester) async {
    await pump(
      tester,
      {...contractRules},
      shorts: AgentShorts(
        todayCount: 7,
        lastDetectedAt: DateTime(2026, 10, 28, 18, 42),
      ),
    );
    await show(tester, 'rules-shorts-today');
    expect(find.text('Today: 7 Shorts · last at 6:42 pm'), findsOneWidget);
  });

  testWidgets('a nudge scrolls to the card', (tester) async {
    await pump(tester, {...contractRules}, focus: 'shorts', height: 700);
    await settle(tester, 6);
    final box = tester.getRect(key('rules-shorts'));
    expect(box.top, lessThan(700));
    expect(box.top, greaterThanOrEqualTo(0));
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
    await show(tester, 'rules-shorts');
    expect(tester.takeException(), isNull);
  });
}
