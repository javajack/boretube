import 'dart:convert';

import 'package:boretube_mobile/actions/actions_service.dart';
import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/break_provider.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/tv/tv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../actions/actions_service_test.dart' show FakeCast, FakeSony;

void main() {
  final t0 = DateTime(2026, 10, 28, 19);
  late List<Map<String, dynamic>> bodies;
  late bool agentOk;
  late bool agentUp;

  AgentClient agent() => AgentClient(
        host: '10.0.0.9',
        token: 't',
        httpClient: MockClient((r) async {
          if (!agentUp) throw http.ClientException('refused');
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'ok': agentOk,
              'detail': agentOk ? 'done' : 'TV Guard is in safe mode',
              'endsAt': '2026-10-28T19:30:00.000Z',
            }),
            200,
          );
        }),
      );

  late FakeSony sony;
  late List<String> cast;

  ActionsService service({bool withAgent = true}) => ActionsService(
        const Tv(
          id: 'tv1',
          name: 'TV',
          ip: '10.0.0.9',
          capabilities: {TvCapability.cast, TvCapability.sonyRest},
        ),
        agent: withAgent ? agent() : null,
        sony: sony,
        cast: () => FakeCast(cast),
      );

  setUp(() {
    bodies = [];
    agentOk = true;
    agentUp = true;
    sony = FakeSony();
    cast = [];
  });

  group('ActionsService with TV Guard', () {
    test('every action goes to /v1/action first', () async {
      final s = service();
      expect((await s.mute()).via, ActionTransport.agent);
      expect((await s.unmute()).via, ActionTransport.agent);
      expect((await s.stopCurrentApp()).via, ActionTransport.agent);
      expect((await s.bore()).via, ActionTransport.agent);
      expect((await s.setVolume(25)).via, ActionTransport.agent);
      expect((await s.restore()).via, ActionTransport.agent);
      expect([
        for (final b in bodies) b['action']
      ], [
        'mute',
        'unmute',
        'stop',
        'bore',
        'volume',
        'restore',
      ]);
      expect(bodies[4]['value'], 25);
      expect(sony.calls, isEmpty);
    });

    test('break and muteFor are TV-enforced with the agent end time', () async {
      final s = service();
      final b = await s.startBreak(30, now: t0);
      expect(b.via, ActionTransport.agent);
      expect(b.until, DateTime.utc(2026, 10, 28, 19, 30));
      final m = await s.muteFor(30, now: t0);
      expect(m.via, ActionTransport.agent);
      expect(bodies.map((b) => b['action']), ['break', 'muteFor']);
      expect(bodies.last['minutes'], 30);
    });

    test('refused (safe mode) falls back silently to Sony/Cast', () async {
      agentOk = false;
      final s = service();
      final r = await s.mute();
      expect(r.ok, isTrue);
      expect(r.via, ActionTransport.sonyRest);
      final b = await s.startBreak(15, now: t0);
      expect(b.ok, isTrue);
      expect(b.via, isNot(ActionTransport.agent));
      expect(b.until, t0.add(const Duration(minutes: 15)));
    });

    test('unreachable agent falls back too', () async {
      agentUp = false;
      final r = await service().setVolume(10);
      expect(r.via, ActionTransport.sonyRest);
      expect(sony.calls, ['volume 10']);
    });

    test('without the agent nothing changes', () async {
      final r = await service(withAgent: false).mute();
      expect(r.via, ActionTransport.sonyRest);
      expect(bodies, isEmpty);
    });
  });

  group('status pill', () {
    AgentLink up(AgentStatus s) => AgentLink(AgentLinkKind.up, status: s);
    const base = AgentStatus(agentId: 'a', version: '1');
    GuardState g(AgentLink l, {bool brk = false, bool classic = false}) =>
        guardStateOf(link: l, onBreak: brk, classic: classic);

    test('every state', () {
      expect(g(AgentLink.none), GuardState.notGuarded);
      expect(g(AgentLink.none, classic: true), GuardState.classic);
      expect(g(AgentLink.none, brk: true), GuardState.onBreak);
      expect(g(const AgentLink(AgentLinkKind.checking)), GuardState.checking);
      expect(g(const AgentLink(AgentLinkKind.down)), GuardState.down);
      expect(g(const AgentLink(AgentLinkKind.authFailed)), GuardState.down);
      expect(g(up(base)), GuardState.on);
      expect(
        g(up(const AgentStatus(
          agentId: 'a',
          version: '1',
          selfAdb: SelfAdb.needsApproval,
        ))),
        GuardState.limited,
      );
      expect(
        g(up(const AgentStatus(agentId: 'a', version: '1', limited: true))),
        GuardState.limited,
      );
      expect(
        g(up(const AgentStatus(
          agentId: 'a',
          version: '1',
          mode: AgentMode.paused,
        ))),
        GuardState.paused,
      );
      expect(
        g(
          up(const AgentStatus(
            agentId: 'a',
            version: '1',
            mode: AgentMode.safe,
          )),
          brk: true,
        ),
        GuardState.safe,
      );
      expect(g(up(base), brk: true), GuardState.onBreak);
      expect(
        g(up(AgentStatus(
          agentId: 'a',
          version: '1',
          breakState: AgentBreak(active: true, endsAt: t0),
        ))),
        GuardState.onBreak,
      );
      expect(const AgentLink(AgentLinkKind.up).healthy, isFalse);
      expect(
        up(const AgentStatus(agentId: 'a', version: '1', mode: AgentMode.safe))
            .healthy,
        isFalse,
      );
    });
  });

  group('BreakController with TV Guard', () {
    late DateTime clock;
    late NowPlayingNotifier now;

    Future<BreakController> make(ActionsService a) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return BreakController(
        tvId: 'tv1',
        prefs: prefs,
        actions: () => a,
        nowPlaying: () => now,
        clock: () => clock,
      );
    }

    setUp(() {
      clock = DateTime.utc(2026, 10, 28, 19);
      now = NowPlayingNotifier.fixed(
        const NowPlaying(
          online: true,
          id: 'org.smarttube.stable',
          appName: 'SmartTube',
          muted: false,
        ),
      );
    });

    tearDown(() => now.dispose());

    test('a TV-enforced break is marked byTv and not enforced locally',
        () async {
      final c = await make(service());
      final r = await c.start(30);
      expect(r!.via, ActionTransport.agent);
      expect(c.state.byTv, isTrue);
      expect(c.state.until, DateTime.utc(2026, 10, 28, 19, 30));
      bodies.clear();
      await c.enforce(now.state);
      expect(bodies, isEmpty);
      expect(sony.calls, isEmpty);
      // Reopening the app keeps the flag.
      final again = BreakController(
        tvId: 'tv1',
        prefs: c.prefs,
        actions: () => null,
        nowPlaying: () => null,
        clock: () => clock,
      );
      expect(again.state.byTv, isTrue);
      again.dispose();
      c.dispose();
    });

    test('silence only uses muteFor and never closes apps', () async {
      final c = await make(service(withAgent: false));
      await c.start(30, silenceOnly: true);
      expect(c.state.silenceOnly, isTrue);
      expect(c.state.byTv, isFalse);
      now.patch((s) => s.copyWith(muted: false));
      cast.clear();
      await c.enforce(now.state);
      expect(sony.calls.last, 'mute true');
      expect(cast, isNot(contains('stop')));
      c.dispose();
    });

    test('follows breaks the TV reports', () async {
      final c = await make(service());
      final end = clock.add(const Duration(minutes: 20));
      await c.syncFromAgent(AgentBreak(active: true, endsAt: end));
      expect(c.state.active, isTrue);
      expect(c.state.byTv, isTrue);
      expect(c.state.until, end);
      await c.syncFromAgent(const AgentBreak());
      expect(c.state.active, isFalse);
      c.dispose();
    });

    test('a stale "no break" right after starting is ignored', () async {
      final c = await make(service());
      await c.start(30);
      clock = clock.add(const Duration(seconds: 3));
      await c.syncFromAgent(const AgentBreak());
      expect(c.state.active, isTrue);
      clock = clock.add(const Duration(seconds: 30));
      await c.syncFromAgent(const AgentBreak());
      expect(c.state.active, isFalse);
      c.dispose();
    });
  });
}
