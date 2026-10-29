import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/agent/agent_installer.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/screens/rules/rules_editor.dart';
import 'package:boretube_mobile/screens/rules_tab.dart';
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
  final now = DateTime(2026, 10, 29, 17, 30);

  http.Client mock() => MockClient((r) async {
        sent.add(r);
        if (r.url.path == '/v1/action') {
          return http.Response(
            jsonEncode({'ok': true, 'detail': 'brain break on the TV'}),
            200,
          );
        }
        if (r.method == 'GET') return http.Response(jsonEncode(onTv), 200);
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        onTv = {...body, 'version': (body['version'] as int) + 1};
        return http.Response(jsonEncode(onTv), 200);
      });

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic> rules, {
    String version = '1.4.0',
    AgentLearning? learning,
  }) async {
    sent = [];
    onTv = rules;
    final env = await TestEnv.create(tvs: [adbSony]);
    await AgentTokenStore(env.secrets).write(adbSony.id, 'tok');
    await pumpScreen(
      tester,
      const RulesTab(),
      scaffold: true,
      size: const Size(360, 3600),
      overrides: [
        ...env.overrides(),
        agentStatusProvider.overrideWith(
          (ref) => AgentStatusNotifier.fixed(
            AgentLink(
              AgentLinkKind.up,
              status: AgentStatus(
                agentId: 'a',
                version: version,
                learning: learning,
              ),
            ),
          ),
        ),
        agentHttpClientProvider.overrideWithValue(mock()),
        rulesClockProvider.overrideWithValue(() => now),
      ],
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(key('rules-learning'));
    await settle(tester, 3);
    await tester.tap(key('rules-learning'));
    await settle(tester);
    expect(key('rules-sheet-learning'), findsOneWidget);
  }

  Future<void> tapIn(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await settle(tester, 3);
    await tester.tap(key(k));
    await settle(tester);
  }

  Map<String, dynamic> lastPut() =>
      jsonDecode(sent.lastWhere((r) => r.method == 'PUT').body)
          as Map<String, dynamic>;

  Future<void> save(WidgetTester tester) async {
    await tapIn(tester, 'rules-sheet-done');
    await tester.ensureVisible(key('rules-save'));
    await tester.tap(key('rules-save'));
    await settle(tester);
  }

  testWidgets('a row after Video hopping, Off on a TV without it',
      (tester) async {
    await pump(tester, {...contractRules});
    final shorts = tester.getTopLeft(key('rules-shorts')).dy;
    final learning = tester.getTopLeft(key('rules-learning')).dy;
    final sound = tester.getTopLeft(key('rules-sound')).dy;
    expect(shorts < learning && learning < sound, isTrue);
    expect(
      find.descendant(of: key('rules-learning'), matching: find.text('Off')),
      findsOneWidget,
    );
  });

  testWidgets('turn on, pick a class, language and trigger, save',
      (tester) async {
    await pump(tester, {...contractRules});
    await open(tester);
    // Off: only the switch.
    expect(key('rules-learning-grade-3'), findsNothing);
    await tapIn(tester, 'rules-learning-on');
    await tapIn(tester, 'rules-learning-grade-3');
    await tapIn(tester, 'rules-learning-lang-enHi');
    await tapIn(tester, 'rules-learning-trigger-every');
    expect(key('rules-learning-every'), findsOneWidget);
    await tapIn(tester, 'rules-learning-every-plus');
    // Unsaved: the try waits for a save.
    expect(key('rules-learning-try-note'), findsOneWidget);
    await save(tester);
    expect(lastPut()['learning'], {
      'enabled': true,
      'grade': 3,
      'lang': 'enHi',
      'voice': true,
      'perBreak': 3,
      'trigger': 'every',
      'everyMin': 35,
    });
    expect(
      find.descendant(
          of: key('rules-learning'), matching: find.text('Class 3')),
      findsOneWidget,
    );
  });

  testWidgets('on and off again on a TV without it stays absent',
      (tester) async {
    await pump(tester, {...contractRules});
    await open(tester);
    await tapIn(tester, 'rules-learning-on');
    await tapIn(tester, 'rules-learning-on');
    await tapIn(tester, 'rules-sheet-done');
    expect(key('rules-save'), findsNothing);
  });

  testWidgets('try a break sends the action; this week shows', (tester) async {
    await pump(
      tester,
      {
        ...contractRules,
        'learning': {'enabled': true, 'grade': 4},
      },
      learning: const AgentLearning(
        enabled: true,
        weekBreaks: 3,
        weekRight: 7,
        weekLearned: 2,
        stronger: 'Tables of 6, 7, 8 and 9',
      ),
    );
    expect(find.text('3 this week'), findsOneWidget);
    await open(tester);
    expect(find.text('3 breaks · 7 right · 2 learned'), findsOneWidget);
    expect(
        find.text('Getting stronger: Tables of 6, 7, 8 and 9'), findsOneWidget);
    expect(key('rules-learning-try-note'), findsNothing);
    await tapIn(tester, 'rules-learning-try');
    final a = sent.lastWhere((r) => r.url.path == '/v1/action');
    expect(jsonDecode(a.body), {'action': 'brainBreak'});
    expect(find.text('Brain break on the TV ✓'), findsOneWidget);
  });

  testWidgets('an older TV Guard says to update', (tester) async {
    await pump(tester, {...contractRules}, version: '1.3.2');
    await open(tester);
    expect(key('rules-learning-update'), findsOneWidget);
    expect(key('rules-learning-on'), findsNothing);
    expect(compareVersions('1.3.2', '1.4.0') < 0, isTrue);
  });

  test('rules round-trip learning and keep unknown fields', () {
    final r = AgentRules.fromJson({
      ...contractRules,
      'learning': {'enabled': true, 'grade': 0, 'lang': 'hi', 'future': 1},
    });
    expect(r.learningRule.grade, 0);
    expect(r.learningRule.lang, LearnLang.hi);
    expect(r.toJson()['learning']['future'], 1);
    expect(AgentRules.fromJson({...contractRules}).learning, isNull);
    expect(
      AgentRules.fromJson({...contractRules}).toJson().containsKey('learning'),
      isFalse,
    );
  });

  test('status.learning parses', () {
    final s = AgentStatus.fromJson({
      'agentId': 'a',
      'version': '1.4.0',
      'learning': {
        'enabled': true,
        'showing': true,
        'trigger': 'hopping',
        'grade': 2,
        'skill': 'Money',
        'voice': 'noHindi',
        'week': {'breaks': 1, 'right': 2, 'learned': 1},
      },
    });
    final l = s.learning!;
    expect(l.showing, isTrue);
    expect(l.trigger, LearnTrigger.hopping);
    expect(l.voice, 'noHindi');
    expect(l.weekRight, 2);
    expect(AgentLearning.fromJson(l.toJson()).skill, 'Money');
  });
}
