// The Always On watch's incident logic: pure, persisted as JSON, and
// tested without WorkManager or notifications.

import 'dart:convert';

import '../agent/agent_models.dart';

/// What one background check saw on a TV.
enum WatchObservation {
  /// Answering and enforcing (a running break counts as healthy).
  healthy,

  /// Paused by the parent: their choice, never an alert.
  paused,

  /// Answering, but can't do everything (e.g. can't close apps).
  limited,

  /// Hands off: reporting only, changing nothing.
  safe,

  /// Answers, but no longer recognises this phone.
  authFailed,

  /// No answer this time, though the TV itself is awake (or can't say):
  /// the helper stopped, or a Wi-Fi blip.
  unreachable,

  /// The TV is in standby (Cast says so) and Android paused the helper.
  /// Not a fault: it picks up again when the TV wakes.
  asleep,

  /// Nothing on the TV answers: off at the wall, or the phone isn't home.
  away,

  /// Just started and still reconnecting to itself.
  settling,
}

/// A problem worth telling the parent about, mildest first.
enum Incident { safe, limited, down }

/// How long after starting a limited helper is still settling (as
/// `kAgentSettle` on the Always On card).
const kWatchSettle = Duration(seconds: 60);

/// The same reading as `guardStateOf` for an answering agent.
WatchObservation classifyStatus(AgentStatus s) {
  if (s.mode == AgentMode.safe) return WatchObservation.safe;
  if (s.mode == AgentMode.paused) return WatchObservation.paused;
  if (s.isLimited) {
    return s.justStarted(kWatchSettle)
        ? WatchObservation.settling
        : WatchObservation.limited;
  }
  return WatchObservation.healthy;
}

/// Per-TV memory between checks.
class WatchState {
  /// The worst incident already notified in the current spell, or null
  /// when nothing is outstanding.
  final Incident? notified;

  /// Misses in a row; two make "down" (one is just a blip).
  final int failures;

  const WatchState({this.notified, this.failures = 0});

  static const initial = WatchState();

  factory WatchState.fromJson(Map<String, dynamic> j) => WatchState(
        notified: Incident.values.asNameMap()[j['notified']],
        failures: j['failures'] is int ? j['failures'] as int : 0,
      );

  Map<String, dynamic> toJson() => {
        if (notified != null) 'notified': notified!.name,
        'failures': failures,
      };

  static WatchState decode(String? s) {
    if (s == null || s.isEmpty) return initial;
    try {
      return WatchState.fromJson(
        (jsonDecode(s) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return initial;
    }
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is WatchState &&
      other.notified == notified &&
      other.failures == failures;

  @override
  int get hashCode => Object.hash(notified, failures);

  @override
  String toString() => 'WatchState(${notified?.name}, $failures)';
}

/// A notification to post: an [incident], or recovery when null.
class WatchAlert {
  final Incident? incident;
  const WatchAlert.incident(Incident this.incident);
  const WatchAlert.recovery() : incident = null;

  bool get recovery => incident == null;

  @override
  bool operator ==(Object other) =>
      other is WatchAlert && other.incident == incident;

  @override
  int get hashCode => incident.hashCode;

  @override
  String toString() =>
      recovery ? 'WatchAlert.recovery' : 'WatchAlert(${incident!.name})';
}

/// Misses in a row before an unreachable TV counts as "down".
const kMissesForDown = 2;

/// One check: the next state, and the alert to post (if any).
///
/// - Healthy → problem: one alert for the incident.
/// - Problem → a *worse* problem (safe < limited < down): one more alert,
///   so "can't close apps" turning into "stopped" is not missed. Milder
///   or equal problems stay quiet; the worst one notified is remembered.
/// - Problem → healthy (or paused, the parent's own choice): "Always On
///   is back", but only if an alert had gone out.
/// - One miss is ignored as a blip; [kMissesForDown] in a row is "down".
///   A rejected token is down at once (it won't fix itself).
/// - A sleeping, unplugged or settling TV says nothing either way: no
///   alert, misses start over, and an outstanding incident stays.
(WatchState, WatchAlert?) watchStep(WatchState prev, WatchObservation obs) {
  Incident? now;
  var failures = 0;
  switch (obs) {
    case WatchObservation.asleep:
    case WatchObservation.away:
    case WatchObservation.settling:
      return (WatchState(notified: prev.notified), null);
    case WatchObservation.healthy:
    case WatchObservation.paused:
      if (prev.notified == null) return (WatchState.initial, null);
      return (WatchState.initial, const WatchAlert.recovery());
    case WatchObservation.unreachable:
      failures = prev.failures + 1;
      if (failures < kMissesForDown) {
        return (WatchState(notified: prev.notified, failures: failures), null);
      }
      now = Incident.down;
    case WatchObservation.authFailed:
      now = Incident.down;
    case WatchObservation.limited:
      now = Incident.limited;
    case WatchObservation.safe:
      now = Incident.safe;
  }
  final had = prev.notified;
  if (had == null || now.index > had.index) {
    return (
      WatchState(notified: now, failures: failures),
      WatchAlert.incident(now),
    );
  }
  return (WatchState(notified: had, failures: failures), null);
}

/// Notification copy, in parent words.
({String title, String body}) alertCopy(WatchAlert a, String tvName) =>
    switch (a.incident) {
      null => (
          title: 'Always On is back on $tvName',
          body: 'Bedtime and limits are running again.',
        ),
      Incident.down => (
          title: 'Always On stopped on $tvName',
          body: 'Bedtime and limits won\'t run until it\'s back. Tap to '
              'fix.',
        ),
      Incident.limited => (
          title: 'Always On can\'t close apps on $tvName',
          body: 'Limits may slip for now. Tap to fix it in a minute.',
        ),
      Incident.safe => (
          title: 'Always On is hands-off on $tvName',
          body: 'It\'s only watching, not enforcing. Tap to turn it back '
              'on.',
        ),
    };
