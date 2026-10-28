import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../agent/agent_models.dart' show kAgentPackage;
import 'tv_ops.dart';

/// How a TV looked the first time this phone connected over ADB, before
/// boretube changed anything. Restore uses it to tell boretube's changes
/// apart from ones that were already there.
class Baseline {
  static const schema = 1;

  final String tvId;
  final DateTime capturedAt;
  final String buildFingerprint;
  final String profileId;

  /// `pm list packages -d`.
  final List<String> disabled;

  /// In `pm list packages -u` but not installed for user 0.
  final List<String> uninstalled;

  /// [AppState] name of the stock YouTube app, or null if the profile has
  /// none.
  final String? stockYouTube;
  final String? ttsVersion;
  final bool ttsUpdated;
  final List<String> a11yServices;
  final bool a11yEnabled;
  final String? home;
  final bool agentInstalled;

  const Baseline({
    required this.tvId,
    required this.capturedAt,
    required this.buildFingerprint,
    this.profileId = '',
    this.disabled = const [],
    this.uninstalled = const [],
    this.stockYouTube,
    this.ttsVersion,
    this.ttsUpdated = false,
    this.a11yServices = const [],
    this.a11yEnabled = false,
    this.home,
    this.agentInstalled = false,
  });

  bool wasDisabled(String pkg) => disabled.contains(pkg);
  bool wasUninstalled(String pkg) => uninstalled.contains(pkg);

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'tvId': tvId,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'buildFingerprint': buildFingerprint,
        'profileId': profileId,
        'disabled': disabled,
        'uninstalled': uninstalled,
        'stockYouTube': stockYouTube,
        'ttsVersion': ttsVersion,
        'ttsUpdated': ttsUpdated,
        'enabledAccessibilityServices': a11yServices,
        'accessibilityEnabled': a11yEnabled,
        'home': home,
        'agentInstalled': agentInstalled,
      };

  factory Baseline.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) =>
        [for (final s in (v as List?) ?? const []) '$s'];
    return Baseline(
      tvId: j['tvId'] as String,
      capturedAt: DateTime.parse(j['capturedAt'] as String).toLocal(),
      buildFingerprint: j['buildFingerprint'] as String? ?? '',
      profileId: j['profileId'] as String? ?? '',
      disabled: strings(j['disabled']),
      uninstalled: strings(j['uninstalled']),
      stockYouTube: j['stockYouTube'] as String?,
      ttsVersion: j['ttsVersion'] as String?,
      ttsUpdated: j['ttsUpdated'] as bool? ?? false,
      a11yServices: strings(j['enabledAccessibilityServices']),
      a11yEnabled: j['accessibilityEnabled'] as bool? ?? false,
      home: j['home'] as String?,
      agentInstalled: j['agentInstalled'] as bool? ?? false,
    );
  }

  /// Pretty JSON for export (share / copy).
  String export() => const JsonEncoder.withIndent('  ').convert(toJson());

  static const fingerprintCommand = 'getprop ro.build.fingerprint';

  /// Reads everything over ADB (read-only).
  static Future<Baseline> capture(
    TvOps ops, {
    DateTime Function() clock = DateTime.now,
  }) async {
    final fp = (await ops.adb.shell(fingerprintCommand)).stdout.trim();
    final snap = await ops.packages();
    final tts = await ops.packageVersion(kTtsPackage);
    final launcher = await ops.launcherHealth();
    final yt = ops.profile.stockYouTube;
    return Baseline(
      tvId: ops.tvId,
      capturedAt: clock(),
      buildFingerprint: fp,
      profileId: ops.profile.id,
      disabled: (snap.disabled.intersection(snap.installed).toList()..sort()),
      uninstalled: (snap.all.difference(snap.installed).toList()..sort()),
      stockYouTube: yt == null ? null : snap.state(yt.pkg).name,
      ttsVersion: tts?.versionName,
      ttsUpdated: tts?.updatedSystemApp ?? false,
      a11yServices: launcher.a11yServices,
      a11yEnabled: launcher.a11yEnabled,
      home: launcher.homeComponent,
      agentInstalled: snap.state(kAgentPackage) == AppState.enabled ||
          snap.state(kAgentPackage) == AppState.disabled,
    );
  }
}

/// Baselines per TV in SharedPreferences. The first one is kept forever.
class BaselineStore {
  final SharedPreferences prefs;
  const BaselineStore(this.prefs);

  static String keyFor(String tvId) => 'baseline.$tvId';

  Baseline? read(String tvId) {
    final raw = prefs.getString(keyFor(tvId));
    if (raw == null) return null;
    try {
      return Baseline.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Baseline b) =>
      prefs.setString(keyFor(b.tvId), jsonEncode(b.toJson()));

  /// Captures and stores a baseline unless one exists. Returns the stored
  /// one either way.
  Future<Baseline> captureIfMissing(
    TvOps ops, {
    DateTime Function() clock = DateTime.now,
  }) async {
    final have = read(ops.tvId);
    if (have != null) return have;
    final b = await Baseline.capture(ops, clock: clock);
    await write(b);
    return b;
  }
}
