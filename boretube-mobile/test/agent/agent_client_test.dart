import 'dart:async';
import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The rules document from the contract, with concrete values.
final contractRules = <String, dynamic>{
  'version': 3,
  'updatedBy': 'Rakesh\'s Pixel',
  'updatedAt': '2026-10-28T19:30:00.000Z',
  'style': 'sneaky',
  'allowedApps': {
    'mode': 'allowlist',
    'packages': ['org.smarttube.stable'],
  },
  'volumeLimit': {'maxPercent': 30, 'enabled': true},
  'alwaysMute': false,
  'tvTime': {
    'schedule': [
      {
        'days': [1, 2, 3, 4, 5],
        'from': '21:00',
        'to': '07:00',
      },
    ],
    'dailyLimitMin': 0,
  },
  'overrides': [
    {
      'kind': 'allowApp',
      'pkg': 'com.google.android.youtube.tv',
      'until': '2026-10-28T23:59:00.000',
    },
    {'kind': 'muteUntil', 'until': '2026-10-28T20:00:00.000Z'},
  ],
  'stockYouTubeAllowed': false,
};

final contractStatus = <String, dynamic>{
  'agentId': 'a1b2c3',
  'version': '1.0.0',
  'api': 1,
  'uptimeSec': 3600,
  'bootCount': 4,
  'selfAdb': 'needsApproval',
  'mode': 'normal',
  'now': {
    'foreground': 'org.smarttube.stable',
    'volume': 12,
    'min': 0,
    'max': 100,
    'muted': false,
  },
  'activeRulesVersion': 3,
  'break': {'active': true, 'endsAt': '2026-10-28T19:45:00.000Z'},
  'health': [
    {'id': 'youtube', 'status': 'ok', 'detail': 'Removed'},
    {'id': 'cleanup', 'status': 'warn', 'detail': 'pending approval'},
  ],
  'buildFingerprint': 'Sony/BRAVIA_VU3/UKR1.240726.001:14/user/release-keys',
  'buildChangedSinceApproval': true,
  'clockSkewWarn': false,
};

void main() {
  group('models round-trip the contract examples', () {
    test('rules document', () {
      final r = AgentRules.fromJson(contractRules);
      expect(r.version, 3);
      expect(r.style, RuleStyle.sneaky);
      expect(r.allowedApps.mode, AppsMode.allowlist);
      expect(r.volumeLimit.maxPercent, 30);
      expect(r.tvTime.schedule.single.crossesMidnight, isTrue);
      expect(r.overrides.first.kind, OverrideKind.allowApp);
      expect(r.overrides.last.pkg, isNull);
      expect(jsonDecode(jsonEncode(r.toJson())), contractRules);
    });

    test('unknown rule fields survive a PUT', () {
      final j = {...contractRules, 'futureThing': {'x': 1}};
      expect(AgentRules.fromJson(j).toJson()['futureThing'], {'x': 1});
    });

    test('status', () {
      final s = AgentStatus.fromJson(contractStatus);
      expect(s.selfAdb, SelfAdb.needsApproval);
      expect(s.mode, AgentMode.normal);
      expect(s.now.percent, 12);
      expect(s.breakState.active, isTrue);
      expect(s.breakState.endsAt, DateTime.utc(2026, 10, 28, 19, 45));
      expect(s.health[1].status, AgentHealthStatus.warn);
      expect(s.buildChangedSinceApproval, isTrue);
      expect(jsonDecode(jsonEncode(s.toJson())), contractStatus);
    });

    test('lenient: unknown enums and epoch times', () {
      final s = AgentStatus.fromJson({
        'agentId': 'x',
        'version': '2',
        'selfAdb': 'somethingNew',
        'mode': 'weird',
        'break': {'active': true, 'endsAt': 1761680700000},
      });
      expect(s.selfAdb, SelfAdb.unknown);
      expect(s.mode, AgentMode.normal);
      expect(s.breakState.endsAt!.millisecondsSinceEpoch, 1761680700000);
    });

    test('actions use the wire names', () {
      expect(const AgentAction.startBreak(30).toJson(),
          {'action': 'break', 'minutes': 30});
      expect(const AgentAction.muteFor(30).toJson(),
          {'action': 'muteFor', 'minutes': 30});
      expect(const AgentAction.volume(25).toJson(),
          {'action': 'volume', 'value': 25});
      expect(const AgentAction(AgentActionKind.endBreak).toJson(),
          {'action': 'endBreak'});
      for (final k in AgentActionKind.values) {
        final a = AgentAction(k, minutes: 5);
        expect(AgentAction.fromJson(a.toJson()).kind, k);
      }
    });

    test('journal entry', () {
      final j = {
        'time': 1761680700000,
        'op': 'stockYouTubeOff',
        'target': 'com.google.android.youtube.tv',
        'before': 'enabled',
        'after': 'notInstalled',
        'ok': true,
        'source': 'watchdog',
      };
      final e = AgentJournalEntry.fromJson(j);
      expect(e.source, JournalSource.watchdog);
      expect(e.toJson(), j);
      expect(
        AgentJournalEntry.fromJson({
          'time': '2026-10-28T19:45:00Z',
          'op': 'x',
          'before': {'v': 1},
        }).before,
        '{v: 1}',
      );
    });
  });

  group('AgentClient', () {
    late List<http.Request> sent;
    late Future<http.Response> Function(http.Request) reply;

    AgentClient client() => AgentClient(
          host: '192.168.1.3',
          token: 'tok123',
          clock: () => DateTime.fromMillisecondsSinceEpoch(1761680700000),
          httpClient: MockClient((r) {
            sent.add(r);
            return reply(r);
          }),
        );

    http.Response json(Object body, [int code = 200]) =>
        http.Response(jsonEncode(body), code,
            headers: {'content-type': 'application/json'});

    setUp(() {
      sent = [];
      reply = (_) async => json({'ok': true});
    });

    test('status sends auth and phone time', () async {
      reply = (_) async => json(contractStatus);
      final s = await client().status();
      expect(s.agentId, 'a1b2c3');
      final r = sent.single;
      expect(r.url.toString(), 'http://192.168.1.3:8790/v1/status');
      expect(r.method, 'GET');
      expect(r.headers['Authorization'], 'Bearer tok123');
      expect(r.headers['X-Phone-Time'], '1761680700000');
    });

    test('401 is AgentAuthException', () async {
      reply = (_) async => json({'error': 'unauthorized'}, 401);
      expect(client().status(), throwsA(isA<AgentAuthException>()));
    });

    test('status times out after 2 s', () async {
      reply = (_) => Completer<http.Response>().future;
      final f = client().status();
      await expectLater(f, throwsA(isA<AgentUnreachable>()));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('PUT rules sends the whole document; 409 carries current',
        () async {
      final mine = AgentRules.fromJson(contractRules);
      final theirs = {
        ...contractRules,
        'version': 4,
        'updatedBy': 'Other phone',
      };
      reply = (_) async => json(theirs, 409);
      try {
        await client().putRules(mine);
        fail('expected a conflict');
      } on AgentConflict catch (e) {
        expect(e.current.version, 4);
        expect(e.current.updatedBy, 'Other phone');
      }
      final r = sent.single;
      expect(r.method, 'PUT');
      expect(r.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(r.body), contractRules);
    });

    test('PUT rules returns the saved document', () async {
      reply = (_) async => json({...contractRules, 'version': 4});
      final saved =
          await client().putRules(AgentRules.fromJson(contractRules));
      expect(saved.version, 4);
    });

    test('PUT rules falls back to GET when the reply is not rules',
        () async {
      reply = (r) async => r.method == 'PUT'
          ? json({'ok': true})
          : json({...contractRules, 'version': 4});
      final saved =
          await client().putRules(AgentRules.fromJson(contractRules));
      expect(saved.version, 4);
      expect(sent.map((r) => r.method), ['PUT', 'GET']);
    });

    test('action, mode, approveBuild, profile, restore', () async {
      reply = (r) async => json({
            'ok': true,
            'detail': 'done',
            if (r.url.path == '/v1/action') 'endsAt': '2026-10-28T20:00:00Z',
          });
      final c = client();
      final a = await c.action(const AgentAction.startBreak(30));
      expect(a.ok, isTrue);
      expect(a.endsAt, DateTime.utc(2026, 10, 28, 20));
      await c.setMode(AgentMode.paused);
      await c.approveBuild();
      await c.pushProfile({'id': 'sony-bravia-vu3'});
      await c.restore(RestoreTarget.stock);
      expect(sent.map((r) => '${r.method} ${r.url.path}'), [
        'POST /v1/action',
        'POST /v1/mode',
        'POST /v1/approveBuild',
        'POST /v1/profile',
        'POST /v1/restore',
      ]);
      expect(jsonDecode(sent[0].body), {'action': 'break', 'minutes': 30});
      expect(jsonDecode(sent[1].body), {'mode': 'paused'});
      expect(jsonDecode(sent[3].body), {'id': 'sony-bravia-vu3'});
      expect(jsonDecode(sent[4].body), {'target': 'stock'});
    });

    test('journal passes since as epoch ms', () async {
      reply = (_) async => json([
            {'time': 1, 'op': 'a', 'source': 'rule'},
          ]);
      final list = await client()
          .journal(since: DateTime.fromMillisecondsSinceEpoch(1234));
      expect(sent.single.url.queryParameters['since'], '1234');
      expect(list.single.source, JournalSource.rule);
    });

    test('other errors are AgentHttpException', () async {
      reply = (_) async => http.Response('boom', 500);
      expect(
        client().rules(),
        throwsA(
          isA<AgentHttpException>().having((e) => e.statusCode, 'code', 500),
        ),
      );
    });
  });
}
