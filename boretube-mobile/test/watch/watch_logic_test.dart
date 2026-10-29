import 'package:boretube_mobile/agent/agent_models.dart';
import 'package:boretube_mobile/watch/watch_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const h = WatchObservation.healthy;
const p = WatchObservation.paused;
const l = WatchObservation.limited;
const s = WatchObservation.safe;
const a = WatchObservation.authFailed;
const u = WatchObservation.unreachable;
const z = WatchObservation.asleep;
const w = WatchObservation.away;
const g = WatchObservation.settling;

/// Runs [obs] from a fresh state; returns the alerts (null = none).
List<WatchAlert?> run(List<WatchObservation> obs) {
  var st = WatchState.initial;
  final out = <WatchAlert?>[];
  for (final o in obs) {
    final (next, alert) = watchStep(st, o);
    // Survives persistence between checks.
    st = WatchState.decode(next.encode());
    expect(st, next);
    out.add(alert);
  }
  return out;
}

const down = WatchAlert.incident(Incident.down);
const limited = WatchAlert.incident(Incident.limited);
const safe = WatchAlert.incident(Incident.safe);
const back = WatchAlert.recovery();

void main() {
  group('classifyStatus', () {
    AgentStatus st({
      AgentMode mode = AgentMode.normal,
      SelfAdb adb = SelfAdb.ok,
      bool limited = false,
      bool onBreak = false,
      int uptime = 0,
    }) =>
        AgentStatus(
          agentId: 'a',
          version: '1',
          uptimeSec: uptime,
          mode: mode,
          selfAdb: adb,
          limited: limited,
          breakState: AgentBreak(active: onBreak),
        );

    test('matches the Always On card', () {
      expect(classifyStatus(st()), h);
      expect(classifyStatus(st(onBreak: true)), h);
      expect(classifyStatus(st(mode: AgentMode.paused)), p);
      expect(classifyStatus(st(mode: AgentMode.safe)), s);
      expect(classifyStatus(st(limited: true)), l);
      expect(classifyStatus(st(adb: SelfAdb.needsApproval)), l);
      // Safe mode wins over limited.
      expect(classifyStatus(st(mode: AgentMode.safe, limited: true)), s);
    });

    test('limited in its first minute is still settling', () {
      expect(classifyStatus(st(limited: true, uptime: 20)), g);
      expect(classifyStatus(st(limited: true, uptime: 90)), l);
    });
  });

  group('watchStep', () {
    test('healthy stays quiet', () {
      expect(run([h, h, p, h]), [null, null, null, null]);
    });

    test('one miss is a blip, two in a row is down', () {
      expect(run([h, u, h]), [null, null, null]);
      expect(run([h, u, u]), [null, null, down]);
    });

    test('notifies once per incident, then once on recovery', () {
      expect(run([u, u, u, u, h, h]), [null, down, null, null, back, null]);
      expect(run([l, l, l, h]), [limited, null, null, back]);
      expect(run([s, s, h]), [safe, null, back]);
    });

    test('a new spell after recovery notifies again', () {
      expect(run([l, h, l, h]), [limited, back, limited, back]);
    });

    test('getting worse notifies once more; milder stays quiet', () {
      expect(run([s, l, u, u, l, s, h]), [
        safe,
        limited,
        null,
        down,
        null,
        null,
        back,
      ]);
      expect(run([u, u, l, s, u, u]), [null, down, null, null, null, null]);
    });

    test('a rejected token is down at once', () {
      expect(run([a, a, h]), [down, null, back]);
    });

    test('paused is the parent\'s choice: ends an incident quietly', () {
      // No alert going into pause; recovery from a notified problem.
      expect(run([h, p, p]), [null, null, null]);
      expect(run([l, p]), [limited, back]);
    });

    test('a blip during an incident keeps it open', () {
      expect(run([l, u, l, h]), [limited, null, null, back]);
    });

    test('a sleeping or unplugged TV never alerts, and misses start over', () {
      expect(run([h, z, z, z, w, w, h]), List.filled(7, null));
      expect(run([u, z, u, w, u, g, u]), List.filled(7, null));
    });

    test('an open incident stays open through standby, then recovers', () {
      expect(run([u, u, z, w, h]), [null, down, null, null, back]);
      expect(run([l, g, z, l, h]), [limited, null, null, null, back]);
    });

    test('corrupt state starts fresh', () {
      expect(WatchState.decode('{nope'), WatchState.initial);
      expect(WatchState.decode(null), WatchState.initial);
    });
  });

  test('copy never says agent or ADB', () {
    for (final al in [down, limited, safe, back]) {
      final c = alertCopy(al, 'Living Room TV');
      expect(c.title, contains('Living Room TV'));
      for (final w in ['agent', 'ADB', 'adb', 'Guard']) {
        expect(c.title + c.body, isNot(contains(w)));
      }
    }
    expect(alertCopy(down, 'Den').title, 'Always On stopped on Den');
    expect(alertCopy(back, 'Den').title, 'Always On is back on Den');
  });
}
