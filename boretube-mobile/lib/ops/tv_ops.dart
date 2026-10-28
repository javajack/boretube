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

  Future<AdbShellResult> _sh(String cmd) => adb.shell(cmd);

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

  Future<VolumeState?> readVolume() async =>
      parseVolume((await _sh(volumeCommand)).stdout);

  static const foregroundCommand =
      'dumpsys activity activities | grep -m1 topResumedActivity';

  Future<String?> foregroundPackage() async =>
      parseTopResumed((await _sh(foregroundCommand)).stdout);

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

  /// `am force-stop`. Verified by the process being gone or restarted.
  Future<JournalEntry> stopApp(String pkg) async {
    checkPackage(pkg);
    if (isStopProtected(pkg)) throw NeverTouchException(pkg);
    final before = (await _sh('pidof $pkg')).stdout.trim();
    final r = await _sh('am force-stop $pkg');
    final after = (await _sh('pidof $pkg')).stdout.trim();
    return _record(
      op: 'stopApp',
      target: pkg,
      before: before.isEmpty ? 'not running' : 'pid $before',
      after: after.isEmpty ? 'not running' : 'pid $after',
      ok: r.ok && (after.isEmpty || after != before),
    );
  }

  /// Stops whatever is on screen, then goes Home. A stop-protected
  /// foreground app (Home, system UI...) is not force-stopped; it only gets
  /// the Home key.
  Future<StopOutcome> stopForegroundApp() async {
    final fg = await foregroundPackage();
    if (fg == null) {
      return const StopOutcome(detail: 'No foreground app found');
    }
    final launcherPkg = profile.launcher?.pkg;
    final isHome =
        fg == launcherPkg || fg == 'com.google.android.apps.tv.launcherx';
    if (isHome) {
      return StopOutcome(pkg: fg, detail: 'Already on the home screen');
    }
    JournalEntry? entry;
    var detail = '';
    if (isStopProtected(fg) || !_pkgPattern.hasMatch(fg)) {
      detail = '$fg is protected; sent Home instead of force-stop';
    } else {
      entry = await stopApp(fg);
    }
    final home = await _sh('input keyevent KEYCODE_HOME');
    return StopOutcome(
      pkg: fg,
      forceStopped: entry?.ok ?? false,
      sentHome: home.ok,
      entry: entry,
      detail: detail,
    );
  }

  /// `pm enable` / `pm disable-user --user 0`.
  Future<JournalEntry> setAppEnabled(String pkg, bool on) async {
    _requireMaintenance();
    _guard(pkg);
    final before = await appState(pkg);
    final r = await _sh(_enableCmd(pkg, on));
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

  /// Presses volume up/down [n] times (capped at 100). Absolute volume set
  /// is ignored on the VU3 (quirk absoluteVolumeIgnored), so steps it is.
  Future<JournalEntry> volumeStep({required bool up, int n = 1}) async {
    final count = n.clamp(1, 100);
    final key = up ? 'KEYCODE_VOLUME_UP' : 'KEYCODE_VOLUME_DOWN';
    final undoKey = up ? 'KEYCODE_VOLUME_DOWN' : 'KEYCODE_VOLUME_UP';
    final before = await readVolume();
    final r = await _sh(
      'input keyevent ${List.filled(count, key).join(' ')}',
    );
    final after = await readVolume();
    final moved = before == null ||
        after == null ||
        (up
            ? after.level > before.level || after.level >= after.max
            : after.level < before.level || after.level <= after.min);
    return _record(
      op: up ? 'volumeUp' : 'volumeDown',
      target: 'x$count',
      before: '$before',
      after: '$after',
      undo: 'input keyevent ${List.filled(count, undoKey).join(' ')}',
      ok: r.ok && moved,
    );
  }

  /// Toggles mute with KEYCODE_VOLUME_MUTE.
  Future<JournalEntry> toggleMute() async {
    final before = await readVolume();
    final r = await _sh('input keyevent KEYCODE_VOLUME_MUTE');
    final after = await readVolume();
    return _record(
      op: 'toggleMute',
      target: 'mute',
      before: '$before',
      after: '$after',
      undo: 'input keyevent KEYCODE_VOLUME_MUTE',
      ok: r.ok &&
          (before == null || after == null || after.muted != before.muted),
    );
  }

  /// Mutes or unmutes; returns null when already in that state.
  Future<JournalEntry?> setMuted(bool muted) async {
    final v = await readVolume();
    if (v != null && v.muted == muted) return null;
    return toggleMute();
  }

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
