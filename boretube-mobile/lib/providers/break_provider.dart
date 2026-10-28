import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../actions/actions_service.dart';
import '../agent/agent_models.dart';
import '../ops/journal.dart';
import 'agent_providers.dart';
import 'now_playing.dart';
import 'providers.dart';
import 'tv_providers.dart';

/// A running break: the TV stays closed and muted until [until].
class BreakState {
  final DateTime? until;

  /// TV Guard enforces it on the TV; the phone doesn't need to.
  final bool byTv;

  /// "Silence only": muted, but apps keep running (agent `muteFor`).
  final bool silenceOnly;

  const BreakState([this.until, this.byTv = false, this.silenceOnly = false]);

  /// The controller clears [until] when the break ends.
  bool get active => until != null;
}

/// Starts, keeps and ends a break. The end time is kept in
/// SharedPreferences, so reopening the app resumes the countdown. While
/// the app is alive, every poll re-mutes the TV and closes any app that
/// was opened; at the end the sound comes back once.
class BreakController extends StateNotifier<BreakState> {
  final String? tvId;
  final SharedPreferences prefs;
  final ActionsService? Function() actions;
  final NowPlayingNotifier? Function() nowPlaying;
  final Journal? journal;
  final DateTime Function() clock;
  final void Function()? onJournal;

  /// Minimum gap between two enforcements of the same kind, so a TV that
  /// refuses doesn't get hammered on every reconciling refresh.
  final Duration enforceGap;

  Timer? _timer;
  bool _enforcing = false;
  DateTime? _lastMute;
  DateTime? _lastClose;

  BreakController({
    required this.tvId,
    required this.prefs,
    required this.actions,
    required this.nowPlaying,
    this.journal,
    this.clock = DateTime.now,
    this.onJournal,
    this.enforceGap = const Duration(seconds: 4),
  }) : super(const BreakState()) {
    final id = tvId;
    final raw = id == null ? null : prefs.getString(keyFor(id));
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return;
    final flags = prefs.getString(flagsKeyFor(id!)) ?? '';
    if (until.isAfter(clock())) {
      state = BreakState(
        until,
        flags.contains('tv'),
        flags.contains('silence'),
      );
      _schedule(until);
    } else {
      // Ran out while the app was closed: bring the sound back once.
      scheduleMicrotask(_expire);
    }
  }

  static String keyFor(String tvId) => 'break.until.$tvId';
  static String flagsKeyFor(String tvId) => 'break.flags.$tvId';

  /// Ignore "no break" from agent polls this soon after starting one: a
  /// poll that was already on the wire predates it.
  static const syncGrace = Duration(seconds: 10);
  DateTime? _startedAt;

  Duration remaining() {
    final u = state.until;
    if (u == null) return Duration.zero;
    final d = u.difference(clock());
    return d.isNegative ? Duration.zero : d;
  }

  void _schedule(DateTime until) {
    _timer?.cancel();
    _timer = Timer(until.difference(clock()), _expire);
  }

  Future<void> _set(
    DateTime? until, {
    bool byTv = false,
    bool silenceOnly = false,
  }) async {
    _timer?.cancel();
    if (mounted) state = BreakState(until, byTv, silenceOnly);
    final id = tvId;
    if (id == null) return;
    if (until == null) {
      await prefs.remove(keyFor(id));
      await prefs.remove(flagsKeyFor(id));
    } else {
      await prefs.setString(keyFor(id), until.toIso8601String());
      await prefs.setString(
        flagsKeyFor(id),
        [if (byTv) 'tv', if (silenceOnly) 'silence'].join(','),
      );
      _schedule(until);
    }
  }

  /// Runs [run] with the hero card already showing [change]; undoes the
  /// change if it fails.
  Future<ActionResult?> _optimistic(
    NowPlaying Function(NowPlaying s) change,
    Future<ActionResult?> Function() run,
  ) async {
    final n = nowPlaying();
    final undo = n?.patch(change);
    n?.hold();
    ActionResult? r;
    try {
      r = await run();
    } catch (e) {
      r = ActionResult(false, ActionTransport.none, detail: '$e');
    } finally {
      n?.release();
    }
    if ((r == null || !r.ok) && undo != null) n?.revert(undo);
    return r;
  }

  /// Closes the app, mutes, and starts the countdown ([silenceOnly]: just
  /// mutes). Shown at once; rolled back if the TV didn't take it. With TV
  /// Guard healthy the TV enforces it, even with this app closed.
  Future<ActionResult?> start(int minutes, {bool silenceOnly = false}) async {
    final a = actions();
    if (a == null) return null;
    final until = clock().add(Duration(minutes: minutes));
    _startedAt = clock();
    await _set(until, silenceOnly: silenceOnly);
    final r = await _optimistic(
      (s) => silenceOnly
          ? s.copyWith(muted: true)
          : s.atHome().copyWith(muted: true),
      () => silenceOnly
          ? a.muteFor(minutes, now: clock())
          : a.startBreak(minutes, now: clock()),
    );
    if (r == null || !r.ok) {
      await _set(null);
    } else if (r.via == ActionTransport.agent) {
      await _set(r.until ?? until, byTv: true, silenceOnly: silenceOnly);
    }
    return r;
  }

  /// Follows a break the TV reports (started by another phone, or ended
  /// there).
  Future<void> syncFromAgent(AgentBreak b) async {
    final end = b.endsAt;
    if (b.active && end != null && end.isAfter(clock())) {
      if (!state.active || state.silenceOnly || state.until != end) {
        await _set(end, byTv: true);
      }
      return;
    }
    final started = _startedAt;
    final fresh = started != null && clock().difference(started) < syncGrace;
    if (!b.active &&
        state.active &&
        state.byTv &&
        !state.silenceOnly &&
        !fresh) {
      await _set(null);
    }
  }

  /// Ends the break now and unmutes (same as Restore).
  Future<ActionResult?> end() async {
    await _set(null);
    final a = actions();
    if (a == null) return null;
    return _optimistic((s) => s.copyWith(muted: false), a.restore);
  }

  Future<void> _expire() async {
    if (!mounted) return;
    if (state.byTv) {
      // The TV ends it and brings the sound back by itself.
      await _set(null);
      onJournal?.call();
      return;
    }
    final r = await end();
    await _log('over: sound back on', r);
  }

  /// Called with each fresh poll: re-mutes and closes apps while a break
  /// runs.
  Future<void> enforce(NowPlaying now) async {
    if (!state.active || state.byTv || _enforcing) return;
    if (!now.online || now.loading) return;
    final a = actions();
    if (a == null) return;
    final t = clock();
    bool due(DateTime? last) =>
        last == null || t.difference(last) >= enforceGap;
    _enforcing = true;
    try {
      if (!state.silenceOnly &&
          !now.isHome &&
          now.id != null &&
          due(_lastClose)) {
        _lastClose = t;
        final name = now.appName.isEmpty ? now.id! : now.appName;
        final r = await _optimistic((s) => s.atHome(), a.stopCurrentApp);
        await _log('closed $name', r);
      }
      if (now.muted == false && due(_lastMute)) {
        _lastMute = t;
        final r = await _optimistic(
          (s) => s.copyWith(muted: true),
          a.mute,
        );
        await _log('re-muted', r);
      }
    } finally {
      _enforcing = false;
    }
  }

  Future<void> _log(String what, ActionResult? r) async {
    final id = tvId;
    final j = journal;
    if (id == null || j == null) return;
    final ok = r?.ok ?? false;
    await j.add(
      JournalEntry(
        tvId: id,
        time: clock(),
        op: 'break',
        target: what,
        before: '',
        after: ok ? 'done via ${r!.via.name}' : (r?.detail ?? 'no TV'),
        ok: ok,
      ),
    );
    onJournal?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Time source for breaks; tests override it.
final breakClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final breakProvider = StateNotifierProvider<BreakController, BreakState>((ref) {
  final c = BreakController(
    tvId: ref.watch(activeTvIdProvider),
    prefs: ref.watch(sharedPrefsProvider),
    actions: () => ref.read(actionsServiceProvider),
    nowPlaying: () => ref.read(nowPlayingProvider.notifier),
    journal: ref.watch(journalProvider),
    clock: ref.watch(breakClockProvider),
    onJournal: () => ref.invalidate(journalEntriesProvider),
  );
  // A real poll stamps lastSeen; optimistic patches keep it.
  ref.listen<NowPlaying>(nowPlayingProvider, (prev, next) {
    if (next.lastSeen != prev?.lastSeen) unawaited(c.enforce(next));
  });
  ref.listen<AgentLink>(agentStatusProvider, (prev, next) {
    final s = next.status;
    if (next.up && s != null && !identical(s, prev?.status)) {
      unawaited(c.syncFromAgent(s.breakState));
    }
  });
  return c;
});
