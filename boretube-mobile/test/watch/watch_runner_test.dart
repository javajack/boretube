import 'dart:convert';

import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:boretube_mobile/watch/always_on_watch.dart';
import 'package:boretube_mobile/watch/watch_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const living = Tv(id: 'tv-a', name: 'Living Room TV', ip: '10.0.0.3');
const bedroom = Tv(id: 'tv-b', name: 'Bedroom TV', ip: '10.0.0.7');
const noGuard = Tv(id: 'tv-c', name: 'Kitchen TV', ip: '10.0.0.9');

void main() {
  late SharedPreferences prefs;
  late FakeAlertNotifier notifier;

  /// What each TV answers: a JSON status, 401, or nothing.
  final answers = <String, Object?>{};
  final asked = <String>[];

  /// What Cast says about each TV's power when its helper is silent.
  final power = <String, TvPower>{};

  http.Client client() => MockClient((r) async {
        asked.add(r.url.host);
        expect(r.url.path, '/v1/status');
        expect(r.headers['Authorization'], startsWith('Bearer tok-'));
        final a = answers[r.url.host];
        if (a == 401) return http.Response('', 401);
        if (a == null) throw const AgentUnreachable('timeout');
        return http.Response(jsonEncode(a), 200);
      });

  Map<String, Object?> status({String mode = 'normal', bool limited = false}) =>
      {
        'agentId': 'x',
        'version': '1.0.1',
        'selfAdb': 'ok',
        'mode': mode,
        'limited': limited,
      };

  Future<List<WatchAlert>> check() {
    final c = client();
    return runWatchOnce(
      prefs: prefs,
      tvs: const [living, bedroom, noGuard],
      tokenFor: (id) async => id == noGuard.id ? null : 'tok-$id',
      statusOf: (tv, token) => AgentClient(
        host: tv.ip,
        port: tv.agentPort,
        token: token,
        httpClient: c,
      ).status(),
      notifier: notifier,
      powerOf: (tv) async => power[tv.ip] ?? TvPower.awake,
      clock: () => DateTime(2026, 10, 29, 21),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    notifier = FakeAlertNotifier();
    answers.clear();
    asked.clear();
    power.clear();
  });

  test('checks only TVs with Always On, and stays quiet when fine', () async {
    answers[living.ip] = status();
    answers[bedroom.ip] = status(mode: 'paused');
    expect(await check(), isEmpty);
    expect(asked, unorderedEquals([living.ip, bedroom.ip]));
    expect(notifier.shown, isEmpty);
    expect(prefs.getString(kWatchLastRunKey), '2026-10-29T21:00:00.000');
  });

  test('a TV going quiet alerts on the second miss, once, then recovers',
      () async {
    answers[bedroom.ip] = status();
    // Living Room doesn't answer.
    expect(await check(), isEmpty);
    expect(await check(), [const WatchAlert.incident(Incident.down)]);
    expect(await check(), isEmpty);
    final n = notifier.shown.single;
    expect(n.title, 'Always On stopped on Living Room TV');
    expect(n.payload, living.id);
    expect(n.id, alertIdFor(living.id));

    answers[living.ip] = status();
    expect(await check(), [const WatchAlert.recovery()]);
    expect(notifier.shown.last.title, 'Always On is back on Living Room TV');
    // Same id: the recovery replaces the "stopped" notification.
    expect(notifier.shown.last.id, n.id);
    expect(await check(), isEmpty);
  });

  test('standby and a TV that is off stay quiet; awake and silent alerts',
      () async {
    answers[bedroom.ip] = status();
    power[living.ip] = TvPower.asleep;
    expect(await check(), isEmpty);
    expect(await check(), isEmpty);
    power[living.ip] = TvPower.gone;
    expect(await check(), isEmpty);
    expect(await check(), isEmpty);
    expect(notifier.shown, isEmpty);
    // Woke up, and the helper still doesn't answer: that's the real fault.
    power[living.ip] = TvPower.awake;
    expect(await check(), isEmpty);
    expect(await check(), [const WatchAlert.incident(Incident.down)]);
  });

  test('limited, safe and a rejected token each get their own words', () async {
    answers[living.ip] = status(limited: true);
    answers[bedroom.ip] = 401;
    await check();
    expect(notifier.shown.map((n) => n.title), [
      'Always On can\'t close apps on Living Room TV',
      'Always On stopped on Bedroom TV',
    ]);
    answers[living.ip] = status(mode: 'safe');
    await check();
    // Safe is milder than limited: no second alert.
    expect(notifier.shown, hasLength(2));
  });

  test('state is kept per TV in preferences', () async {
    answers[bedroom.ip] = status(limited: true);
    await check();
    await check();
    final b = WatchState.decode(prefs.getString(watchStateKey(bedroom.id)));
    expect(b.notified, Incident.limited);
    final a = WatchState.decode(prefs.getString(watchStateKey(living.id)));
    expect(a.notified, Incident.down);
  });
}
