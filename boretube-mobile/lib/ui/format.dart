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

String journalTitle(JournalEntry e) {
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
    _ => '${e.op} $target'.trim(),
  } +
      (e.ok ? '' : ' (failed)');
}

IconData journalIcon(String op) => switch (op) {
      'stopApp' => Icons.stop_circle_outlined,
      'enableApp' => Icons.toggle_on_outlined,
      'disableApp' => Icons.toggle_off_outlined,
      'speechRollback' => Icons.record_voice_over_outlined,
      'fixLauncher' => Icons.home_outlined,
      'volumeUp' || 'volumeDown' => Icons.volume_up_outlined,
      'applyCleanup' => Icons.cleaning_services_outlined,
      'undoCleanup' => Icons.undo_rounded,
      'stockYouTubeOn' || 'stockYouTubeOff' => Icons.smart_display_outlined,
      'toggleMute' => Icons.volume_off_outlined,
      _ => Icons.build_outlined,
    };

/// "AB:CD:…" — the MD5 fingerprint the TV shows in "Allow USB debugging?".
String adbFingerprint(AdbKey key) {
  final d = md5.convert(key.androidPublicKeyStruct()).bytes;
  return d
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
