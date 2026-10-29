import 'package:boretube_mobile/agent/agent_client.dart';
import 'package:boretube_mobile/providers/agent_providers.dart';
import 'package:boretube_mobile/providers/now_playing.dart';
import 'package:boretube_mobile/tv/presence.dart';
import 'package:flutter_test/flutter_test.dart';

/// The TV's own power state, measured on the VU3 (2026-10-29):
/// standby keeps the network, ADB and Cast alive (ADB says Asleep, Cast says
/// isStandBy) while Android pauses TV Guard; off at the wall answers nothing.
void main() {
  final t = DateTime(2026, 10, 29, 23, 30);

  group('presenceOf', () {
    test('nothing answers: the TV can\'t be reached', () {
      expect(presenceOf(const NowPlaying(), t), TvPresence.unreachable);
    });

    test('still looking', () {
      expect(presenceOf(NowPlaying.initial, t), TvPresence.checking);
    });

    test('it answers but says it is asleep', () {
      expect(
        presenceOf(const NowPlaying(online: true, asleep: true), t),
        TvPresence.asleep,
      );
    });

    test('awake for a while (or since before we looked): on', () {
      expect(presenceOf(const NowPlaying(online: true), t), TvPresence.on);
      expect(
        presenceOf(
          NowPlaying(
            online: true,
            asleep: false,
            awakeSince: t.subtract(const Duration(minutes: 2)),
          ),
          t,
        ),
        TvPresence.on,
      );
    });

    test('just woke or booted: waking, for a minute', () {
      final now = NowPlaying(
        online: true,
        asleep: false,
        awakeSince: t.subtract(const Duration(seconds: 20)),
      );
      expect(presenceOf(now, t), TvPresence.waking);
      expect(
          presenceOf(now, t.add(const Duration(seconds: 41))), TvPresence.on);
    });
  });

  group('a silent helper and a TV reading that may be stale', () {
    final lastOk = t.subtract(const Duration(seconds: 15));

    test('not proven awake since the helper went quiet: checking', () {
      // Power cut: the helper gave up first; the TV reading still holds
      // its last success, from before the cut.
      final stale = NowPlaying(online: true, lastSeen: lastOk);
      expect(presenceOf(stale, t, helperLastOk: lastOk), TvPresence.checking);
      expect(
        g(const AgentLink(AgentLinkKind.down),
            presenceOf(stale, t, helperLastOk: lastOk)),
        GuardState.checking,
      );
    });

    test('the TV kept answering after the helper went quiet: a real fault', () {
      final fresh = NowPlaying(online: true, lastSeen: t);
      expect(presenceOf(fresh, t, helperLastOk: lastOk), TvPresence.on);
    });

    test('asleep or unreachable wins over checking', () {
      expect(
        presenceOf(const NowPlaying(online: true, asleep: true), t,
            helperLastOk: lastOk),
        TvPresence.asleep,
      );
      expect(presenceOf(const NowPlaying(), t, helperLastOk: lastOk),
          TvPresence.unreachable);
    });
  });

  group('the notifier notices waking up', () {
    test('asleep → awake starts the waking clock; awake → awake keeps it',
        () async {
      var clock = t;
      final readings = [
        const NowPlaying(online: true, asleep: true),
        const NowPlaying(online: true, asleep: false),
        const NowPlaying(online: true, asleep: false),
      ];
      var i = 0;
      final n = NowPlayingNotifier(
        fetch: () async => readings[i++],
        interval: const Duration(days: 1),
        active: false,
        clock: () => clock,
      );
      await n.refresh();
      expect(n.state.awakeSince, isNull);
      clock = t.add(const Duration(seconds: 5));
      await n.refresh();
      expect(n.state.awakeSince, t.add(const Duration(seconds: 5)));
      clock = t.add(const Duration(seconds: 30));
      await n.refresh();
      expect(n.state.awakeSince, t.add(const Duration(seconds: 5)));
    });

    test('back from unreachable (power cut, Wi-Fi) also counts as waking',
        () async {
      final readings = <NowPlaying?>[
        const NowPlaying(online: true),
        null,
        null,
        const NowPlaying(online: true),
      ];
      var i = 0;
      final n = NowPlayingNotifier(
        fetch: () async => readings[i++],
        interval: const Duration(days: 1),
        active: false,
        clock: () => t,
      );
      await n.refresh();
      expect(n.state.awakeSince, isNull,
          reason: 'awake since before we looked');
      await n.refresh();
      await n.refresh();
      await n.refresh();
      expect(n.state.awakeSince, t);
    });
  });

  group('Always On, read against the TV', () {
    const s = AgentStatus(agentId: 'a', version: '1.4.1', uptimeSec: 600);
    final up = AgentLink(AgentLinkKind.up, status: s);
    const down = AgentLink(AgentLinkKind.down, status: s);

    test('silent while the TV sleeps is not a fault', () {
      expect(g(down, TvPresence.asleep), GuardState.sleeping);
      expect(g(down, TvPresence.unreachable), GuardState.tvUnreachable);
    });

    test('silent or limited just after waking is starting up', () {
      expect(g(down, TvPresence.waking), GuardState.starting);
      const limited = AgentStatus(
          agentId: 'a', version: '1.4.1', uptimeSec: 600, limited: true);
      expect(
        g(const AgentLink(AgentLinkKind.up, status: limited),
            TvPresence.waking),
        GuardState.starting,
      );
    });

    test('a freshly started helper that is still limited is starting up', () {
      const fresh = AgentStatus(
          agentId: 'a', version: '1.4.1', uptimeSec: 20, limited: true);
      expect(
        g(const AgentLink(AgentLinkKind.up, status: fresh), TvPresence.on),
        GuardState.starting,
      );
    });

    test('awake for a while and still silent or limited: the real problem', () {
      expect(g(down, TvPresence.on), GuardState.down);
      const limited = AgentStatus(
          agentId: 'a', version: '1.4.1', uptimeSec: 600, limited: true);
      expect(
        g(const AgentLink(AgentLinkKind.up, status: limited), TvPresence.on),
        GuardState.limited,
      );
    });

    test('a rejected phone is always the real problem', () {
      const auth = AgentLink(AgentLinkKind.authFailed);
      expect(g(auth, TvPresence.on), GuardState.down);
      expect(g(auth, TvPresence.waking), GuardState.down);
    });

    test('healthy stays on', () {
      expect(g(up, TvPresence.on), GuardState.on);
      expect(g(up, TvPresence.waking), GuardState.on);
    });
  });
}

GuardState g(AgentLink link, TvPresence p) =>
    guardStateOf(link: link, onBreak: false, classic: false, presence: p);
