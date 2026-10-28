import '../agent/agent_models.dart' show RestoreTarget, kAgentPackage;
import 'baseline.dart';
import 'device_profile.dart';
import 'journal.dart';
import 'tv_ops.dart';

/// Google TV's own Home (what HOME resolves to without a custom launcher).
const kStockHome = 'com.google.android.apps.tv.launcherx/.home.HomeActivity';

enum RestoreStepKind {
  uninstallAgent,
  enable,
  installExisting,
  removeLauncherHelper,
  setHome,
  note,
}

/// One explicit step of a restore: what it does in plain words and the
/// exact shell command. [RestoreStepKind.note] steps run nothing.
class RestoreStep {
  final RestoreStepKind kind;
  final String title;
  final String why;
  final String? command;
  final String? pkg;

  const RestoreStep({
    required this.kind,
    required this.title,
    this.why = '',
    this.command,
    this.pkg,
  });

  bool get runs => command != null;

  @override
  String toString() => command ?? '# $title';
}

class RestorePlan {
  final RestoreTarget target;
  final List<RestoreStep> steps;

  const RestorePlan(this.target, this.steps);

  List<RestoreStep> get actions => [
        for (final s in steps)
          if (s.runs) s,
      ];

  List<String> get commands => [for (final s in actions) s.command!];

  bool get isEmpty => actions.isEmpty;
}

/// Turns the TV's current state (plus the journal and the baseline) into
/// an explicit restore plan. Pure: tests check the exact command lists.
///
/// The agent is removed first, so its watchdog can't undo the restore
/// while it runs. Never-touch packages are never written (the agent's own
/// uninstall is the one exception, and only through its dedicated step).
class RestorePlanner {
  static RestorePlan plan({
    required RestoreTarget target,
    required DeviceProfile profile,
    required PackageSnapshot packages,
    required LauncherHealth launcher,
    List<JournalEntry> journal = const [],
    TvBaseline? baseline,
    bool removeLauncherHelper = false,
  }) {
    final neverTouch = {...kBaselineNeverTouch, ...profile.neverTouch}
      ..remove(kAgentPackage);
    final steps = <RestoreStep>[];
    final planned = <String>{};

    bool allowed(String pkg) {
      try {
        TvOps.checkPackage(pkg);
      } on InvalidPackageException {
        return false;
      }
      return !neverTouch.contains(pkg) && pkg != kAgentPackage;
    }

    final notes = {
      for (final c in [...profile.cleanup, ...profile.extras])
        if (c.comment.isNotEmpty) c.pkg: c.comment,
    };
    String name(String pkg) => notes[pkg] ?? _label(pkg);
    String whyFor(String pkg, String why) =>
        name(pkg) == pkg ? why : '$pkg · $why';

    void enable(String pkg, String why) {
      if (!allowed(pkg) || !planned.add(pkg)) return;
      switch (packages.state(pkg)) {
        case AppState.disabled:
          steps.add(
            RestoreStep(
              kind: RestoreStepKind.enable,
              title: 'Turn on ${name(pkg)}',
              why: whyFor(pkg, why),
              command: 'pm enable $pkg',
              pkg: pkg,
            ),
          );
        case AppState.notInstalled:
          steps.add(
            RestoreStep(
              kind: RestoreStepKind.installExisting,
              title: 'Put back ${name(pkg)}',
              why: whyFor(pkg, why),
              command: 'cmd package install-existing $pkg',
              pkg: pkg,
            ),
          );
        case AppState.enabled:
        case AppState.absent:
          break;
      }
    }

    // 1. The agent goes first.
    final agent = packages.state(kAgentPackage);
    if (agent == AppState.enabled || agent == AppState.disabled) {
      steps.add(
        const RestoreStep(
          kind: RestoreStepKind.uninstallAgent,
          title: 'Remove TV Guard',
          why: 'Stops boretube\'s rules and watchdog on the TV',
          command: 'pm uninstall $kAgentPackage',
          pkg: kAgentPackage,
        ),
      );
    }

    final yt = profile.stockYouTube;
    switch (target) {
      case RestoreTarget.undoBoretube:
        final undo = _journalEffects(journal);
        for (final p in undo.disabled) {
          enable(p, 'boretube turned it off');
        }
        // Profile-managed packages the baseline saw on but are off now
        // (e.g. turned off by the agent's watchdog while it was away).
        final b = baseline;
        if (b != null) {
          for (final p in [
            for (final c in profile.cleanup) c.pkg,
            for (final e in profile.extras) e.pkg,
            ...?yt?.companions,
          ]) {
            if (!b.wasDisabled(p) && packages.state(p) == AppState.disabled) {
              enable(p, 'was on when boretube first connected');
            }
          }
        }
        if (yt != null) {
          final wasThere = b != null &&
              (b.stockYouTube == AppState.enabled.name ||
                  b.stockYouTube == AppState.disabled.name);
          if (undo.youTubeRemoved || wasThere) {
            enable(yt.pkg, 'boretube removed stock YouTube');
          }
        }
        steps.add(
          const RestoreStep(
            kind: RestoreStepKind.note,
            title: 'Speech services and Home repairs are kept',
            why: 'Rolling speech back and repairing Home fixed real '
                'problems; undoing them would break voice search or Home.',
          ),
        );
      case RestoreTarget.stock:
        for (final c in profile.cleanup) {
          enable(c.pkg, 'on the clean-up list');
        }
        for (final e in profile.extras) {
          enable(e.pkg, 'optional clean-up app');
        }
        if (yt != null) {
          enable(yt.pkg, 'stock YouTube');
          for (final c in yt.companions) {
            enable(c, 'YouTube Music');
          }
        }
        steps.add(
          const RestoreStep(
            kind: RestoreStepKind.note,
            title: 'Speech services update on their own',
            why: 'Nothing to do: Google Play updates them again.',
          ),
        );
        final spec = profile.launcher;
        if (removeLauncherHelper && spec != null) {
          final helper = TvOps.normalizeComponent(spec.a11yService);
          final rest = [
            for (final s in launcher.a11yServices)
              if (TvOps.normalizeComponent(s) != helper) s,
          ];
          if (launcher.helperEnabled) {
            final safe = rest.every(_componentPattern.hasMatch);
            steps.add(
              RestoreStep(
                kind: RestoreStepKind.removeLauncherHelper,
                title: 'Turn off the custom launcher\'s Home helper',
                why: rest.isEmpty
                    ? 'It was the only accessibility service'
                    : 'Keeps ${rest.length} other accessibility '
                        'service${rest.length == 1 ? '' : 's'}',
                command: !safe
                    ? null
                    : rest.isEmpty
                        ? 'settings delete secure '
                            'enabled_accessibility_services && '
                            'settings put secure accessibility_enabled 0'
                        : 'settings put secure '
                            "enabled_accessibility_services '"
                            "${rest.join(':')}'",
                pkg: spec.pkg,
              ),
            );
          }
          final home = launcher.homeComponent;
          if (home != null && home.startsWith('${spec.pkg}/')) {
            steps.add(
              const RestoreStep(
                kind: RestoreStepKind.setHome,
                title: 'Make Google TV Home the home screen',
                command: 'cmd package set-home-activity $kStockHome',
              ),
            );
          }
        }
    }
    steps.add(
      const RestoreStep(
        kind: RestoreStepKind.note,
        title: 'Wait a minute before restarting the TV',
        why: 'Changes need about 60 s to be saved; a restart sooner can '
            'lose them.',
      ),
    );
    return RestorePlan(target, steps);
  }

  static final _componentPattern = RegExp(r'^[a-zA-Z0-9_.$]+/[a-zA-Z0-9_.$]+$');

  static String _label(String pkg) => switch (pkg) {
        'com.google.android.youtube.tv' => 'YouTube',
        'com.google.android.youtube.tvmusic' => 'YouTube Music',
        _ => pkg,
      };

  /// Net effect of boretube's own journaled writes (oldest first).
  static ({List<String> disabled, bool youTubeRemoved}) _journalEffects(
    List<JournalEntry> journal,
  ) {
    final sorted = [...journal]..sort((a, b) => a.time.compareTo(b.time));
    final disabled = <String>[];
    var yt = false;
    for (final e in sorted) {
      if (!e.ok) continue;
      switch (e.op) {
        case 'disableApp' || 'applyCleanup':
          if (!disabled.contains(e.target)) disabled.add(e.target);
        case 'enableApp' || 'undoCleanup':
          disabled.remove(e.target);
        case 'stockYouTubeOff':
          yt = true;
        case 'stockYouTubeOn':
          yt = false;
      }
    }
    return (disabled: disabled, youTubeRemoved: yt);
  }
}

class RestoreStepResult {
  final RestoreStep step;
  final bool ok;
  final String before;
  final String after;
  final String detail;

  const RestoreStepResult({
    required this.step,
    required this.ok,
    this.before = '',
    this.after = '',
    this.detail = '',
  });
}

/// Runs a [RestorePlan] over ADB (no agent needed). Each step is
/// journaled and verified with a fresh read; a failed step doesn't stop
/// the rest.
class RestoreRunner {
  final TvOps ops;
  final Journal? journal;
  final DateTime Function() _clock;

  RestoreRunner(this.ops, {this.journal, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Reads the TV and plans [target].
  Future<RestorePlan> plan(
    RestoreTarget target, {
    TvBaseline? baseline,
    bool removeLauncherHelper = false,
  }) async {
    final packages = await ops.packages();
    final launcher = await ops.launcherHealth();
    final entries = await journal?.entries(ops.tvId) ?? const [];
    return RestorePlanner.plan(
      target: target,
      profile: ops.profile,
      packages: packages,
      launcher: launcher,
      journal: entries,
      baseline: baseline,
      removeLauncherHelper: removeLauncherHelper,
    );
  }

  Future<List<RestoreStepResult>> run(
    RestorePlan plan, {
    void Function(int index, RestoreStepResult result)? onStep,
  }) async {
    final out = <RestoreStepResult>[];
    final actions = plan.actions;
    for (var i = 0; i < actions.length; i++) {
      final r = await _runStep(actions[i], plan.target);
      out.add(r);
      onStep?.call(i, r);
    }
    return out;
  }

  Future<String> _read(RestoreStep s) async {
    switch (s.kind) {
      case RestoreStepKind.removeLauncherHelper:
        final h = await ops.launcherHealth();
        return h.helperEnabled ? 'helper on' : 'helper off';
      case RestoreStepKind.setHome:
        return (await ops.launcherHealth()).homeComponent ?? 'none';
      case RestoreStepKind.uninstallAgent:
      case RestoreStepKind.enable:
      case RestoreStepKind.installExisting:
        return (await ops.packages()).state(s.pkg!).name;
      case RestoreStepKind.note:
        return '';
    }
  }

  static bool _verified(RestoreStep s, String after) => switch (s.kind) {
        RestoreStepKind.uninstallAgent =>
          after == AppState.absent.name || after == AppState.notInstalled.name,
        RestoreStepKind.enable => after == AppState.enabled.name,
        RestoreStepKind.installExisting =>
          after == AppState.enabled.name || after == AppState.disabled.name,
        RestoreStepKind.removeLauncherHelper => after == 'helper off',
        RestoreStepKind.setHome => after == kStockHome ||
            TvOps.normalizeComponent(after) ==
                TvOps.normalizeComponent(kStockHome),
        RestoreStepKind.note => true,
      };

  Future<RestoreStepResult> _runStep(
    RestoreStep s,
    RestoreTarget target,
  ) async {
    var before = '';
    var after = '';
    var ok = false;
    var detail = '';
    try {
      before = await _read(s);
      final r = await ops.adb.shell(s.command!);
      after = await _read(s);
      ok = r.ok && _verified(s, after);
      if (!ok) {
        detail = r.ok ? 'TV reports $after' : r.stdout.trim();
      }
    } catch (e) {
      detail = '$e';
    }
    await journal?.add(
      JournalEntry(
        tvId: ops.tvId,
        time: _clock(),
        op: 'restore',
        target: '${s.pkg ?? s.kind.name} (${target.name})',
        before: before,
        after: after.isEmpty ? detail : after,
        ok: ok,
      ),
    );
    return RestoreStepResult(
      step: s,
      ok: ok,
      before: before,
      after: after,
      detail: detail,
    );
  }
}
