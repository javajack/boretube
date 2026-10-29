import '../providers/now_playing.dart';

/// The TV's own power state, as the phone can tell it.
///
/// Measured on the VU3 (2026-10-29): in standby the TV keeps its network,
/// ADB (`mWakefulness=Asleep`) and Cast (`isStandBy: true`) alive while
/// Android pauses TV Guard; off at the wall (or a Wi-Fi fault) answers
/// nothing; after waking, TV Guard is back within seconds but may need a
/// little longer to reconnect to itself.
enum TvPresence {
  /// No reading yet.
  checking,
  on,

  /// Woke or booted less than [kWakeGrace] ago: helpers are still settling.
  waking,

  /// Standby: answers, but its screen is off.
  asleep,

  /// Nothing answers: off at the wall, or the Wi-Fi is down.
  unreachable,
}

/// How long after waking a silent or limited TV Guard is still "starting".
const kWakeGrace = Duration(seconds: 60);

TvPresence presenceOf(NowPlaying now, DateTime t) {
  if (now.loading) return TvPresence.checking;
  if (!now.online) return TvPresence.unreachable;
  if (now.asleep == true) return TvPresence.asleep;
  final since = now.awakeSince;
  final woke = since != null && t.difference(since) < kWakeGrace;
  return woke ? TvPresence.waking : TvPresence.on;
}
