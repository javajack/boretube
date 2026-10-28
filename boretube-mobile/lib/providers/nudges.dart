import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../agent/agent_models.dart';
import '../ops/health.dart';
import '../screens/home/home_logic.dart' show isStopEntry, stoppedAppOf;
import 'agent_providers.dart';
import 'providers.dart';

// Discovery over time (spec §5): small, well-timed suggestions computed
// from the journals and what this phone remembers. At most one per app
// open, never during an action, and "Not now" backs off 7 → 30 days →
// never. Everything here is UI-layer state on this phone.

/// Every nudge, in priority order (first wins).
enum NudgeId {
  fixSpeech,
  reviewUpdate,
  alwaysOn,
  bedtime,
  noShorts,
  shorts,
  cleanTv,
  volumeLimit,
  friendlyMessage,
  newTv,
  weekendPreset,
}

/// Where a nudge's button goes.
enum NudgeTarget { routines, betterTv, addTv }

/// A nudge ready to show, with words specific to what triggered it.
class Nudge {
  final NudgeId id;
  final String title;
  final String message;
  final String action;
  final NudgeTarget target;

  /// The section to open: a Better TV id ([betterTvFocusProvider]) or a
  /// Routines card ([routinesFocusProvider]).
  final String? focus;

  const Nudge({
    required this.id,
    required this.title,
    required this.message,
    required this.action,
    required this.target,
    this.focus,
  });
}

/// Everything the triggers look at. Plain data, so they are easy to test.
class NudgeInputs {
  final DateTime now;

  /// Pause TV taps from this phone (not quiet-only), oldest first.
  final List<DateTime> pauses;

  /// Volume turned down from this phone.
  final List<DateTime> volumeDowns;

  /// Phone and Always On journals, any order.
  final List<ActivityItem> activity;
  final bool alwaysOn;
  final bool hasAdb;

  /// When this phone first saw Home mode work on this TV.
  final DateTime? adbSince;

  /// The rules on the TV (Always On only).
  final AgentRules? rules;
  final AgentStatus? status;
  final List<HealthCheck> health;

  /// Stock YouTube is on the TV right now (null: unknown).
  final bool? stockYouTubeInstalled;

  /// When boretube was first opened on this phone.
  final DateTime? firstOpen;

  /// The previous app open (before this one).
  final DateTime? lastVisit;

  /// The TV's build changed since this phone last looked (Home mode).
  final bool buildChanged;

  /// TVs seen on the Wi-Fi that aren't saved on this phone.
  final int unsavedTvs;

  /// Something on Home needs a hand right now (problem banner).
  final bool problem;

  const NudgeInputs({
    required this.now,
    this.pauses = const [],
    this.volumeDowns = const [],
    this.activity = const [],
    this.alwaysOn = false,
    this.hasAdb = false,
    this.adbSince,
    this.rules,
    this.status,
    this.health = const [],
    this.stockYouTubeInstalled,
    this.firstOpen,
    this.lastVisit,
    this.buildChanged = false,
    this.unsavedTvs = 0,
    this.problem = false,
  });
}

const kStockYouTubePkg = 'com.google.android.youtube.tv';

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

int _minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

bool _near(DateTime a, DateTime b, {int minutes = 45}) =>
    (_minuteOfDay(a) - _minuteOfDay(b)).abs() <= minutes;

/// A time of day the parent pauses at on [days] calendar days running,
/// ending today or yesterday (within ±45 min), or null.
DateTime? habitualPause(
  List<DateTime> pauses,
  DateTime now, {
  int days = 3,
}) {
  final today = _day(now);
  for (final end in [today, today.subtract(const Duration(days: 1))]) {
    final last = [
      for (final p in pauses)
        if (_day(p) == end) p,
    ];
    for (final p in last.reversed) {
      var run = true;
      for (var d = 1; d < days; d++) {
        final day = end.subtract(Duration(days: d));
        if (!pauses.any((q) => _day(q) == day && _near(q, p))) {
          run = false;
          break;
        }
      }
      if (run) return p;
    }
  }
  return null;
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h:$mm ${t.hour < 12 ? 'am' : 'pm'}';
}

bool _hasBedtime(AgentRules? r) => r?.tvTime.schedule.isNotEmpty ?? false;

// ── Triggers: each returns a nudge or null ──

/// 1. Pausing at about the same hour three days running, and no bedtime.
Nudge? bedtimeNudge(NudgeInputs i) {
  if (_hasBedtime(i.rules)) return null;
  final at = habitualPause(i.pauses, i.now);
  if (at == null) return null;
  return Nudge(
    id: NudgeId.bedtime,
    title: 'Same pause, every evening?',
    message: 'You\'ve paused around ${_clock(at)} three days running. A '
        'bedtime does it for you.',
    action: 'Set a bedtime',
    target: NudgeTarget.routines,
  );
}

/// 2. Volume turned down from this phone 3 times in a week, no limit.
Nudge? volumeLimitNudge(NudgeInputs i) {
  if (i.rules?.volumeLimit.enabled ?? false) return null;
  final week = i.now.subtract(const Duration(days: 7));
  final n = i.volumeDowns.where((t) => t.isAfter(week)).length;
  if (n < 3) return null;
  return Nudge(
    id: NudgeId.volumeLimit,
    title: 'Turning it down again?',
    message: 'You\'ve lowered the volume from here $n times this week. A '
        'volume limit keeps it there.',
    action: 'Set a limit',
    target: NudgeTarget.routines,
  );
}

/// 3. Stock YouTube came back after boretube removed it, or YouTube had
/// to be stopped 5+ times this week.
Nudge? noShortsNudge(NudgeInputs i) {
  final ytOps = [
    for (final a in i.activity)
      if (a.entry.ok &&
          (a.entry.op == 'stockYouTubeOff' || a.entry.op == 'stockYouTubeOn'))
        a.entry,
  ]..sort((a, b) => a.time.compareTo(b.time));
  final removedLast = ytOps.isNotEmpty && ytOps.last.op == 'stockYouTubeOff';
  final allowed = i.rules?.stockYouTubeAllowed ?? false;
  if (removedLast && i.stockYouTubeInstalled == true && !allowed) {
    return const Nudge(
      id: NudgeId.noShorts,
      title: 'YouTube came back',
      message: 'The TV\'s own YouTube, Shorts and all, is installed again. '
          'One tap tucks it away.',
      action: 'Show me',
      target: NudgeTarget.betterTv,
      focus: 'noShorts',
    );
  }
  if (i.stockYouTubeInstalled == false) return null;
  final week = i.now.subtract(const Duration(days: 7));
  final stops = i.activity
      .where(
        (a) =>
            a.entry.time.isAfter(week) &&
            isStopEntry(a.entry) &&
            a.entry.target.contains(kStockYouTubePkg),
      )
      .length;
  if (stops < 5) return null;
  return Nudge(
    id: NudgeId.noShorts,
    title: 'YouTube keeps getting closed',
    message: 'It was stopped $stops times this week. YouTube without '
        'Shorts keeps YouTube, minus the endless Shorts.',
    action: 'Show me',
    target: NudgeTarget.betterTv,
    focus: 'noShorts',
  );
}

/// 3b. Shorts keep showing up (3+ today by Always On's count) and the TV
/// does nothing about them yet.
Nudge? shortsNudge(NudgeInputs i) {
  final s = i.status?.shorts;
  if (!i.alwaysOn || s == null || s.mode != ShortsMode.off) return null;
  if ((i.rules?.shortsRule.mode ?? ShortsMode.off) != ShortsMode.off) {
    return null;
  }
  if (s.todayCount < 3) return null;
  return Nudge(
    id: NudgeId.shorts,
    title: 'Shorts keep sneaking in…',
    message: 'The TV counted ${s.todayCount} Shorts today. It can stop '
        'them, or allow a few a day.',
    action: 'Choose for Shorts',
    target: NudgeTarget.routines,
    focus: 'shorts',
  );
}

/// 4. Home mode started working in the last two days and the TV still has
/// its promo apps on.
Nudge? cleanTvNudge(NudgeInputs i) {
  final since = i.adbSince;
  if (!i.hasAdb || since == null) return null;
  if (i.now.difference(since) > const Duration(days: 2)) return null;
  final cleanup = i.health.where((c) => c.id == 'cleanup');
  if (cleanup.isEmpty || cleanup.first.status == HealthStatus.ok) return null;
  return const Nudge(
    id: NudgeId.cleanTv,
    title: 'Home mode is on. Tidy the TV?',
    message: 'Switch off the promo and ad apps it came with. Undo any time.',
    action: 'Clean TV',
    target: NudgeTarget.betterTv,
    focus: 'cleanTv',
  );
}

/// 5. A routine missed while away: without Always On, the parent has a
/// pause habit (same hour, 2+ days running), and since the last visit the
/// app was closed through that hour on a day with no pause. That evening
/// went unguarded, which Always On would have covered.
Nudge? alwaysOnNudge(NudgeInputs i) {
  if (i.alwaysOn || i.lastVisit == null) return null;
  final habit = habitualPause(i.pauses, i.now, days: 2) ??
      habitualPause(
        i.pauses,
        i.now.subtract(const Duration(days: 1)),
        days: 2,
      );
  if (habit == null) return null;
  final away = i.lastVisit!;
  for (var day = _day(away);
      day.isBefore(_day(i.now)) || day == _day(i.now);
      day = day.add(const Duration(days: 1))) {
    final at = DateTime(day.year, day.month, day.day, habit.hour, habit.minute);
    final closedThrough = at.isAfter(away) && at.isBefore(i.now);
    final paused = i.pauses.any((p) => _day(p) == day && _near(p, habit));
    if (closedThrough && !paused) {
      return Nudge(
        id: NudgeId.alwaysOn,
        title: 'Bedtime slipped while you were out',
        message: 'You usually pause around ${_clock(habit)}, but this app '
            'was closed. Always On keeps routines on the TV itself.',
        action: 'See Always On',
        target: NudgeTarget.betterTv,
        focus: 'alwaysOn',
      );
    }
  }
  return null;
}

/// 6. One app closed 3+ times in a day this week while the TV says no
/// quietly: a friendly message usually ends the tug of war.
Nudge? friendlyMessageNudge(NudgeInputs i) {
  final r = i.rules;
  if (r == null || r.style != RuleStyle.sneaky) return null;
  final week = _day(i.now).subtract(const Duration(days: 6));
  final counts = <(DateTime, String), int>{};
  for (final a in i.activity) {
    final e = a.entry;
    if (e.time.isBefore(week) || !isStopEntry(e)) continue;
    final k = (_day(e.time), stoppedAppOf(e));
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final top = counts.entries.where((e) => e.value >= 3).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (top.isEmpty) return null;
  final app = top.first.key.$2;
  return Nudge(
    id: NudgeId.friendlyMessage,
    title: '$app was reopened ${top.first.value - 1}×',
    message: 'Instead of closing quietly, the TV can say "That\'s all for '
        'now" with Tubby. Kids argue less with the TV.',
    action: 'Try it',
    target: NudgeTarget.routines,
  );
}

/// 7. Seven calm days: Always On, boretube in use for a week, no failed
/// change in the last 7 days, nothing wrong now, and no weekend routine.
Nudge? weekendPresetNudge(NudgeInputs i) {
  final r = i.rules;
  final first = i.firstOpen;
  if (!i.alwaysOn || r == null || first == null || i.problem) return null;
  if (i.now.difference(first) < const Duration(days: 7)) return null;
  final week = i.now.subtract(const Duration(days: 7));
  if (i.activity.any((a) => !a.entry.ok && a.entry.time.isAfter(week))) {
    return null;
  }
  final weekend = r.tvTime.schedule.any(
    (s) => s.days.contains(6) || s.days.contains(7),
  );
  if (weekend) return null;
  return const Nudge(
    id: NudgeId.weekendPreset,
    title: 'A calm week',
    message: 'Seven days without a hitch. Want a later bedtime for '
        'Friday and Saturday?',
    action: 'Set up weekends',
    target: NudgeTarget.routines,
  );
}

/// 8. The TV updated itself. With Always On the Home banner already asks
/// for approval, so this is for Home mode TVs (or a calm banner-less
/// state).
Nudge? reviewUpdateNudge(NudgeInputs i) {
  final agent = i.status?.buildChangedSinceApproval ?? false;
  if (!(agent || i.buildChanged) || i.problem) return null;
  return const Nudge(
    id: NudgeId.reviewUpdate,
    title: 'Your TV updated itself',
    message: 'Updates sometimes bring apps back. A quick look shows if '
        'everything is still in place.',
    action: 'Check the TV',
    target: NudgeTarget.betterTv,
    focus: 'health',
  );
}

/// 9. The speech services check failed (voice remote broken).
Nudge? fixSpeechNudge(NudgeInputs i) {
  final bad = i.health.any(
    (c) => c.id == 'speech' && c.status == HealthStatus.fail,
  );
  if (!bad) return null;
  return const Nudge(
    id: NudgeId.fixSpeech,
    title: 'Voice search may be broken',
    message: 'A speech update on the TV is known to break the voice '
        'remote. One tap puts the working version back.',
    action: 'Fix it',
    target: NudgeTarget.betterTv,
    focus: 'health',
  );
}

/// 10. A TV on this Wi-Fi that isn't saved here.
Nudge? newTvNudge(NudgeInputs i) {
  if (i.unsavedTvs <= 0) return null;
  return Nudge(
    id: NudgeId.newTv,
    title: i.unsavedTvs == 1
        ? 'Another TV is on this Wi-Fi'
        : '${i.unsavedTvs} more TVs are on this Wi-Fi',
    message: 'Add it to pause and quiet it from here too.',
    action: 'Add it',
    target: NudgeTarget.addTv,
  );
}

/// Every nudge whose trigger fires, in priority order.
List<Nudge> nudgeCandidates(NudgeInputs i) {
  final all = <NudgeId, Nudge? Function(NudgeInputs)>{
    NudgeId.fixSpeech: fixSpeechNudge,
    NudgeId.reviewUpdate: reviewUpdateNudge,
    NudgeId.alwaysOn: alwaysOnNudge,
    NudgeId.bedtime: bedtimeNudge,
    NudgeId.noShorts: noShortsNudge,
    NudgeId.shorts: shortsNudge,
    NudgeId.cleanTv: cleanTvNudge,
    NudgeId.volumeLimit: volumeLimitNudge,
    NudgeId.friendlyMessage: friendlyMessageNudge,
    NudgeId.newTv: newTvNudge,
    NudgeId.weekendPreset: weekendPresetNudge,
  };
  return [
    for (final id in NudgeId.values)
      if (all[id]!(i) case final n?) n,
  ];
}

// ── Persistence ──

/// Backoff and the small logs the triggers read, in SharedPreferences.
class NudgeStore {
  final SharedPreferences prefs;
  NudgeStore(this.prefs);

  static const backoff = [Duration(days: 7), Duration(days: 30)];
  static const _pausesKey = 'nudge.log.pauses';
  static const _volumeKey = 'nudge.log.volumeDown';
  static const _firstOpenKey = 'nudge.firstOpen';
  static const _unsavedKey = 'nudge.unsavedTvs';
  static const _logDays = 21;

  static String snoozesKey(NudgeId id) => 'nudge.${id.name}.snoozes';
  static String untilKey(NudgeId id) => 'nudge.${id.name}.until';
  static String doneKey(NudgeId id) => 'nudge.${id.name}.done';
  static String adbSinceKey(String tvId) => 'nudge.adbSince.$tvId';
  static String buildKey(String tvId) => 'nudge.build.$tvId';

  /// Not done, not snoozed into the future.
  bool eligible(NudgeId id, DateTime now) {
    if (prefs.getBool(doneKey(id)) ?? false) return false;
    final until = DateTime.tryParse(prefs.getString(untilKey(id)) ?? '');
    return until == null || !now.isBefore(until);
  }

  int snoozes(NudgeId id) => prefs.getInt(snoozesKey(id)) ?? 0;

  /// "Not now": 7 days, then 30 days, then never.
  Future<void> notNow(NudgeId id, DateTime now) async {
    final n = snoozes(id);
    await prefs.setInt(snoozesKey(id), n + 1);
    if (n >= backoff.length) {
      await prefs.setBool(doneKey(id), true);
    } else {
      await prefs.setString(
          untilKey(id), now.add(backoff[n]).toIso8601String());
    }
  }

  /// The parent followed it: it never shows again.
  Future<void> acted(NudgeId id) => prefs.setBool(doneKey(id), true);

  /// Lets [id] show again (e.g. a new TV update).
  Future<void> reset(NudgeId id) async {
    await prefs.remove(snoozesKey(id));
    await prefs.remove(untilKey(id));
    await prefs.remove(doneKey(id));
  }

  List<DateTime> _log(String key) => [
        for (final s in prefs.getStringList(key) ?? const <String>[])
          if (DateTime.tryParse(s) case final t?) t,
      ];

  Future<void> _append(String key, DateTime t) {
    final cut = t.subtract(const Duration(days: _logDays));
    final kept = [
      for (final x in _log(key))
        if (x.isAfter(cut)) x,
      t,
    ];
    return prefs
        .setStringList(key, [for (final x in kept) x.toIso8601String()]);
  }

  List<DateTime> get pauses => _log(_pausesKey);
  List<DateTime> get volumeDowns => _log(_volumeKey);

  Future<void> logPause(DateTime t) => _append(_pausesKey, t);
  Future<void> logVolumeDown(DateTime t) => _append(_volumeKey, t);

  /// First open, stamped the first time it is asked for.
  DateTime firstOpen(DateTime now) {
    final have = DateTime.tryParse(prefs.getString(_firstOpenKey) ?? '');
    if (have != null) return have;
    prefs.setString(_firstOpenKey, now.toIso8601String());
    return now;
  }

  /// When Home mode was first seen working on [tvId]; stamped now if new.
  DateTime adbSince(String tvId, DateTime now) {
    final have = DateTime.tryParse(prefs.getString(adbSinceKey(tvId)) ?? '');
    if (have != null) return have;
    prefs.setString(adbSinceKey(tvId), now.toIso8601String());
    return now;
  }

  /// Remembers the TV's build id. Returns true while a change since the
  /// previous one is still unreviewed (and re-arms the nudge on a change).
  bool noteBuild(String tvId, String build) {
    if (build.isEmpty) return false;
    final key = buildKey(tvId);
    final pendingKey = '$key.pending';
    final prev = prefs.getString(key);
    if (prev == null) {
      prefs.setString(key, build);
      return false;
    }
    if (prev != build) {
      prefs.setString(key, build);
      prefs.setBool(pendingKey, true);
      reset(NudgeId.reviewUpdate);
      return true;
    }
    return prefs.getBool(pendingKey) ?? false;
  }

  /// Clears an update that was looked at.
  Future<void> buildReviewed(String tvId) =>
      prefs.remove('${buildKey(tvId)}.pending');

  /// Discovery reports the TVs it saw that aren't saved (none wire this
  /// yet outside onboarding; see [newTvNudge]).
  Future<void> noteUnsavedTvs(int n) => prefs.setInt(_unsavedKey, n);
  int get unsavedTvs => prefs.getInt(_unsavedKey) ?? 0;
}

final nudgeStoreProvider = Provider<NudgeStore>(
  (ref) => NudgeStore(ref.watch(sharedPrefsProvider)),
);

/// Nudge clock; tests override it.
final nudgeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// One nudge per app open. The first eligible nudge seen while nothing
/// else is going on is kept for the session; once it is answered, no
/// other nudge shows until the app is opened again.
class NudgeSession extends ChangeNotifier {
  final NudgeStore store;
  Nudge? _current;
  bool _spent = false;

  NudgeSession(this.store);

  Nudge? get current => _current;
  bool get spent => _spent;

  /// The nudge to show now. [busy] (an action in flight, a break, a
  /// problem banner) hides it without spending the session.
  Nudge? choose(
    List<Nudge> candidates, {
    required DateTime now,
    bool busy = false,
  }) {
    if (_spent) return null;
    final kept = _current;
    if (kept != null) {
      // Show the freshest words; hide it if its reason went away.
      final fresh = candidates.where((n) => n.id == kept.id);
      if (fresh.isEmpty) return null;
      _current = fresh.first;
    } else {
      if (busy) return null;
      for (final n in candidates) {
        if (store.eligible(n.id, now)) {
          _current = n;
          break;
        }
      }
    }
    return busy ? null : _current;
  }

  Future<void> notNow(DateTime now) => _answer((id) => store.notNow(id, now));

  Future<void> acted() => _answer(store.acted);

  Future<void> _answer(Future<void> Function(NudgeId id) f) async {
    final n = _current;
    _spent = true;
    _current = null;
    notifyListeners();
    if (n != null) await f(n.id);
  }
}

final nudgeSessionProvider = ChangeNotifierProvider<NudgeSession>(
  (ref) => NudgeSession(ref.watch(nudgeStoreProvider)),
);
