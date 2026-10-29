import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adb/adb_connection.dart';
import 'device_profile.dart';
import 'journal.dart';

/// Packages no op may write to, whatever the profile says.
const kBaselineNeverTouch = {
  'android',
  'com.android.systemui',
  'com.android.settings',
  'com.android.tv.settings',
  'com.android.vending',
  'com.google.android.gms',
  'com.rakesh.boretube.agent',
};

/// Packages that must not be force-stopped: system, Home, input/key
/// plumbing and the agent. Ordinary apps on the never-touch list (e.g.
/// SmartTube) may be stopped; they just can't be disabled or removed.
const kNeverStop = {
  'android',
  'com.android.systemui',
  'com.google.android.gms',
  'com.google.android.katniss',
  'com.google.android.apps.tv.launcherx',
  'com.google.android.tungsten.setupwraith',
  'com.realtek.advancesetting',
  'com.realtek.dtv',
  'com.realtek.tv.passthrough',
  'com.sony.dtv.smartui',
  'com.rakesh.boretube.agent',
};

const kTtsPackage = 'com.google.android.tts';

final _pkgPattern = RegExp(r'^[a-zA-Z0-9_.]+$');
final _componentPattern = RegExp(r'^[a-zA-Z0-9_.$]+/[a-zA-Z0-9_.$]+$');

class NeverTouchException implements Exception {
  final String pkg;
  const NeverTouchException(this.pkg);
  @override
  String toString() => 'NeverTouchException: $pkg is protected';
}

class InvalidPackageException implements Exception {
  final String value;
  const InvalidPackageException(this.value);
  @override
  String toString() => 'InvalidPackageException: "$value"';
}

/// Maintenance writes on a read-only (generic) profile need opt-in.
class ReadOnlyProfileException implements Exception {
  final String profileId;
  const ReadOnlyProfileException(this.profileId);
  @override
  String toString() =>
      'ReadOnlyProfileException: profile $profileId is read-only';
}

/// A restart was asked for too soon after a package change: the TV keeps
/// package state in memory for a while, and a reboot before
/// [TvOps.rebootSettle] has passed loses the change (verified on the VU3).
class RestartTooSoonException implements Exception {
  /// How much longer to wait.
  final Duration wait;
  const RestartTooSoonException(this.wait);
  @override
  String toString() => 'RestartTooSoonException: wait ${wait.inSeconds} s more';
}

enum AppState { enabled, disabled, notInstalled, absent }

/// `pm list packages` -u / plain / -d in one read.
class PackageSnapshot {
  /// Every package on the system image or installed (`-u`).
  final Set<String> all;

  /// Installed for user 0.
  final Set<String> installed;
  final Set<String> disabled;

  const PackageSnapshot({
    required this.all,
    required this.installed,
    required this.disabled,
  });

  static const command = 'pm list packages -u; echo ---; '
      'pm list packages; echo ---; pm list packages -d';

  factory PackageSnapshot.parse(String out) {
    final parts = out.split(RegExp(r'^---\s*$', multiLine: true));
    Set<String> at(int i) =>
        i < parts.length ? TvOps.parsePackageList(parts[i]) : <String>{};
    return PackageSnapshot(all: at(0), installed: at(1), disabled: at(2));
  }

  AppState state(String pkg) {
    if (!all.contains(pkg) && !installed.contains(pkg)) {
      return AppState.absent;
    }
    if (!installed.contains(pkg)) return AppState.notInstalled;
    if (disabled.contains(pkg)) return AppState.disabled;
    return AppState.enabled;
  }
}

class TvApp {
  final String pkg;

  /// Leanback launcher activity, when the app is launchable now.
  final String? activity;
  final AppState state;

  /// In the never-touch list: the UI must not offer disable.
  final bool protected;

  const TvApp({
    required this.pkg,
    this.activity,
    required this.state,
    required this.protected,
  });

  bool get launchable => activity != null;

  @override
  String toString() => '$pkg ${state.name}${protected ? ' (protected)' : ''}';
}

class PackageVersion {
  final String versionName;
  final bool updatedSystemApp;
  final bool? installedForUser0;
  const PackageVersion({
    required this.versionName,
    required this.updatedSystemApp,
    this.installedForUser0,
  });
}

class SpeechDecision {
  final bool needed;
  final String reason;
  final String? currentVersion;
  final String? knownGood;
  const SpeechDecision({
    required this.needed,
    required this.reason,
    this.currentVersion,
    this.knownGood,
  });

  /// True when the installed version is the profile's known-good one.
  bool get atKnownGood => currentVersion != null && currentVersion == knownGood;
}

class LauncherHealth {
  final String? homeComponent;
  final bool homeIsLauncher;
  final List<String> a11yServices;
  final bool helperEnabled;
  final bool a11yEnabled;
  final String rawServices;

  const LauncherHealth({
    required this.homeComponent,
    required this.homeIsLauncher,
    required this.a11yServices,
    required this.helperEnabled,
    required this.a11yEnabled,
    required this.rawServices,
  });

  /// Home lands in the launcher directly, or via its a11y helper.
  bool get ok => homeIsLauncher || (helperEnabled && a11yEnabled);
}

class VolumeState {
  final int level;
  final int min;
  final int max;
  final bool muted;
  const VolumeState({
    required this.level,
    required this.min,
    required this.max,
    required this.muted,
  });

  int get percent =>
      max <= min ? 0 : ((level - min) * 100 / (max - min)).round();

  @override
  String toString() => '$level/$max${muted ? ' muted' : ''}';
}

class CleanupStatus {
  /// Profile targets present on this TV.
  final List<String> present;
  final List<String> disabled;
  final List<String> pending;
  final List<String> absent;

  const CleanupStatus({
    required this.present,
    required this.disabled,
    required this.pending,
    required this.absent,
  });

  bool get complete => pending.isEmpty;
}

class StopOutcome {
  /// Foreground package before the stop, if any.
  final String? pkg;
  final bool forceStopped;
  final bool sentHome;
  final JournalEntry? entry;
  final String detail;

  const StopOutcome({
    this.pkg,
    this.forceStopped = false,
    this.sentHome = false,
    this.entry,
    this.detail = '',
  });
}

/// Typed, guarded TV operations over ADB. Every write refuses protected
/// packages, re-reads state to verify, and records a [JournalEntry].
class TvOps {
  final AdbShell adb;
  final DeviceProfile profile;
  final String tvId;
  final Journal? journal;

  /// Lets maintenance ops run on a read-only (generic) profile.
  final bool maintenanceUnlocked;
  final DateTime Function() _now;

  TvOps({
    required this.adb,
    required this.profile,
    required this.tvId,
    this.journal,
    this.maintenanceUnlocked = false,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  Set<String> get neverTouch => {...kBaselineNeverTouch, ...profile.neverTouch};

  bool isProtected(String pkg) => neverTouch.contains(pkg);

  bool isStopProtected(String pkg) =>
      kNeverStop.contains(pkg) || pkg == profile.launcher?.pkg;

  // ── guards ──

  static String checkPackage(String pkg) {
    if (!_pkgPattern.hasMatch(pkg)) throw InvalidPackageException(pkg);
    return pkg;
  }

  String _guard(String pkg) {
    checkPackage(pkg);
    if (isProtected(pkg)) throw NeverTouchException(pkg);
    return pkg;
  }

  void _requireMaintenance() {
    if (profile.readOnly && !maintenanceUnlocked) {
      throw ReadOnlyProfileException(profile.id);
    }
  }

  Future<AdbShellResult> _sh(String cmd, {bool urgent = false}) {
    final a = adb;
    return urgent && a is PriorityAdbShell ? a.shellUrgent(cmd) : a.shell(cmd);
  }

  // ── package writes and restarts ──

  /// How long the TV needs after a package change before a reboot keeps
  /// it (profile quirk `rebootWait60s`).
  static const rebootSettle = Duration(seconds: 60);

  static const rebootCommand = 'reboot';

  DateTime? _lastPackageWrite;

  /// When this TvOps last changed package state (enable, disable,
  /// install, remove, roll back), or null.
  DateTime? get lastPackageWrite => _lastPackageWrite;

  void _notePackageWrite() => _lastPackageWrite = _now();

  /// How much longer a restart must wait; zero when it may go now.
  Duration get restartWait {
    final at = _lastPackageWrite;
    if (at == null) return Duration.zero;
    final left = rebootSettle - _now().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  /// Restarts the TV (`reboot`). Refuses with [RestartTooSoonException]
  /// within [rebootSettle] of the last package write. Checks the TV
  /// answers first, so a throw before the reboot means nothing was sent;
  /// the connection dropping while the reboot goes out is expected.
  Future<JournalEntry> restartTv() async {
    _requireMaintenance();
    final wait = restartWait;
    if (wait > Duration.zero) throw RestartTooSoonException(wait);
    await _sh('echo ok');
    AdbShellResult? r;
    try {
      r = await _sh(rebootCommand);
    } catch (_) {
      // The TV went down while answering: the reboot is under way.
      r = null;
    }
    return _record(
      op: 'restartTv',
      target: 'tv',
      before: 'on',
      after: r == null
          ? 'restarting (connection dropped)'
          : r.ok
              ? 'restarting'
              : 'refused: ${r.stdout.trim()}',
      ok: r == null || r.ok,
    );
  }

  // ── last known state (from polls and actions) ──

  /// How long a polled foreground / volume counts as current enough to
  /// plan an action from. Every action re-reads in the same round trip and
  /// corrects itself when the cache was stale.
  static const cacheTtl = Duration(seconds: 20);

  VolumeState? _volume;
  String? _foreground;
  DateTime? _volumeAt;
  DateTime? _foregroundAt;

  bool _fresh(DateTime? at) =>
      at != null && _now().difference(at).abs() < cacheTtl;

  /// Last volume read, if recent.
  VolumeState? get cachedVolume => _fresh(_volumeAt) ? _volume : null;

  /// Last foreground package read, if recent.
  String? get cachedForeground => _fresh(_foregroundAt) ? _foreground : null;

  VolumeState? _seeVolume(VolumeState? v) {
    if (v != null) {
      _volume = v;
      _volumeAt = _now();
    }
    return v;
  }

  String? _seeForeground(String? pkg) {
    _foreground = pkg;
    _foregroundAt = pkg == null ? null : _now();
    return pkg;
  }

  static List<String> _sections(String out) =>
      out.split(RegExp(r'^---\s*$', multiLine: true));

  static String _at(List<String> parts, int i) =>
      i < parts.length ? parts[i] : '';

  Future<JournalEntry> _record({
    required String op,
    required String target,
    required String before,
    required String after,
    String? undo,
    required bool ok,
  }) async {
    final e = JournalEntry(
      tvId: tvId,
      time: _now(),
      op: op,
      target: target,
      before: before,
      after: after,
      undoCommand: undo,
      ok: ok,
    );
    await journal?.add(e);
    return e;
  }

  // ── reads ──

  Future<PackageSnapshot> packages() async =>
      PackageSnapshot.parse((await _sh(PackageSnapshot.command)).stdout);

  Future<AppState> appState(String pkg) async =>
      (await packages()).state(checkPackage(pkg));

  Future<PackageVersion?> packageVersion(String pkg) async =>
      parsePackageVersion(
        (await _sh('dumpsys package ${checkPackage(pkg)}')).stdout,
      );

  static const leanbackQuery = 'cmd package query-activities --brief '
      '-a android.intent.action.MAIN '
      '-c android.intent.category.LEANBACK_LAUNCHER';

  /// Launchable leanback apps plus disabled / uninstalled-for-user ones.
  Future<List<TvApp>> listApps() async {
    final snap = await packages();
    final launchers =
        parseLeanbackActivities((await _sh(leanbackQuery)).stdout);
    final pkgs = {
      ...launchers.keys,
      ...snap.disabled,
      ...snap.all.difference(snap.installed),
    };
    final apps = [
      for (final p in pkgs)
        TvApp(
          pkg: p,
          activity: launchers[p],
          state: snap.state(p),
          protected: isProtected(p),
        ),
    ]..sort((a, b) => a.pkg.compareTo(b.pkg));
    return apps;
  }

  static const volumeCommand = "dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'";

  Future<VolumeState?> readVolume({bool urgent = false}) async => _seeVolume(
        parseVolume((await _sh(volumeCommand, urgent: urgent)).stdout),
      );

  static const foregroundCommand =
      'dumpsys activity activities | grep -m1 topResumedActivity';

  Future<String?> foregroundPackage({bool urgent = false}) async =>
      _seeForeground(
        parseTopResumed((await _sh(foregroundCommand, urgent: urgent)).stdout),
      );

  /// The screen: `mWakefulness=Awake`, or `Asleep`/`Dozing` in standby.
  static const wakefulnessCommand = 'dumpsys power | grep -m1 mWakefulness=';

  /// Null when the reply doesn't say.
  static bool? parseAwake(String out) {
    final m = RegExp(r'mWakefulness=(\w+)').firstMatch(out);
    return m == null ? null : m.group(1) == 'Awake';
  }

  /// Foreground app, volume and the screen in one round trip (the
  /// now-playing poll).
  static const statusCommand =
      '$foregroundCommand; echo ---; $volumeCommand; echo ---; $wakefulnessCommand';

  Future<({String? foreground, VolumeState? volume, bool? awake})>
      status() async {
    final parts = _sections((await _sh(statusCommand)).stdout);
    return (
      foreground: _seeForeground(parseTopResumed(_at(parts, 0))),
      volume: _seeVolume(parseVolume(_at(parts, 1))),
      awake: parseAwake(_at(parts, 2)),
    );
  }

  static const launcherCommand = 'cmd package resolve-activity --brief '
      '-a android.intent.action.MAIN -c android.intent.category.HOME; '
      'echo ---; settings get secure enabled_accessibility_services; '
      'echo ---; settings get secure accessibility_enabled';

  Future<LauncherHealth> launcherHealth() async =>
      parseLauncherHealth((await _sh(launcherCommand)).stdout, profile);

  Future<CleanupStatus> cleanupStatus({Set<String> extras = const {}}) async {
    final targets = _cleanupTargets(extras);
    final snap = await packages();
    final present = <String>[];
    final disabled = <String>[];
    final pending = <String>[];
    final absent = <String>[];
    for (final p in targets) {
      switch (snap.state(p)) {
        case AppState.absent:
          absent.add(p);
        case AppState.notInstalled:
        case AppState.disabled:
          present.add(p);
          disabled.add(p);
        case AppState.enabled:
          present.add(p);
          pending.add(p);
      }
    }
    return CleanupStatus(
      present: present,
      disabled: disabled,
      pending: pending,
      absent: absent,
    );
  }

  Future<SpeechDecision> speechDecision() async {
    final good = profile.knownGood[kTtsPackage];
    if (good == null) {
      return const SpeechDecision(
        needed: false,
        reason: 'No known-good speech version for this TV',
      );
    }
    final v = await packageVersion(kTtsPackage);
    return decideSpeechRollback(v, good);
  }

  // ── writes ──

  /// Lets key events land before the verify read in the same shell.
  static const settle = 'sleep 0.15';

  /// One round trip: [foregroundCommand] (with [home]) --- pid before ---
  /// force-stop (+ Home) markers --- pid after.
  static String stopCommand(String pkg, {bool home = false}) =>
      '${home ? foregroundCommand : 'true'}; echo ---; pidof $pkg; '
      'echo ---; am force-stop $pkg && echo stopped; '
      '${home ? 'input keyevent KEYCODE_HOME && echo home; ' : ''}'
      'echo ---; pidof $pkg';

  /// `am force-stop`. Verified by the process being gone or restarted.
  Future<JournalEntry> stopApp(String pkg) async =>
      (await _stop(pkg, home: false)).entry;

  Future<({JournalEntry entry, String? foreground, bool home})> _stop(
    String pkg, {
    required bool home,
  }) async {
    checkPackage(pkg);
    if (isStopProtected(pkg)) throw NeverTouchException(pkg);
    final r = await _sh(stopCommand(pkg, home: home), urgent: true);
    final parts = _sections(r.stdout);
    final before = _at(parts, 1).trim();
    final marks = _at(parts, 2);
    final after = _at(parts, 3).trim();
    final entry = await _record(
      op: 'stopApp',
      target: pkg,
      before: before.isEmpty ? 'not running' : 'pid $before',
      after: after.isEmpty ? 'not running' : 'pid $after',
      ok: marks.contains('stopped') && (after.isEmpty || after != before),
    );
    if (home) _seeForeground(null);
    return (
      entry: entry,
      foreground: home ? parseTopResumed(_at(parts, 0)) : null,
      home: marks.contains('home'),
    );
  }

  bool _isHome(String pkg) =>
      pkg == profile.launcher?.pkg ||
      pkg == 'com.google.android.apps.tv.launcherx';

  /// Stops whatever is on screen, then goes Home, in one round trip when
  /// the poll already knows the foreground app. A stop-protected
  /// foreground app (Home, system UI...) is not force-stopped; it only gets
  /// the Home key.
  Future<StopOutcome> stopForegroundApp() async {
    var fg = cachedForeground;
    if (fg == null || _isHome(fg)) fg = await foregroundPackage(urgent: true);
    if (fg == null) {
      return const StopOutcome(detail: 'No foreground app found');
    }
    if (_isHome(fg)) {
      return StopOutcome(pkg: fg, detail: 'Already on the home screen');
    }
    if (isStopProtected(fg) || !_pkgPattern.hasMatch(fg)) {
      final home = await _sh('input keyevent KEYCODE_HOME', urgent: true);
      _seeForeground(null);
      return StopOutcome(
        pkg: fg,
        sentHome: home.ok,
        detail: '$fg is protected; sent Home instead of force-stop',
      );
    }
    final s = await _stop(fg, home: true);
    var entry = s.entry;
    var pkg = fg;
    // The cached foreground was stale: the app really on screen was
    // something else. Stop that one too (Home was already sent).
    final real = s.foreground;
    if (real != null &&
        real != fg &&
        !_isHome(real) &&
        !isStopProtected(real) &&
        _pkgPattern.hasMatch(real)) {
      entry = await stopApp(real);
      pkg = real;
    }
    return StopOutcome(
      pkg: pkg,
      forceStopped: entry.ok,
      sentHome: s.home,
      entry: entry,
    );
  }

  /// `pm enable` / `pm disable-user --user 0`.
  Future<JournalEntry> setAppEnabled(String pkg, bool on) async {
    _requireMaintenance();
    _guard(pkg);
    final before = await appState(pkg);
    final r = await _sh(_enableCmd(pkg, on));
    _notePackageWrite();
    final after = await appState(pkg);
    return _record(
      op: on ? 'enableApp' : 'disableApp',
      target: pkg,
      before: before.name,
      after: after.name,
      undo: _enableCmd(pkg, !on),
      ok: r.ok && after == (on ? AppState.enabled : AppState.disabled),
    );
  }

  static String _enableCmd(String pkg, bool on) =>
      on ? 'pm enable $pkg' : 'pm disable-user --user 0 $pkg';

  /// State of the stock YouTube app, or null if the profile has none.
  Future<AppState?> stockYouTubeState() async {
    final spec = profile.stockYouTube;
    if (spec == null) return null;
    return appState(spec.pkg);
  }

  /// Installs (install-existing) or removes for user 0 (`uninstall -k`)
  /// the stock YouTube app, and enables/disables its companions.
  Future<List<JournalEntry>> stockYouTube(bool on) async {
    _requireMaintenance();
    final spec = profile.stockYouTube;
    if (spec == null) throw StateError('Profile has no stock YouTube');
    final pkg = _guard(spec.pkg);
    spec.companions.forEach(_guard);
    final out = <JournalEntry>[];
    final before = await packages();
    final installCmd = 'cmd package install-existing $pkg';
    final removeCmd = 'pm uninstall -k --user 0 $pkg';
    final r = await _sh(on ? installCmd : removeCmd);
    _notePackageWrite();
    final mid = await packages();
    final st = mid.state(pkg);
    out.add(
      await _record(
        op: on ? 'stockYouTubeOn' : 'stockYouTubeOff',
        target: pkg,
        before: before.state(pkg).name,
        after: st.name,
        undo: on ? removeCmd : installCmd,
        ok: r.ok &&
            (on
                ? st == AppState.enabled || st == AppState.disabled
                : st == AppState.notInstalled || st == AppState.absent),
      ),
    );
    for (final c in spec.companions) {
      final cs = mid.state(c);
      if (cs == AppState.absent || cs == AppState.notInstalled) continue;
      if ((cs == AppState.enabled) == on) continue;
      out.add(await setAppEnabled(c, on));
    }
    return out;
  }

  /// Rolls back speech services updates when they are newer than the
  /// profile's known-good build. Returns null when not needed. The package
  /// is protected from disabling; this rollback is the only allowed write.
  Future<JournalEntry?> speechRollback() async {
    _requireMaintenance();
    final d = await speechDecision();
    if (!d.needed) return null;
    const cmd = 'pm uninstall-system-updates $kTtsPackage';
    final r = await _sh(cmd);
    _notePackageWrite();
    final after = await packageVersion(kTtsPackage);
    return _record(
      op: 'speechRollback',
      target: kTtsPackage,
      before: d.currentVersion ?? '?',
      after: after?.versionName ?? '?',
      ok: r.ok && after != null && !after.updatedSystemApp,
    );
  }

  List<String> _cleanupTargets(Set<String> extras) {
    final known = {for (final e in profile.extras) e.pkg};
    for (final x in extras) {
      if (!known.contains(x)) {
        throw ArgumentError.value(x, 'extras', 'not in profile extras');
      }
    }
    return [
      for (final c in profile.cleanup) c.pkg,
      for (final e in profile.extras)
        if (extras.contains(e.pkg)) e.pkg,
    ];
  }

  /// Disables every cleanup package (plus opted-in [extras]) that is
  /// currently enabled. Refuses up front if any target is protected.
  Future<List<JournalEntry>> applyCleanup({
    Set<String> extras = const {},
  }) =>
      _bulkEnable(extras, false);

  /// Re-enables every disabled cleanup package (plus [extras]).
  Future<List<JournalEntry>> undoCleanup({
    Set<String> extras = const {},
  }) =>
      _bulkEnable(extras, true);

  Future<List<JournalEntry>> _bulkEnable(Set<String> extras, bool on) async {
    _requireMaintenance();
    final targets = _cleanupTargets(extras)..forEach(_guard);
    final before = await packages();
    final from = on ? AppState.disabled : AppState.enabled;
    final todo = [
      for (final p in targets)
        if (before.state(p) == from) p,
    ];
    if (todo.isEmpty) return const [];
    final results = <String, AdbShellResult>{};
    for (final p in todo) {
      results[p] = await _sh(_enableCmd(p, on));
      _notePackageWrite();
    }
    final after = await packages();
    final want = on ? AppState.enabled : AppState.disabled;
    final out = <JournalEntry>[];
    for (final p in todo) {
      out.add(
        await _record(
          op: on ? 'undoCleanup' : 'applyCleanup',
          target: p,
          before: from.name,
          after: after.state(p).name,
          undo: _enableCmd(p, !on),
          ok: results[p]!.ok && after.state(p) == want,
        ),
      );
    }
    return out;
  }

  /// Ensures the launcher's Home-key helper is in
  /// `enabled_accessibility_services` (keeping existing entries) and that
  /// accessibility is on.
  Future<JournalEntry> fixLauncher() async {
    _requireMaintenance();
    final spec = profile.launcher;
    if (spec == null) throw StateError('Profile has no launcher');
    final h = await launcherHealth();
    final beforeDesc = _launcherDesc(h);
    if (h.helperEnabled && h.a11yEnabled) {
      return _record(
        op: 'fixLauncher',
        target: spec.a11yService,
        before: beforeDesc,
        after: beforeDesc,
        ok: true,
      );
    }
    final list = [
      ...h.a11yServices,
      if (!h.helperEnabled) spec.a11yService,
    ];
    for (final c in list) {
      if (!_componentPattern.hasMatch(c)) {
        throw InvalidPackageException(c);
      }
    }
    final value = list.join(':');
    final undo = h.rawServices.isEmpty
        ? 'settings delete secure enabled_accessibility_services'
        : "settings put secure enabled_accessibility_services "
            "'${h.rawServices}'";
    final r = await _sh(
      "settings put secure enabled_accessibility_services '$value' && "
      'settings put secure accessibility_enabled 1',
    );
    final after = await launcherHealth();
    return _record(
      op: 'fixLauncher',
      target: spec.a11yService,
      before: beforeDesc,
      after: _launcherDesc(after),
      undo: undo,
      ok: r.ok && after.helperEnabled && after.a11yEnabled,
    );
  }

  static String _launcherDesc(LauncherHealth h) =>
      'home=${h.homeComponent} helper=${h.helperEnabled} '
      'a11y=${h.a11yEnabled}';

  /// One round trip: volume --- key presses (+ settle) --- volume.
  static String keysThenVolumeCommand(List<String> keys) =>
      '$volumeCommand; echo ---; '
      'input keyevent ${keys.join(' ')} && $settle && echo sent; '
      'echo ---; $volumeCommand';

  /// One round trip that presses mute only if the TV is in the other
  /// state: volume --- `sent` marker --- volume. Never toggles blind: an
  /// unreadable state sends nothing.
  static String setMutedCommand(bool muted) =>
      'v=\$($volumeCommand); echo "\$v"; echo ---; '
      'echo "\$v" | grep -q \'Muted: ${!muted}\' && '
      'input keyevent KEYCODE_VOLUME_MUTE && $settle && echo sent; '
      'echo ---; $volumeCommand';

  /// Slow-path re-read when a key press hadn't reached dumpsys yet.
  static const lateVolumeCommand = 'sleep 0.3; $volumeCommand';

  Future<({VolumeState? before, bool sent, VolumeState? after})> _keys(
    String cmd,
    bool Function(VolumeState? before, VolumeState after) done,
  ) async {
    final parts = _sections((await _sh(cmd, urgent: true)).stdout);
    final before = parseVolume(_at(parts, 0));
    final sent = _at(parts, 1).contains('sent');
    var after = parseVolume(_at(parts, 2));
    if (sent && after != null && !done(before, after)) {
      after = parseVolume(
            (await _sh(lateVolumeCommand, urgent: true)).stdout,
          ) ??
          after;
    }
    _seeVolume(after ?? before);
    return (before: before, sent: sent, after: after);
  }

  static bool _moved(bool up, VolumeState? before, VolumeState after) =>
      before == null ||
      (up
          ? after.level > before.level || after.level >= after.max
          : after.level < before.level || after.level <= after.min);

  /// Presses volume up/down [n] times (capped at 100) and reads the result,
  /// in one round trip. Absolute volume set is ignored on the VU3 (quirk
  /// absoluteVolumeIgnored), so steps it is.
  Future<JournalEntry> volumeStep({required bool up, int n = 1}) async {
    final count = n.clamp(1, 100);
    final key = up ? 'KEYCODE_VOLUME_UP' : 'KEYCODE_VOLUME_DOWN';
    final undoKey = up ? 'KEYCODE_VOLUME_DOWN' : 'KEYCODE_VOLUME_UP';
    final r = await _keys(
      keysThenVolumeCommand(List.filled(count, key)),
      (b, a) => _moved(up, b, a),
    );
    final after = r.after;
    return _record(
      op: up ? 'volumeUp' : 'volumeDown',
      target: 'x$count',
      before: '${r.before}',
      after: '$after',
      undo: 'input keyevent ${List.filled(count, undoKey).join(' ')}',
      ok: r.sent && (after == null || _moved(up, r.before, after)),
    );
  }

  /// Steps to [percent] (0–100). Plans from the polled volume when recent
  /// (one round trip), else reads first. If the plan was stale, one more
  /// step fixes it. Returns null when already there.
  Future<JournalEntry?> setVolumePercent(int percent) async {
    final start = cachedVolume ?? await readVolume(urgent: true);
    if (start == null) throw StateError('Could not read volume');
    int goalOf(VolumeState v) =>
        v.min + ((v.max - v.min) * percent.clamp(0, 100) / 100).round();
    var diff = goalOf(start) - start.level;
    if (diff == 0) return null;
    JournalEntry? e;
    for (var i = 0; i < 2 && diff != 0; i++) {
      e = await volumeStep(up: diff > 0, n: diff.abs());
      final now = _volume;
      if (now == null) break;
      diff = goalOf(now) - now.level;
    }
    return e;
  }

  /// Toggles mute with KEYCODE_VOLUME_MUTE, verified in the same round
  /// trip.
  Future<JournalEntry> toggleMute() async {
    final r = await _keys(
      keysThenVolumeCommand(const ['KEYCODE_VOLUME_MUTE']),
      (b, a) => b == null || a.muted != b.muted,
    );
    final before = r.before;
    final after = r.after;
    return _record(
      op: 'toggleMute',
      target: 'mute',
      before: '$before',
      after: '$after',
      undo: 'input keyevent KEYCODE_VOLUME_MUTE',
      ok: r.sent &&
          (before == null || after == null || after.muted != before.muted),
    );
  }

  /// Mutes or unmutes. The TV only honours the mute *toggle* key, so the
  /// state must be known first. Fast path: a fresh polled state says the
  /// TV is in the other state, so the key goes out alone (~0.1 s) and a
  /// background read corrects it if the TV ended up wrong (e.g. the remote
  /// toggled it meanwhile). Otherwise: read, press if needed and verify in
  /// one round trip. Returns null when already in that state.
  Future<JournalEntry?> setMuted(bool muted) async {
    final cached = cachedVolume;
    if (cached != null && cached.muted != muted) {
      final sent =
          await _sh('input keyevent KEYCODE_VOLUME_MUTE', urgent: true);
      if (sent.ok) {
        final predicted = VolumeState(
          level: cached.level,
          min: cached.min,
          max: cached.max,
          muted: muted,
        );
        _seeVolume(predicted);
        unawaited(_confirmMuted(muted));
        return _record(
          op: muted ? 'mute' : 'unmute',
          target: 'sound',
          before: '$cached',
          after: '$predicted',
          undo: 'input keyevent KEYCODE_VOLUME_MUTE',
          ok: true,
        );
      }
    }
    final r = await _keys(setMutedCommand(muted), (_, a) => a.muted == muted);
    final before = r.before;
    if (before == null) throw StateError('Could not read mute state');
    if (!r.sent && before.muted == muted) return null;
    return _record(
      op: muted ? 'mute' : 'unmute',
      target: 'sound',
      before: '${r.before}',
      after: '${r.after}',
      undo: 'input keyevent KEYCODE_VOLUME_MUTE',
      ok: r.after?.muted == muted,
    );
  }

  /// Background check after a fast-path mute: if the TV disagrees, fix it
  /// with the careful read-press-verify command.
  Future<void> _confirmMuted(bool muted) async {
    try {
      await Future<void>.delayed(confirmDelay);
      final v = _seeVolume(parseVolume((await _sh(volumeCommand)).stdout));
      if (v == null || v.muted == muted) return;
      final r = await _keys(setMutedCommand(muted), (_, a) => a.muted == muted);
      await _record(
        op: muted ? 'mute' : 'unmute',
        target: 'sound (corrected)',
        before: '${r.before}',
        after: '${r.after}',
        undo: 'input keyevent KEYCODE_VOLUME_MUTE',
        ok: r.after?.muted == muted,
      );
    } catch (_) {
      // The next poll reconciles the UI either way.
    }
  }

  /// How long a fast-path mute waits before its background check.
  @visibleForTesting
  static Duration confirmDelay = const Duration(milliseconds: 250);

  // ── parsers (pure; exposed for tests) ──

  static Set<String> parsePackageList(String out) => {
        for (final l in out.split('\n'))
          if (l.trim().startsWith('package:'))
            l.trim().substring('package:'.length),
      };

  /// `pkg -> component` from `query-activities --brief`.
  static Map<String, String> parseLeanbackActivities(String out) {
    final m = <String, String>{};
    for (final raw in out.split('\n')) {
      final l = raw.trim();
      if (!_componentPattern.hasMatch(l)) continue;
      m.putIfAbsent(l.split('/').first, () => l);
    }
    return m;
  }

  @visibleForTesting
  static String? parseResolvedComponent(String out) {
    for (final raw in out.split('\n').reversed) {
      final l = raw.trim();
      if (_componentPattern.hasMatch(l)) return l;
    }
    return null;
  }

  /// Expands `pkg/.Cls` to `pkg/pkg.Cls` for comparisons.
  static String normalizeComponent(String c) {
    final i = c.indexOf('/');
    if (i < 0) return c;
    final pkg = c.substring(0, i);
    final cls = c.substring(i + 1);
    return cls.startsWith('.') ? '$pkg/$pkg$cls' : c;
  }

  static List<String> parseA11yList(String value) {
    final v = value.trim();
    if (v.isEmpty || v == 'null') return const [];
    return [
      for (final s in v.split(':'))
        if (s.trim().isNotEmpty) s.trim(),
    ];
  }

  static LauncherHealth parseLauncherHealth(
    String out,
    DeviceProfile profile,
  ) {
    final parts = out.split(RegExp(r'^---\s*$', multiLine: true));
    String at(int i) => i < parts.length ? parts[i].trim() : '';
    final home = parseResolvedComponent(at(0));
    final raw = at(1) == 'null' ? '' : at(1);
    final services = parseA11yList(raw);
    final spec = profile.launcher;
    final helper = spec != null &&
        services
            .map(normalizeComponent)
            .contains(normalizeComponent(spec.a11yService));
    return LauncherHealth(
      homeComponent: home,
      homeIsLauncher:
          spec != null && home != null && home.startsWith('${spec.pkg}/'),
      a11yServices: services,
      helperEnabled: helper,
      a11yEnabled: at(2) == '1',
      rawServices: raw,
    );
  }

  static PackageVersion? parsePackageVersion(String out) {
    final name = RegExp(r'versionName=(\S+)').firstMatch(out)?.group(1);
    if (name == null) return null;
    final flags = RegExp(r'pkgFlags=\[([^\]]*)\]').firstMatch(out)?.group(1);
    final user0 =
        RegExp(r'User 0:[^\n]*installed=(true|false)').firstMatch(out);
    return PackageVersion(
      versionName: name,
      updatedSystemApp: flags?.contains('UPDATED_SYSTEM_APP') ?? false,
      installedForUser0: user0 == null ? null : user0.group(1) == 'true',
    );
  }

  static SpeechDecision decideSpeechRollback(
    PackageVersion? v,
    String knownGood,
  ) {
    if (v == null) {
      return SpeechDecision(
        needed: false,
        reason: 'Speech services not found',
        knownGood: knownGood,
      );
    }
    if (v.versionName == knownGood) {
      return SpeechDecision(
        needed: false,
        reason: 'Speech services are the known-good build',
        currentVersion: v.versionName,
        knownGood: knownGood,
      );
    }
    if (!v.updatedSystemApp) {
      return SpeechDecision(
        needed: false,
        reason: 'Factory build differs from known-good; nothing to roll '
            'back',
        currentVersion: v.versionName,
        knownGood: knownGood,
      );
    }
    return SpeechDecision(
      needed: true,
      reason: 'Updated speech services ${v.versionName} replace the '
          'known-good build',
      currentVersion: v.versionName,
      knownGood: knownGood,
    );
  }

  static VolumeState? parseVolume(String out) {
    final i = out.indexOf('- STREAM_MUSIC:');
    if (i < 0) return null;
    final block = out.substring(i).split(RegExp(r'\n\s*\n')).first;
    int? num(String label) => int.tryParse(
          RegExp('$label\\s*(-?\\d+)').firstMatch(block)?.group(1) ?? '',
        );
    final level = num('streamVolume:');
    if (level == null) return null;
    final muted = RegExp(r'^\s*Muted:\s*(true|false)', multiLine: true)
        .firstMatch(block)
        ?.group(1);
    return VolumeState(
      level: level,
      min: num('Min:') ?? 0,
      max: num('Max:') ?? 100,
      muted: muted == 'true',
    );
  }

  static String? parseTopResumed(String out) =>
      RegExp(r'u\d+ ([a-zA-Z0-9_.]+)/').firstMatch(out)?.group(1);
}
