import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'baseline.dart';
import 'journal.dart';
import 'tv_ops.dart';

// The guided clean-up: a restore point, a choice, then one group at a
// time (switch off, let the TV save, restart, check). Progress is kept
// per TV so closing the app or losing the TV resumes at the same step.
// Every TV write goes through [TvOps].

enum WizardStep { restorePoint, choose, batch, done }

/// Where the current batch is.
enum BatchPhase {
  /// Switching the batch's apps off.
  disabling,

  /// The 60 s wait so the TV keeps the change.
  saving,

  /// Ready to restart (or skip it).
  restart,

  /// Restart sent; waiting for the TV to come back.
  restarting,

  /// Running the checks.
  checking,

  /// A check failed: undo or keep going.
  failed,

  /// The batch was put back; showing what came back.
  undone,
}

/// One group's apps, switched off together.
@immutable
class WizardBatch {
  /// Group id (the Clean TV group name) and its plain title.
  final String group;
  final String title;
  final List<String> pkgs;

  const WizardBatch({
    required this.group,
    required this.title,
    required this.pkgs,
  });

  Map<String, dynamic> toJson() => {
        'group': group,
        'title': title,
        'pkgs': pkgs,
      };

  factory WizardBatch.fromJson(Map<String, dynamic> j) => WizardBatch(
        group: j['group'] as String? ?? '',
        title: j['title'] as String? ?? '',
        pkgs: [for (final p in (j['pkgs'] as List?) ?? const []) '$p'],
      );
}

enum WizardCheckId { appsOff, connected, home, guard }

/// One post-restart check, shown as a ✓/✗ row.
@immutable
class WizardCheck {
  final WizardCheckId id;
  final bool ok;

  /// Why it failed, in plain words (empty when it passed). For
  /// [WizardCheckId.appsOff], the names of the apps that came back.
  final String detail;

  /// [WizardCheckId.appsOff]: how many apps switched themselves back on.
  final int count;

  const WizardCheck(
    this.id, {
    required this.ok,
    this.detail = '',
    this.count = 0,
  });

  Map<String, dynamic> toJson() =>
      {'id': id.name, 'ok': ok, 'detail': detail, 'count': count};

  static WizardCheck? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = WizardCheckId.values.asNameMap()[j['id']];
    if (id == null) return null;
    return WizardCheck(
      id,
      ok: j['ok'] as bool? ?? false,
      detail: j['detail'] as String? ?? '',
      count: j['count'] as int? ?? 0,
    );
  }

  @override
  String toString() => '${id.name}:${ok ? 'ok' : 'fail'}';
}

/// Everything the wizard needs to pick up where it left off.
@immutable
class WizardProgress {
  static const schema = 1;

  final WizardStep step;
  final Set<String> selected;
  final List<WizardBatch> batches;

  /// Index of the batch in progress.
  final int current;
  final BatchPhase phase;

  /// When [phase] started: the last write (saving) or the restart
  /// (restarting).
  final DateTime? phaseAt;

  /// Batches finished and kept, and batches put back.
  final List<int> kept;
  final List<int> undone;

  /// The current batch's checks (shown again on resume).
  final List<WizardCheck> checks;

  /// Packages the undo switched back on, and whether each verified.
  final Map<String, bool> undoResult;
  final bool restartSkipped;
  final DateTime? restorePointAt;
  final bool summaryLogged;

  const WizardProgress({
    this.step = WizardStep.restorePoint,
    this.selected = const {},
    this.batches = const [],
    this.current = 0,
    this.phase = BatchPhase.disabling,
    this.phaseAt,
    this.kept = const [],
    this.undone = const [],
    this.checks = const [],
    this.undoResult = const {},
    this.restartSkipped = false,
    this.restorePointAt,
    this.summaryLogged = false,
  });

  WizardBatch? get batch =>
      current >= 0 && current < batches.length ? batches[current] : null;

  bool get isLastBatch => current >= batches.length - 1;

  /// Apps switched off and kept off by this run.
  int get tidiedCount => [
        for (final i in kept)
          if (i >= 0 && i < batches.length) batches[i].pkgs.length,
      ].fold(0, (a, b) => a + b);

  WizardProgress copyWith({
    WizardStep? step,
    Set<String>? selected,
    List<WizardBatch>? batches,
    int? current,
    BatchPhase? phase,
    DateTime? phaseAt,
    bool clearPhaseAt = false,
    List<int>? kept,
    List<int>? undone,
    List<WizardCheck>? checks,
    Map<String, bool>? undoResult,
    bool? restartSkipped,
    DateTime? restorePointAt,
    bool? summaryLogged,
  }) =>
      WizardProgress(
        step: step ?? this.step,
        selected: selected ?? this.selected,
        batches: batches ?? this.batches,
        current: current ?? this.current,
        phase: phase ?? this.phase,
        phaseAt: clearPhaseAt ? null : phaseAt ?? this.phaseAt,
        kept: kept ?? this.kept,
        undone: undone ?? this.undone,
        checks: checks ?? this.checks,
        undoResult: undoResult ?? this.undoResult,
        restartSkipped: restartSkipped ?? this.restartSkipped,
        restorePointAt: restorePointAt ?? this.restorePointAt,
        summaryLogged: summaryLogged ?? this.summaryLogged,
      );

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'step': step.name,
        'selected': selected.toList()..sort(),
        'batches': [for (final b in batches) b.toJson()],
        'current': current,
        'phase': phase.name,
        'phaseAt': phaseAt?.toUtc().toIso8601String(),
        'kept': kept,
        'undone': undone,
        'checks': [for (final c in checks) c.toJson()],
        'undoResult': undoResult,
        'restartSkipped': restartSkipped,
        'restorePointAt': restorePointAt?.toUtc().toIso8601String(),
        'summaryLogged': summaryLogged,
      };

  factory WizardProgress.fromJson(Map<String, dynamic> j) {
    DateTime? time(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    List<int> ints(Object? v) => [
          for (final i in (v as List?) ?? const [])
            if (i is int) i,
        ];
    final undo = j['undoResult'];
    return WizardProgress(
      step: WizardStep.values.asNameMap()[j['step']] ?? WizardStep.restorePoint,
      selected: {for (final p in (j['selected'] as List?) ?? const []) '$p'},
      batches: [
        for (final b in (j['batches'] as List?) ?? const [])
          if (b is Map) WizardBatch.fromJson(b.cast<String, dynamic>()),
      ],
      current: j['current'] as int? ?? 0,
      phase: BatchPhase.values.asNameMap()[j['phase']] ?? BatchPhase.disabling,
      phaseAt: time(j['phaseAt']),
      kept: ints(j['kept']),
      undone: ints(j['undone']),
      checks: [
        for (final c in (j['checks'] as List?) ?? const [])
          if (WizardCheck.fromJson(c) case final WizardCheck w) w,
      ],
      undoResult: undo is Map
          ? {for (final e in undo.entries) '${e.key}': e.value == true}
          : const {},
      restartSkipped: j['restartSkipped'] as bool? ?? false,
      restorePointAt: time(j['restorePointAt']),
      summaryLogged: j['summaryLogged'] as bool? ?? false,
    );
  }
}

/// Wizard progress and the restore point, per TV, in SharedPreferences.
class WizardProgressStore {
  final SharedPreferences prefs;
  const WizardProgressStore(this.prefs);

  static String keyFor(String tvId) => 'ui.cleanWizard.$tvId';
  static String restorePointKey(String tvId) =>
      'ui.cleanWizard.restorePoint.$tvId';

  WizardProgress? read(String tvId) {
    final raw = prefs.getString(keyFor(tvId));
    if (raw == null) return null;
    try {
      return WizardProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String tvId, WizardProgress p) =>
      prefs.setString(keyFor(tvId), jsonEncode(p.toJson()));

  Future<void> clear(String tvId) => prefs.remove(keyFor(tvId));

  TvBaseline? restorePoint(String tvId) {
    final raw = prefs.getString(restorePointKey(tvId));
    if (raw == null) return null;
    try {
      return TvBaseline.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeRestorePoint(TvBaseline b) =>
      prefs.setString(restorePointKey(b.tvId), jsonEncode(b.toJson()));
}

// ── pure planning and checks ──

/// One batch per group (in the order given) of the selected apps that are
/// still on. Groups with nothing to do are left out.
List<WizardBatch> planBatches(
  List<WizardBatch> pendingByGroup,
  Set<String> selected,
) =>
    [
      for (final g in pendingByGroup)
        if (g.pkgs.where(selected.contains).toList() case final pkgs
            when pkgs.isNotEmpty)
          WizardBatch(group: g.group, title: g.title, pkgs: pkgs),
    ];

/// The batch's apps that are off now, so an undo switches them back on.
List<String> undoTargets(WizardBatch b, PackageSnapshot snap) => [
      for (final p in b.pkgs)
        if (snap.state(p) == AppState.disabled) p,
    ];

/// Turns what was read after a restart into the four check rows. The TV
/// Guard row is there only when [guardHealthy] is not null (installed).
List<WizardCheck> evaluateChecks({
  required WizardBatch batch,
  required bool connected,
  PackageSnapshot? packages,
  LauncherHealth? launcher,
  bool hasLauncherSpec = true,
  bool? guardHealthy,
  String Function(String pkg) label = _same,
}) {
  final back = [
    if (packages != null)
      for (final p in batch.pkgs)
        if (packages.state(p) == AppState.enabled) p,
  ];
  final home = launcher == null
      ? false
      : hasLauncherSpec
          ? launcher.ok
          : launcher.homeComponent != null;
  return [
    WizardCheck(
      WizardCheckId.appsOff,
      ok: packages != null && back.isEmpty,
      detail: packages == null
          ? 'Couldn\'t read the apps'
          : back.map(label).join(', '),
      count: back.length,
    ),
    WizardCheck(
      WizardCheckId.connected,
      ok: connected,
      detail: connected ? '' : 'The TV isn\'t answering on Wi-Fi',
    ),
    WizardCheck(
      WizardCheckId.home,
      ok: home,
      detail: home
          ? ''
          : launcher == null
              ? 'Couldn\'t ask the TV'
              : 'Home opens something else',
    ),
    if (guardHealthy != null)
      WizardCheck(
        WizardCheckId.guard,
        ok: guardHealthy,
        detail: guardHealthy ? '' : 'TV Guard isn\'t answering yet',
      ),
  ];
}

String _same(String s) => s;

bool checksPassed(List<WizardCheck> checks) =>
    checks.isNotEmpty && checks.every((c) => c.ok);

/// Decides when a restarted TV is really back. Right after `reboot` the
/// old session may still answer for a moment, so an answer only counts
/// once the TV was seen gone, or after [trustAfter] (e.g. on resume, when
/// nobody was watching it go down).
class ComebackTracker {
  final Duration trustAfter;
  bool sawDown;

  ComebackTracker({
    this.trustAfter = const Duration(seconds: 90),
    this.sawDown = false,
  });

  /// Records one look. True when the TV counts as back.
  bool look({required bool answered, required Duration sinceRestart}) {
    if (!answered) {
      sawDown = true;
      return false;
    }
    return sawDown || sinceRestart >= trustAfter;
  }
}

// ── the controller ──

/// Timings, overridable in tests.
@immutable
class WizardTiming {
  /// Wait after the last write before a restart.
  final Duration save;

  /// Screen tick (countdowns).
  final Duration tick;

  /// How often to look for the TV after a restart, and when to start.
  final Duration poll;
  final Duration firstPoll;
  final Duration trustAfter;

  /// Give up waiting (with a helpful message) after this long.
  final Duration timeout;

  const WizardTiming({
    this.save = TvOps.rebootSettle,
    this.tick = const Duration(seconds: 1),
    this.poll = const Duration(seconds: 5),
    this.firstPoll = const Duration(seconds: 15),
    this.trustAfter = const Duration(seconds: 90),
    this.timeout = const Duration(minutes: 4),
  });
}

/// The reads the wizard needs beyond [TvOps]: whether the TV is back
/// (session reconnect and a capability probe) and whether TV Guard
/// answers (null when it isn't installed).
@immutable
class WizardProbes {
  final Future<bool> Function() tvBack;
  final Future<bool?> Function() guardHealthy;

  const WizardProbes({required this.tvBack, required this.guardHealthy});
}

/// Drives the wizard: persists every phase change, runs the batch writes
/// through [TvOps], waits, restarts, waits for the TV and checks it.
class CleanWizard extends ChangeNotifier {
  final String tvId;
  final WizardProgressStore store;
  final Future<TvOps?> Function() ops;
  final WizardProbes probes;
  final Journal? journal;
  final BaselineStore? baselines;
  final DateTime Function() clock;
  final WizardTiming timing;

  /// Plain app names for check details.
  final String Function(String pkg) label;

  CleanWizard({
    required this.tvId,
    required this.store,
    required this.ops,
    required this.probes,
    this.journal,
    this.baselines,
    this.clock = DateTime.now,
    this.timing = const WizardTiming(),
    this.label = _same,
  }) : progress = store.read(tvId) ?? const WizardProgress();

  WizardProgress progress;

  /// A write or read is running (buttons wait).
  bool busy = false;

  /// What went wrong last, shown on the current step.
  Object? error;

  /// Per-app result while switching off (null: not done yet).
  Map<String, bool?> live = {};

  /// Saving: time left. Restarting: time waited, and whether it's been
  /// too long.
  Duration saveLeft = Duration.zero;
  Duration waited = Duration.zero;
  bool timedOut = false;

  Timer? _timer;
  DateTime? _waitFrom;
  DateTime? _lastPoll;
  bool _polling = false;
  ComebackTracker? _tracker;
  bool _disposed = false;

  Future<void> _save(WizardProgress p) async {
    progress = p;
    _notify();
    await store.write(tvId, p);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  /// Picks the flow back up after the screen opens.
  Future<void> resume() async {
    if (progress.step == WizardStep.done) return logSummary();
    if (progress.step != WizardStep.batch) return;
    switch (progress.phase) {
      case BatchPhase.disabling:
        await runBatch();
      case BatchPhase.saving:
        _startSaving();
      case BatchPhase.restarting:
        _startWaiting();
      case BatchPhase.checking:
        await _check();
      case BatchPhase.restart || BatchPhase.failed || BatchPhase.undone:
        break;
    }
  }

  // ── step 1: restore point ──

  Future<void> captureRestorePoint() async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      final o = await ops();
      if (o == null) throw StateError('The TV isn\'t connected');
      final b = await TvBaseline.capture(o, clock: clock);
      await store.writeRestorePoint(b);
      // The first baseline is kept forever; this run may be the first.
      final bs = baselines;
      if (bs != null && bs.read(tvId) == null) await bs.write(b);
      busy = false;
      await _save(
        progress.copyWith(
          step: WizardStep.choose,
          restorePointAt: b.capturedAt,
        ),
      );
    } catch (e) {
      busy = false;
      error = e;
      _notify();
    }
  }

  // ── step 2: choose ──

  Future<void> select(Set<String> selected) =>
      _save(progress.copyWith(selected: selected));

  /// Starts the first batch.
  Future<void> start(List<WizardBatch> batches) async {
    if (batches.isEmpty) return;
    await _save(
      progress.copyWith(
        step: WizardStep.batch,
        batches: batches,
        current: 0,
        phase: BatchPhase.disabling,
        clearPhaseAt: true,
        kept: const [],
        undone: const [],
        checks: const [],
        undoResult: const {},
        restartSkipped: false,
      ),
    );
    await runBatch();
  }

  // ── step 3: one batch ──

  /// Switches the batch's apps off, one at a time, each verified and
  /// journaled by [TvOps.setAppEnabled]. Apps already off are skipped.
  Future<void> runBatch() async {
    final b = progress.batch;
    if (b == null || busy) return;
    busy = true;
    error = null;
    live = {for (final p in b.pkgs) p: null};
    _notify();
    try {
      final o = await ops();
      if (o == null) throw StateError('The TV isn\'t connected');
      final snap = await o.packages();
      for (final p in b.pkgs) {
        if (snap.state(p) != AppState.enabled) {
          live[p] = snap.state(p) != AppState.absent;
        } else {
          final e = await o.setAppEnabled(p, false);
          live[p] = e.ok;
        }
        _notify();
      }
      busy = false;
      await _save(
        progress.copyWith(
          phase: BatchPhase.saving,
          phaseAt: o.lastPackageWrite ?? clock(),
          restartSkipped: false,
          checks: const [],
        ),
      );
      _startSaving();
    } catch (e) {
      busy = false;
      error = e;
      _notify();
    }
  }

  Duration _left() {
    final at = progress.phaseAt ?? clock();
    final left = timing.save - clock().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  void _startSaving() {
    _timer?.cancel();
    saveLeft = _left();
    _notify();
    if (saveLeft == Duration.zero) {
      unawaited(_save(progress.copyWith(phase: BatchPhase.restart)));
      return;
    }
    _timer = Timer.periodic(timing.tick, (t) {
      saveLeft = _left();
      if (saveLeft == Duration.zero) {
        t.cancel();
        unawaited(_save(progress.copyWith(phase: BatchPhase.restart)));
      } else {
        _notify();
      }
    });
  }

  /// Restarts the TV through [TvOps.restartTv].
  Future<void> restart() async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      final o = await ops();
      if (o == null) throw StateError('The TV isn\'t connected');
      final e = await o.restartTv();
      busy = false;
      if (!e.ok) {
        error = StateError('The TV didn\'t restart');
        _notify();
        return;
      }
      await _save(
        progress.copyWith(phase: BatchPhase.restarting, phaseAt: clock()),
      );
      _startWaiting();
    } on RestartTooSoonException catch (e) {
      // Too soon after a write: back to saving for the time left.
      busy = false;
      await _save(
        progress.copyWith(
          phase: BatchPhase.saving,
          phaseAt: clock().subtract(timing.save - e.wait),
        ),
      );
      _startSaving();
    } catch (e) {
      busy = false;
      error = e;
      _notify();
    }
  }

  /// Checks without restarting.
  Future<void> skipRestart() async {
    if (busy) return;
    await _save(progress.copyWith(restartSkipped: true));
    await _check();
  }

  void _startWaiting() {
    _timer?.cancel();
    timedOut = false;
    _waitFrom = clock();
    _lastPoll = null;
    _tracker = ComebackTracker(trustAfter: timing.trustAfter);
    _tickWait();
    _timer = Timer.periodic(timing.tick, (_) => _tickWait());
  }

  /// After the 4 minutes: keep looking for another 4.
  void keepWaiting() => _startWaiting();

  void _tickWait() {
    final at = progress.phaseAt ?? clock();
    final now = clock();
    waited = now.difference(at);
    if (!timedOut && now.difference(_waitFrom ?? now) >= timing.timeout) {
      timedOut = true;
    }
    _notify();
    final last = _lastPoll;
    final due = waited >= timing.firstPoll &&
        (last == null || now.difference(last) >= timing.poll);
    if (due && !_polling) unawaited(_poll());
  }

  Future<void> _poll() async {
    _polling = true;
    _lastPoll = clock();
    var answered = false;
    try {
      answered = await probes.tvBack();
    } catch (_) {
      answered = false;
    }
    _polling = false;
    if (_disposed || progress.phase != BatchPhase.restarting) return;
    final since = clock().difference(progress.phaseAt ?? clock());
    if (_tracker!.look(answered: answered, sinceRestart: since)) {
      _timer?.cancel();
      timedOut = false;
      await _check();
    }
  }

  /// Checks the batch: its apps still off, the TV connected, Home opens the
  /// launcher, and TV Guard answers if it's installed.
  Future<void> _check() async {
    final b = progress.batch;
    if (b == null) return;
    await _save(
      progress.copyWith(phase: BatchPhase.checking, checks: const []),
    );
    busy = true;
    _notify();
    final checks = await runChecks(b);
    busy = false;
    final ok = checksPassed(checks);
    await _save(
      progress.copyWith(
        phase: ok ? BatchPhase.checking : BatchPhase.failed,
        checks: checks,
      ),
    );
  }

  /// Retries the checks (after a failure, or once the TV is back).
  Future<void> checkAgain() => _check();

  Future<List<WizardCheck>> runChecks(WizardBatch b) async {
    PackageSnapshot? snap;
    LauncherHealth? home;
    var connected = false;
    TvOps? o;
    try {
      o = await ops();
      if (o != null) {
        snap = await o.packages();
        connected = true;
        home = await o.launcherHealth();
      }
    } catch (_) {
      // Shown as failed rows below.
    }
    bool? guard;
    try {
      guard = await probes.guardHealthy();
    } catch (_) {
      guard = false;
    }
    return evaluateChecks(
      batch: b,
      connected: connected,
      packages: snap,
      launcher: home,
      hasLauncherSpec: o?.profile.launcher != null,
      guardHealthy: guard,
      label: label,
    );
  }

  /// True once the current batch's checks are in and all passed.
  bool get checksDone =>
      progress.phase == BatchPhase.checking &&
      !busy &&
      checksPassed(progress.checks);

  // ── step 4: a failed check ──

  /// Switches the current batch's apps back on, each verified.
  Future<void> undoBatch() async {
    final b = progress.batch;
    if (b == null || busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      final o = await ops();
      if (o == null) throw StateError('The TV isn\'t connected');
      final targets = undoTargets(b, await o.packages());
      final result = <String, bool>{};
      for (final p in targets) {
        result[p] = (await o.setAppEnabled(p, true)).ok;
      }
      busy = false;
      await _save(
        progress.copyWith(
          phase: BatchPhase.undone,
          undoResult: result,
          undone: [...progress.undone, progress.current],
        ),
      );
    } catch (e) {
      busy = false;
      error = e;
      _notify();
    }
  }

  /// Keeps the batch despite the failed check, and moves on.
  Future<void> keepGoing() => next();

  /// Moves to the next batch (or the end). A batch that wasn't put back
  /// counts as kept.
  Future<void> next() async {
    if (busy) return;
    final i = progress.current;
    final kept = progress.undone.contains(i) || progress.kept.contains(i)
        ? progress.kept
        : [...progress.kept, i];
    if (progress.isLastBatch) {
      await _save(progress.copyWith(step: WizardStep.done, kept: kept));
      await logSummary();
      return;
    }
    await _save(
      progress.copyWith(
        current: i + 1,
        phase: BatchPhase.disabling,
        clearPhaseAt: true,
        kept: kept,
        checks: const [],
        undoResult: const {},
        restartSkipped: false,
      ),
    );
    await runBatch();
  }

  // ── step 5: done ──

  /// One History line for the whole run (once).
  Future<void> logSummary() async {
    if (progress.summaryLogged) return;
    final p = progress;
    final groups = [
      for (var i = 0; i < p.batches.length; i++)
        p.undone.contains(i)
            ? '${p.batches[i].title}: put back'
            : '${p.batches[i].title}: ${p.batches[i].pkgs.length}',
    ];
    await journal?.add(
      JournalEntry(
        tvId: tvId,
        time: clock(),
        op: 'cleanWizard',
        target: '${p.tidiedCount}',
        before: '',
        after: groups.join(' · '),
        ok: true,
      ),
    );
    await _save(p.copyWith(summaryLogged: true));
  }

  /// Ends the run; the next open starts fresh.
  Future<void> finish() async {
    _timer?.cancel();
    await store.clear(tvId);
    progress = const WizardProgress();
  }
}
