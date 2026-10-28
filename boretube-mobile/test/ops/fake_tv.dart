import 'dart:io';

import 'package:boretube_mobile/adb/adb_connection.dart';
import 'package:boretube_mobile/ops/device_profile.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';

String fixture(String name) =>
    File('test/fixtures/vu3/$name').readAsStringSync();

DeviceProfile loadProfile(String id) => DeviceProfile.fromJsonString(
      File('assets/profiles/$id.json').readAsStringSync(),
    );

/// A simulated VU3 seeded from real (read-only) captures. It understands
/// the commands [TvOps] sends and mutates its state like the TV would.
class FakeTv implements AdbShell {
  /// Every round trip, as sent.
  final log = <String>[];

  /// Every simple command the "shell" ran, compound ones split up.
  final ran = <String>[];
  late Set<String> all;
  late Set<String> installed;
  late Set<String> disabled;
  String leanback = fixture('query_leanback.txt');
  String home = fixture('resolve_home.txt');
  String a11y = fixture('a11y_services.txt').trim();
  String a11yEnabled = fixture('a11y_enabled.txt').trim();
  String? foreground = 'org.smarttube.stable';
  final running = <String, int>{'org.smarttube.stable': 3479};
  final dumpsys = <String, String>{
    'com.google.android.tts': fixture('dumpsys_package_tts.txt'),
    'com.google.android.youtube.tv': fixture('dumpsys_package_youtube.txt'),
  };
  int volume = 12;
  bool muted = false;

  /// Commands (by prefix) that should exit non-zero without effect.
  final failing = <String>{};

  /// When false, the TV ignores mute key events (dumpsys stays the same).
  bool muteReflected = true;

  FakeTv() {
    all = TvOps.parsePackageList(fixture('pm_list_u.txt'));
    installed = TvOps.parsePackageList(fixture('pm_list.txt'));
    disabled = TvOps.parsePackageList(fixture('pm_list_d.txt'));
  }

  /// Writes sent (everything but known reads).
  List<String> get writes => [
        for (final c in ran)
          if (!_isRead(c)) c,
      ];

  static bool _isRead(String c) =>
      c == 'true' ||
      c.startsWith('echo ') ||
      c.startsWith('sleep ') ||
      c == PackageSnapshot.command ||
      c == TvOps.leanbackQuery ||
      c == TvOps.volumeCommand ||
      c == TvOps.foregroundCommand ||
      c == TvOps.launcherCommand ||
      c.startsWith('dumpsys package ') ||
      c.startsWith('pidof ') ||
      c == 'echo ok';

  String _list(Iterable<String> s) =>
      '${[for (final p in s) 'package:$p'].join('\n')}\n';

  AdbShellResult _ok([String out = '']) => AdbShellResult(out, 0);

  String _volumeDump() =>
      '- STREAM_MUSIC:\n   Muted: $muted\n   Muted Internally: false\n'
      '   Min: 0\n   Max: 100\n   streamVolume:$volume\n'
      '   Current: 2 (speaker): $volume\n';

  @override
  Future<AdbShellResult> shell(String c) async {
    log.add(c);
    return _exec(c);
  }

  /// A tiny `sh`: `;` lists and `&&` chains over the simple commands.
  AdbShellResult _exec(String c) {
    for (final m in [true, false]) {
      if (c == TvOps.setMutedCommand(m)) return _setMuted(m);
    }
    final whole = c == PackageSnapshot.command ||
        c == TvOps.launcherCommand ||
        c.startsWith('settings put ');
    if (whole) return _simple(c)!;
    if (c.contains('; ')) {
      final out = StringBuffer();
      var code = 0;
      for (final part in c.split('; ')) {
        final r = _exec(part.trim());
        out.write(r.stdout);
        code = r.exitCode;
      }
      return AdbShellResult('$out', code);
    }
    if (c.contains(' && ')) {
      final out = StringBuffer();
      var code = 0;
      for (final part in c.split(' && ')) {
        final r = _exec(part.trim());
        out.write(r.stdout);
        code = r.exitCode;
        if (code != 0) break;
      }
      return AdbShellResult('$out', code);
    }
    return _simple(c) ?? AdbShellResult('unknown command: $c', 127);
  }

  AdbShellResult _setMuted(bool m) {
    final out = StringBuffer('${_volumeDump()}---\n');
    if (muted != m) {
      const key = 'input keyevent KEYCODE_VOLUME_MUTE';
      if (_simple(key)!.ok) out.write('sent\n');
    }
    out.write('---\n${_volumeDump()}');
    return AdbShellResult('$out', 0);
  }

  AdbShellResult? _simple(String c) {
    final r = _run(c);
    if (r != null) ran.add(c);
    return r;
  }

  AdbShellResult? _run(String c) {
    if (failing.any(c.startsWith)) return const AdbShellResult('Error', 1);
    if (c == 'true' || c.startsWith('sleep ')) return _ok();
    if (c.startsWith('echo ')) return _ok('${c.substring(5)}\n');
    if (c == PackageSnapshot.command) {
      return _ok(
        '${_list(all)}---\n${_list(installed)}---\n'
        '${_list(disabled.intersection(installed))}',
      );
    }
    if (c == TvOps.leanbackQuery) return _ok(leanback);
    if (c == TvOps.volumeCommand) return _ok(_volumeDump());
    if (c == TvOps.foregroundCommand) {
      final f = foreground;
      return f == null
          ? const AdbShellResult('', 1)
          : _ok('    topResumedActivity=ActivityRecord{6253481 u0 '
              '$f/.Main t3685}\n');
    }
    if (c == TvOps.launcherCommand) {
      return _ok('$home---\n$a11y\n---\n$a11yEnabled\n');
    }
    final words = c.split(' ');
    final last = words.last;
    if (c.startsWith('dumpsys package ')) {
      return _ok(dumpsys[last] ?? 'Unable to find package: $last\n');
    }
    if (c.startsWith('pidof ')) {
      final pid = running[last];
      return pid == null ? const AdbShellResult('', 1) : _ok('$pid\n');
    }
    if (c.startsWith('am force-stop ')) {
      running.remove(last);
      if (foreground == last) foreground = null;
      return _ok();
    }
    if (c.startsWith('pm disable-user --user 0 ')) {
      if (!installed.contains(last)) {
        return const AdbShellResult('Unknown package', 1);
      }
      disabled.add(last);
      return _ok('Package $last new state: disabled-user\n');
    }
    if (c.startsWith('pm enable ')) {
      disabled.remove(last);
      return _ok('Package $last new state: enabled\n');
    }
    if (c.startsWith('cmd package install-existing ')) {
      if (!all.contains(last)) return const AdbShellResult('', 1);
      installed.add(last);
      return _ok('Package $last installed for user: 0\n');
    }
    if (c.startsWith('pm uninstall -k --user 0 ')) {
      installed.remove(last);
      return _ok('Success\n');
    }
    if (c.startsWith('pm uninstall-system-updates ')) {
      dumpsys[last] = fixture('dumpsys_package_tts.txt');
      return _ok('Success\n');
    }
    if (c.startsWith('input keyevent ')) {
      for (final k in words.skip(2)) {
        switch (k) {
          case 'KEYCODE_VOLUME_UP':
            if (volume < 100) volume++;
          case 'KEYCODE_VOLUME_DOWN':
            if (volume > 0) volume--;
          case 'KEYCODE_VOLUME_MUTE':
            if (muteReflected) muted = !muted;
          case 'KEYCODE_HOME':
            foreground = 'com.google.android.apps.tv.launcherx';
        }
      }
      return _ok();
    }
    final put = RegExp(
      r"^settings put secure enabled_accessibility_services '([^']*)' && "
      r'settings put secure accessibility_enabled 1$',
    ).firstMatch(c);
    if (put != null) {
      a11y = put.group(1)!;
      a11yEnabled = '1';
      return _ok();
    }
    return null;
  }

  /// A dumpsys for tts as if Play had installed a newer update.
  static String updatedTtsDump() => fixture('dumpsys_package_tts.txt')
      .replaceFirst(
        'versionName=googletts.google-speech-apk_20251028.02_p2.827711934',
        'versionName=googletts.google-speech-apk_20260901.01_p0.900000000',
      )
      .replaceFirst(
        'pkgFlags=[ SYSTEM HAS_CODE',
        'pkgFlags=[ SYSTEM HAS_CODE UPDATED_SYSTEM_APP',
      );
}
