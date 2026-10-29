import 'dart:convert';

import 'package:flutter/services.dart';

import '../adb/adb_connection.dart';
import '../agent/agent_installer.dart' show apkPushCommands, compareVersions;
import '../ops/journal.dart';

/// The boretube Learn TV app ("Tubby's Town").
const kLearnPackage = 'com.rakesh.boretube.learn';

/// `assets/learn/manifest.json`, written when the Learn app is bundled.
class LearnManifest {
  final String versionName;
  final int versionCode;
  final String sha256;
  final String apk;

  const LearnManifest({
    required this.versionName,
    this.versionCode = 0,
    required this.sha256,
    this.apk = 'boretube-learn.apk',
  });

  factory LearnManifest.fromJson(Map<String, dynamic> j) => LearnManifest(
        versionName: (j['versionName'] as String?) ?? '?',
        versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
        sha256: ((j['sha256'] as String?) ?? '').toLowerCase(),
        apk: (j['apk'] as String?) ?? 'boretube-learn.apk',
      );
}

class LearnBundle {
  static const dir = 'assets/learn';

  final LearnManifest manifest;
  final Uint8List apk;

  const LearnBundle(this.manifest, this.apk);

  /// Throws when the build has no `assets/learn/`.
  static Future<LearnBundle> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final m = LearnManifest.fromJson(
      jsonDecode(await b.loadString('$dir/manifest.json'))
          as Map<String, dynamic>,
    );
    final data = await b.load('$dir/${m.apk}');
    return LearnBundle(m, data.buffer.asUint8List());
  }
}

enum LearnInstallState { missing, current, updateAvailable }

class LearnDiagnosis {
  final LearnInstallState state;

  /// The version on the TV, if any.
  final String? installed;
  final String bundled;

  const LearnDiagnosis(this.state, this.installed, this.bundled);
}

class LearnInstallResult {
  final bool ok;

  /// Plain words for the parent.
  final String message;

  const LearnInstallResult(this.ok, this.message);
}

/// Installs, updates and opens Tubby's Town on the TV over ADB. Every
/// command touches only the Learn package; each install is journaled.
class LearnInstaller {
  static const tmpApk = '/data/local/tmp/bt-learn.apk';
  static const versionCommand =
      'dumpsys package $kLearnPackage | grep -m1 versionName';

  final AdbShell adb;
  final String tvId;
  final Future<LearnBundle> Function() loadBundle;
  final Journal? journal;
  final DateTime Function() _clock;

  LearnInstaller({
    required this.adb,
    required this.tvId,
    required this.loadBundle,
    this.journal,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<String?> _installedVersion() async {
    final r = await adb.shell(versionCommand);
    final m = RegExp(r'versionName=(\S+)').firstMatch(r.stdout);
    return m?.group(1);
  }

  Future<LearnDiagnosis> diagnose() async {
    final b = await loadBundle();
    final v = await _installedVersion();
    final bundled = b.manifest.versionName;
    if (v == null) {
      return LearnDiagnosis(LearnInstallState.missing, null, bundled);
    }
    final newer = compareVersions(v, bundled) < 0;
    return LearnDiagnosis(
      newer ? LearnInstallState.updateAvailable : LearnInstallState.current,
      v,
      bundled,
    );
  }

  /// Copies the bundled app to the TV, checks the copy, installs it and
  /// checks the version the TV now reports.
  Future<LearnInstallResult> install() async {
    final b = await loadBundle();
    final before = await _installedVersion();
    final r = await _install(b);
    await journal?.add(
      JournalEntry(
        tvId: tvId,
        time: _clock(),
        op: 'installLearn',
        target: kLearnPackage,
        before: before ?? 'not installed',
        after: r.ok ? b.manifest.versionName : r.message,
        ok: r.ok,
      ),
    );
    return r;
  }

  Future<LearnInstallResult> _install(LearnBundle b) async {
    for (final c in apkPushCommands(b.apk, tmpApk)) {
      final r = await adb.shell(c);
      if (!r.ok) {
        await adb.shell('rm -f $tmpApk');
        return const LearnInstallResult(false, 'Copying to the TV failed');
      }
    }
    final sum = await adb.shell('sha256sum $tmpApk');
    final got = sum.stdout.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (got != b.manifest.sha256) {
      await adb.shell('rm -f $tmpApk');
      return const LearnInstallResult(
        false,
        'The copy on the TV is damaged. Try again.',
      );
    }
    final pm = await adb.shell('pm install -r $tmpApk');
    await adb.shell('rm -f $tmpApk');
    final out = pm.stdout.trim();
    if (!out.contains('Success')) {
      if (out.contains('UPDATE_INCOMPATIBLE') || out.contains('SIGNATURES')) {
        return const LearnInstallResult(
          false,
          'A Tubby\'s Town signed with a different key is on the TV. '
          'Remove it first.',
        );
      }
      return LearnInstallResult(false, out.isEmpty ? 'Install failed' : out);
    }
    final now = await _installedVersion();
    if (now != b.manifest.versionName) {
      return LearnInstallResult(false, 'The TV reports version ${now ?? '?'}');
    }
    return LearnInstallResult(true, 'Tubby\'s Town ${now!} is on the TV');
  }

  /// Opens Tubby's Town on the TV.
  Future<bool> open() async {
    final r = await adb.shell(
      'monkey -p $kLearnPackage -c android.intent.category.LEANBACK_LAUNCHER 1',
    );
    return r.stdout.contains('Events injected');
  }
}
