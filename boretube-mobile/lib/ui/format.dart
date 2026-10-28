import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../adb/adb_key.dart';
import '../ops/journal.dart';
import '../providers/now_playing.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 24-hour clock, e.g. "19:45".
String clockTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// "just now", "5 min ago", "3 h ago", "2 days ago".
String relativeTime(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  final days = d.inDays;
  return days == 1 ? 'yesterday' : '$days days ago';
}

/// "42s", "5m", "5m 10s" — the classic lock countdown.
String formatRemaining(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}

/// "12:40", "0:05" — the break countdown (minutes:seconds, rounded up).
String countdown(Duration d) {
  final total = (d.inMilliseconds / 1000).ceil().clamp(0, 99 * 60 + 59);
  return '${total ~/ 60}:${_two(total % 60)}';
}

String journalTitle(JournalEntry e) {
  if (e.op == 'break') return 'Break: ${e.target}${e.ok ? '' : ' (failed)'}';
  final target = e.target.contains('.') ? appLabel(e.target) : e.target;
  return switch (e.op) {
        'stopApp' => 'Stopped $target',
        'enableApp' => 'Enabled $target',
        'disableApp' => 'Disabled $target',
        'stockYouTubeOn' => 'Stock YouTube restored ($target)',
        'stockYouTubeOff' => 'Stock YouTube removed ($target)',
        'applyCleanup' => 'Cleaned up $target',
        'undoCleanup' => 'Restored $target',
        'speechRollback' => 'Speech services rolled back',
        'fixLauncher' => 'Home launcher repaired',
        'volumeUp' || 'volumeDown' => 'Volume ${e.before} → ${e.after}',
        'toggleMute' => 'Mute toggled',
        'mute' => 'Muted',
        'unmute' => 'Unmuted',
        'restore' => 'Restore: $target',
        'agentInstall' => 'Always On set up',
        'agentRepair' => 'Always On repaired',
        'agentUninstall' => 'Always On removed',
        'agentUpdate' => 'Always On updated',
        'shorts' => e.before == 'detected'
            ? 'Shorts spotted in $target'
            : 'Shorts stopped in $target',
        'endAfter' => e.before == 'armed'
            ? 'Pause after this one: on'
            : 'Paused after ${e.before}',
        'cancelEndAfter' => 'Pause after this one: cancelled',
        'blockedApp' || 'closedApp' || 'closeApp' => 'Closed $target',
        'endBreak' => 'Break ended',
        'muteFor' => 'Quiet for $target',
        'volume' => 'Volume set to $target',
        'approveBuild' => 'TV update approved',
        'mode' => 'Always On: ${e.after}',
        'safeMode' => 'Always On went hands-off',
        'rules' => 'Routines saved ($target)',
        'clampVolume' => 'Volume capped',
        _ => '${e.op} $target'.trim(),
      } +
      (e.ok ? '' : ' (failed)');
}

IconData journalIcon(String op) => switch (op) {
      'stopApp' ||
      'closeApp' ||
      'blockedApp' ||
      'closedApp' =>
        Icons.cancel_outlined,
      'enableApp' => Icons.toggle_on_outlined,
      'disableApp' => Icons.toggle_off_outlined,
      'speechRollback' => Icons.record_voice_over_outlined,
      'fixLauncher' => Icons.home_outlined,
      'volumeUp' || 'volumeDown' => Icons.volume_up_outlined,
      'applyCleanup' => Icons.cleaning_services_outlined,
      'undoCleanup' => Icons.undo_rounded,
      'stockYouTubeOn' || 'stockYouTubeOff' => Icons.smart_display_outlined,
      'toggleMute' || 'mute' => Icons.volume_off_outlined,
      'unmute' => Icons.volume_up_outlined,
      'break' || 'endBreak' => Icons.pause_circle_outline_rounded,
      'muteFor' => Icons.volume_off_outlined,
      'restore' => Icons.settings_backup_restore_rounded,
      'agentInstall' ||
      'agentRepair' ||
      'agentUpdate' ||
      'agentUninstall' =>
        Icons.shield_outlined,
      'shorts' => Icons.swipe_vertical_rounded,
      'endAfter' || 'cancelEndAfter' => Icons.hourglass_bottom_rounded,
      _ => Icons.build_outlined,
    };

/// "AB:CD:…" — the MD5 fingerprint the TV shows in "Allow USB debugging?".
String adbFingerprint(AdbKey key) {
  final d = md5.convert(key.androidPublicKeyStruct()).bytes;
  return d
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
