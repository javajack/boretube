import 'package:boretube_mobile/adb/adb_connection.dart';
import 'package:boretube_mobile/ops/tv_ops.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tv.dart';

/// Replies with fixed text and records which lane each command used.
class _Canned implements PriorityAdbShell {
  final String out;
  final lanes = <String>[];
  _Canned(this.out);

  @override
  Future<AdbShellResult> shell(String command) async {
    lanes.add('bg');
    return AdbShellResult(out, 0);
  }

  @override
  Future<AdbShellResult> shellUrgent(String command) async {
    lanes.add('urgent');
    return AdbShellResult(out, 0);
  }
}

const _music = '- STREAM_MUSIC:\n   Muted: false\n   Muted Internally: false\n'
    '   Min: 0\n   Max: 100\n   streamVolume:13\n';
const _musicMuted =
    '- STREAM_MUSIC:\n   Muted: true\n   Muted Internally: false\n'
    '   Min: 0\n   Max: 100\n   streamVolume:13\n';

void main() {
  final vu3 = loadProfile('sony-bravia-vu3');
  late FakeTv tv;
  late TvOps ops;

  setUp(() {
    tv = FakeTv();
    ops = TvOps(adb: tv, profile: vu3, tvId: 't');
  });

  group('command text', () {
    test('setMuted presses mute only from the other state, then verifies', () {
      expect(
        TvOps.setMutedCommand(true),
        "v=\$(dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'); echo \"\$v\"; "
        "echo ---; echo \"\$v\" | grep -q 'Muted: false' && "
        'input keyevent KEYCODE_VOLUME_MUTE && sleep 0.15 && echo sent; '
        "echo ---; dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'",
      );
      expect(TvOps.setMutedCommand(false), contains("grep -q 'Muted: true'"));
    });

    test('stop with Home: fg, pid, force-stop + Home, pid', () {
      expect(
        TvOps.stopCommand('com.netflix.ninja', home: true),
        'dumpsys activity activities | grep -m1 topResumedActivity; '
        'echo ---; pidof com.netflix.ninja; echo ---; '
        'am force-stop com.netflix.ninja && echo stopped; '
        'input keyevent KEYCODE_HOME && echo home; '
        'echo ---; pidof com.netflix.ninja',
      );
      expect(
        TvOps.stopCommand('com.netflix.ninja'),
        isNot(contains('KEYCODE_HOME')),
      );
    });

    test('volume keys go in one input keyevent with a settle', () {
      expect(
        TvOps.keysThenVolumeCommand(
          const ['KEYCODE_VOLUME_UP', 'KEYCODE_VOLUME_UP'],
        ),
        "dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'; echo ---; "
        'input keyevent KEYCODE_VOLUME_UP KEYCODE_VOLUME_UP && sleep 0.15 '
        "&& echo sent; echo ---; dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'",
      );
    });
  });

  group('parsing combined output', () {
    test('setMuted reads before/after from one reply, on the urgent lane',
        () async {
      final sh = _Canned('$_music---\nsent\n---\n$_musicMuted');
      final o = TvOps(adb: sh, profile: vu3, tvId: 't');
      final e = await o.setMuted(true);
      expect(e!.ok, isTrue);
      expect(e.op, 'mute');
      expect(e.before, '13/100');
      expect(e.after, '13/100 muted');
      expect(sh.lanes, ['urgent']);
    });

    test('setMuted with an unreadable TV throws and sends nothing', () async {
      final sh = _Canned('---\n---\n');
      final o = TvOps(adb: sh, profile: vu3, tvId: 't');
      await expectLater(o.setMuted(true), throwsStateError);
      expect(sh.lanes, hasLength(1));
    });

    test('stop reply (as the TV prints it) parses pids and markers', () async {
      final sh = _Canned(
        '    topResumedActivity=ActivityRecord{ee39a60 u0 '
        'org.smarttube.stable/com.x.PlaybackActivity t3699}\n'
        'Failed to write while dumping service activity: Broken pipe\n'
        '---\n2496\n---\nstopped\nhome\n---\n',
      );
      final o = TvOps(adb: sh, profile: vu3, tvId: 't');
      await o.status(); // primes the cache with the canned foreground
      sh.lanes.clear();
      final s = await o.stopForegroundApp();
      expect(s.pkg, 'org.smarttube.stable');
      expect(s.forceStopped, isTrue);
      expect(s.sentHome, isTrue);
      expect(s.entry!.before, 'pid 2496');
      expect(s.entry!.after, 'not running');
      expect(sh.lanes, ['urgent']);
    });

    test('status parses foreground and volume from one reply', () async {
      final st = await ops.status();
      expect(st.foreground, 'org.smarttube.stable');
      expect(st.volume!.level, 12);
      expect(tv.log, [TvOps.statusCommand]);
    });
  });

  group('one round trip per action', () {
    test('mute: 1 round trip; again: 1 round trip, no key', () async {
      expect((await ops.setMuted(true))!.ok, isTrue);
      expect(tv.log, hasLength(1));
      expect(tv.muted, isTrue);
      expect(await ops.setMuted(true), isNull);
      expect(tv.log, hasLength(2));
      expect(tv.writes, ['input keyevent KEYCODE_VOLUME_MUTE']);
    });

    test('mute that lags dumpsys gets one re-read, then reports', () async {
      tv.muteReflected = false;
      final e = await ops.setMuted(true);
      expect(e!.ok, isFalse);
      expect(tv.log, [TvOps.setMutedCommand(true), TvOps.lateVolumeCommand]);
    });

    test('toggleMute: 1 round trip', () async {
      final e = await ops.toggleMute();
      expect(e.ok, isTrue);
      expect(e.before, '12/100');
      expect(e.after, '12/100 muted');
      expect(tv.log, hasLength(1));
    });

    test('stop after a poll: 1 round trip, guards still apply', () async {
      await ops.status();
      tv.log.clear();
      final s = await ops.stopForegroundApp();
      expect(s.forceStopped, isTrue);
      expect(tv.log, [TvOps.stopCommand('org.smarttube.stable', home: true)]);
      expect(tv.writes, [
        'am force-stop org.smarttube.stable',
        'input keyevent KEYCODE_HOME',
      ]);
      expect(tv.foreground, 'com.google.android.apps.tv.launcherx');
    });

    test('stop with a stale poll also stops the app really on screen',
        () async {
      await ops.status();
      tv.foreground = 'com.netflix.ninja';
      tv.running['com.netflix.ninja'] = 7;
      tv.log.clear();
      final s = await ops.stopForegroundApp();
      expect(s.pkg, 'com.netflix.ninja');
      expect(s.forceStopped, isTrue);
      expect(tv.writes, [
        'am force-stop org.smarttube.stable',
        'input keyevent KEYCODE_HOME',
        'am force-stop com.netflix.ninja',
      ]);
      expect(tv.log, hasLength(2));
    });

    test('stop of a stop-protected foreground: Home only', () async {
      tv.foreground = 'com.sony.dtv.smartui';
      await ops.status();
      tv.log.clear();
      final s = await ops.stopForegroundApp();
      expect(s.forceStopped, isFalse);
      expect(s.sentHome, isTrue);
      expect(tv.log, ['input keyevent KEYCODE_HOME']);
    });

    test('a polled Home screen is re-checked before Stop gives up', () async {
      tv.foreground = 'com.gathin.tvhome';
      await ops.status();
      tv.foreground = 'com.netflix.ninja';
      tv.log.clear();
      final s = await ops.stopForegroundApp();
      expect(s.pkg, 'com.netflix.ninja');
      expect(tv.log.first, TvOps.foregroundCommand);
      expect(tv.writes, contains('am force-stop com.netflix.ninja'));
    });

    test('volume to N after a poll: 1 round trip', () async {
      await ops.status();
      tv.log.clear();
      final e = await ops.setVolumePercent(20);
      expect(e!.ok, isTrue);
      expect(tv.volume, 20);
      expect(tv.log, hasLength(1));
      expect(e.before, '12/100');
      expect(e.after, '20/100');
    });

    test('volume with a stale poll corrects in one more step', () async {
      await ops.status(); // sees 12
      tv.volume = 15; // the remote moved it since
      tv.log.clear();
      await ops.setVolumePercent(20);
      expect(tv.volume, 20);
      expect(tv.log, hasLength(2));
    });

    test('volume with no poll reads first: 2 round trips', () async {
      await ops.setVolumePercent(10);
      expect(tv.volume, 10);
      expect(tv.log, [TvOps.volumeCommand, isNot(TvOps.volumeCommand)]);
    });

    test('volume already there: nothing sent', () async {
      await ops.status();
      tv.log.clear();
      expect(await ops.setVolumePercent(12), isNull);
      expect(tv.log, isEmpty);
    });
  });
}
