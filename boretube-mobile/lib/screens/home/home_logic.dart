import 'package:flutter/material.dart';

import '../../adb/adb_session.dart';
import '../../agent/agent_models.dart';
import '../../ops/journal.dart';
import '../../providers/agent_providers.dart';
import '../../providers/now_playing.dart';
import '../../tv/tv.dart';
import '../../ui/components.dart';

/// How far protection reaches, in parent words.
enum Protection {
  /// Control from the phone (Cast and friends).
  remote,

  /// The phone has developer access: rules work while it is home.
  home,

  /// The helper on the TV: rules run even with the phone away.
  alwaysOn,
}

Protection protectionOf(Tv tv, AgentLink link) {
  if (link.installed) return Protection.alwaysOn;
  if (tv.can(TvCapability.adb)) return Protection.home;
  return Protection.remote;
}

extension ProtectionLook on Protection {
  String get label => switch (this) {
        Protection.remote => 'Remote',
        Protection.home => 'Home mode',
        Protection.alwaysOn => 'Always On',
      };

  String get reach => switch (this) {
        Protection.remote => 'Control the TV from your phone.',
        Protection.home => 'Rules work while this phone is home.',
        Protection.alwaysOn => 'Rules run on the TV, even when you\'re away.',
      };

  IconData get icon => switch (this) {
        Protection.remote => Icons.phone_android_rounded,
        Protection.home => Icons.home_rounded,
        Protection.alwaysOn => Icons.shield_rounded,
      };

  Tone get tone => switch (this) {
        Protection.remote || Protection.home => Tone.info,
        Protection.alwaysOn => Tone.ok,
      };
}

/// The one button that fixes a problem.
enum ProblemFix { repair, reconnect, approveUpdate, resume, approvePhone }

/// Something the parent should know, in plain words, with one fix.
class HomeProblem {
  /// Berry (real problems) or calm blue (a state they chose).
  final bool serious;
  final String title;
  final String message;
  final String fixLabel;
  final String? fixNote;
  final ProblemFix fix;

  const HomeProblem({
    required this.title,
    required this.message,
    required this.fixLabel,
    required this.fix,
    this.fixNote,
    this.serious = true,
  });
}

/// What is wrong right now, if anything. Only asked while the TV is on.
HomeProblem? problemOf({
  required Tv tv,
  required AgentLink link,
  AdbSessionState? adb,
}) {
  final hasAdb = tv.can(TvCapability.adb);
  if (adb is AdbFailed && adb.authRejected && hasAdb && !link.installed) {
    return const HomeProblem(
      title: 'The TV stopped trusting this phone',
      message: 'Home mode needs one OK on the TV again. It takes a few '
          'seconds.',
      fixLabel: 'Approve on the TV',
      fix: ProblemFix.approvePhone,
    );
  }
  if (!link.installed) return null;
  if (link.kind == AgentLinkKind.authFailed) {
    return HomeProblem(
      title: 'Always On doesn\'t know this phone',
      message: 'This usually happens after the helper was set up again. '
          'Bedtime keeps running, but changes from here won\'t reach it.',
      fixLabel: hasAdb ? 'Repair' : 'Reconnect',
      fixNote: hasAdb ? 'about 1 minute' : null,
      fix: hasAdb ? ProblemFix.repair : ProblemFix.reconnect,
    );
  }
  if (link.kind == AgentLinkKind.down) {
    return HomeProblem(
      title: 'Always On is off right now',
      message: 'The TV switched off its helper, probably after an update. '
          'Bedtime won\'t run unless this phone is home.',
      fixLabel: 'Reconnect',
      fixNote: hasAdb ? 'about 1 minute' : null,
      fix: hasAdb ? ProblemFix.repair : ProblemFix.reconnect,
    );
  }
  final s = link.status;
  if (s == null) return null;
  if (s.buildChangedSinceApproval) {
    return const HomeProblem(
      title: 'Your TV installed an update',
      message: 'Tidying up waits until you\'ve checked the TV still works '
          'normally. Rules keep running.',
      fixLabel: 'Approve update',
      fix: ProblemFix.approveUpdate,
    );
  }
  if (s.mode == AgentMode.safe) {
    return const HomeProblem(
      serious: false,
      title: 'Always On is hands-off for now',
      message: 'It only watches and reports, and changes nothing on the TV '
          'until you turn it back on.',
      fixLabel: 'Turn back on',
      fix: ProblemFix.resume,
    );
  }
  if (s.mode == AgentMode.paused) {
    return const HomeProblem(
      serious: false,
      title: 'Always On is paused',
      message: 'Bedtime, limits and tidying up are on hold.',
      fixLabel: 'Resume',
      fix: ProblemFix.resume,
    );
  }
  if (s.isLimited) {
    return HomeProblem(
      title: 'Always On can\'t close apps yet',
      message: 'The TV hasn\'t given its helper permission. Repair asks '
          'again: look at the TV for one OK.',
      fixLabel: hasAdb ? 'Repair' : 'Reconnect',
      fixNote: hasAdb ? 'about 1 minute' : null,
      fix: hasAdb ? ProblemFix.repair : ProblemFix.reconnect,
    );
  }
  return null;
}

/// What keeps working during a problem (the "Still working" list).
List<(String, bool)> stillWorking(Tv tv) {
  final adb = tv.can(TvCapability.adb);
  return [
    ('Pause, Quiet and End app from your phone', true),
    ('YouTube without Shorts', adb),
    ('Bedtime when you\'re away', false),
  ];
}

// ── Time ──

/// "7:52 pm", or "19:52" on 24-hour phones.
String friendlyTime(BuildContext context, DateTime t) {
  final h24 = MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false;
  final mm = t.minute.toString().padLeft(2, '0');
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm ${t.hour < 12 ? 'am' : 'pm'}';
}

/// "2h 10m", "45m", "1h".
String spanLabel(Duration d) {
  final m = (d.inSeconds / 60).ceil();
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r.toString().padLeft(2, '0')}m';
}

/// The next (or current) bedtime window from the rules schedule.
class Bedtime {
  final DateTime start;
  final DateTime end;
  final bool now;
  const Bedtime(this.start, this.end, {this.now = false});
}

DateTime _at(DateTime day, String hhmm) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first) ?? 0;
  final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, h, m);
}

Bedtime? nextBedtime(List<ScheduleRow> schedule, DateTime now) {
  Bedtime? best;
  final today = DateTime(now.year, now.month, now.day);
  for (var d = -1; d <= 7; d++) {
    final day = today.add(Duration(days: d));
    for (final r in schedule) {
      if (!r.days.contains(day.weekday)) continue;
      final start = _at(day, r.from);
      var end = _at(day, r.to);
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
      if (!now.isBefore(start) && now.isBefore(end)) {
        return Bedtime(start, end, now: true);
      }
      if (start.isAfter(now) && (best == null || start.isBefore(best.start))) {
        best = Bedtime(start, end);
      }
    }
  }
  return best;
}

/// Minutes from [now] to the next bedtime, for the "Until bedtime" chip;
/// null when there is none within 12 hours or it is bedtime already.
int? minutesUntilBedtime(List<ScheduleRow> schedule, DateTime now) {
  final b = nextBedtime(schedule, now);
  if (b == null || b.now) return null;
  final m = (b.start.difference(now).inSeconds / 60).ceil();
  if (m < 5 || m > 12 * 60) return null;
  return m;
}

// ── Journals ──

bool isStopEntry(JournalEntry e) =>
    e.ok &&
    (e.op == 'stopApp' ||
        e.op == 'closeApp' ||
        e.op == 'blockedApp' ||
        e.op == 'closedApp' ||
        (e.op == 'break' && e.target.startsWith('closed ')));

/// Apps stopped today, from both journals.
int stopsToday(Iterable<ActivityItem> items, DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return items
      .where((i) => !i.entry.time.isBefore(day) && isStopEntry(i.entry))
      .length;
}

String stoppedAppOf(JournalEntry e) {
  final t = e.op == 'break' ? e.target.replaceFirst('closed ', '') : e.target;
  return t.contains('.') ? appLabel(t) : t;
}

/// Lines for "During this break": what the TV stopped since [since].
List<String> breakDigest(Iterable<ActivityItem> items, DateTime since) {
  final closed = <String, int>{};
  var muted = 0;
  for (final i in items) {
    final e = i.entry;
    if (e.time.isBefore(since) || !e.ok) continue;
    if (isStopEntry(e)) {
      final a = stoppedAppOf(e);
      closed[a] = (closed[a] ?? 0) + 1;
    } else if ((e.op == 'break' && e.target == 're-muted') ||
        (e.op == 'mute' && i.source == JournalSource.rule)) {
      muted++;
    }
  }
  return [
    for (final c in closed.entries)
      c.value == 1 ? '${c.key} was closed' : '${c.key} was closed ${c.value}×',
    if (muted > 0)
      muted == 1
          ? 'Sound went back off after the remote'
          : 'Sound went back off $muted× after the remote',
  ];
}

/// One line for "While you were away": what Always On did since [since].
String? awayDigest(Iterable<ActivityItem> items, DateTime since) {
  final closed = <String, int>{};
  var quiet = 0;
  var breaks = 0;
  var tidy = 0;
  for (final i in items) {
    final e = i.entry;
    if (i.source == JournalSource.phone || !e.time.isAfter(since)) continue;
    if (!e.ok) continue;
    if (isStopEntry(e)) {
      final a = stoppedAppOf(e);
      closed[a] = (closed[a] ?? 0) + 1;
    } else if (e.op == 'mute' || e.op == 'clampVolume') {
      quiet++;
    } else if (e.op == 'break') {
      breaks++;
    } else if (i.source == JournalSource.watchdog && e.op != 'watchdog') {
      tidy++;
    }
  }
  final parts = [
    if (breaks > 0) breaks == 1 ? 'A break ran' : '$breaks breaks ran',
    for (final c in closed.entries)
      c.value == 1
          ? '${c.key} was closed'
          : '${c.key} reopened ${c.value - 1}× and was closed',
    if (quiet > 0) 'Sound kept down $quiet×',
    if (tidy > 0) tidy == 1 ? 'Tidied 1 thing' : 'Tidied $tidy things',
  ];
  return parts.isEmpty ? null : parts.take(3).join(' · ');
}

// ── App tile ──

/// A recognisable tile for the app on the hero's TV.
({Color color, String glyph, IconData? icon}) appTileLook(NowPlaying now) {
  if (now.isHome || now.id == null) {
    return (
      color: const Color(0xFF3A8DFF),
      glyph: '',
      icon: Icons.home_rounded
    );
  }
  const known = {
    'org.smarttube.stable': (Color(0xFFFF3D2E), 'S'),
    'org.smarttube.beta': (Color(0xFFFF3D2E), 'S'),
    'com.teamsmart.videomanager.tv': (Color(0xFFFF3D2E), 'S'),
    'com.google.android.youtube.tv': (Color(0xFFFF0033), ''),
    'com.google.android.youtube.tvkids': (Color(0xFFE62117), ''),
    'com.netflix.ninja': (Color(0xFF141414), 'N'),
    'com.amazon.amazonvideo.livingroom': (Color(0xFF1A98FF), 'P'),
    'com.disney.disneyplus': (Color(0xFF113CCF), 'D'),
    'in.startv.hotstar': (Color(0xFF0F1B4C), 'J'),
    'com.spotify.tv.android': (Color(0xFF1DB954), ''),
    'com.plexapp.android': (Color(0xFFE5A00D), 'P'),
    'org.xbmc.kodi': (Color(0xFF17B2E7), 'K'),
  };
  final k = known[now.id];
  if (k != null) {
    final yt = now.id!.contains('youtube');
    final spotify = now.id!.contains('spotify');
    return (
      color: k.$1,
      glyph: k.$2,
      icon: yt
          ? Icons.play_arrow_rounded
          : spotify
              ? Icons.graphic_eq_rounded
              : null,
    );
  }
  const palette = [
    Color(0xFF8C7CFF),
    Color(0xFF1FBF8F),
    Color(0xFFFF6B4A),
    Color(0xFF3A8DFF),
    Color(0xFFC98200),
  ];
  final name = now.appName.trim();
  final hash = now.id!.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0xffff);
  return (
    color: palette[hash % palette.length],
    glyph: name.isEmpty ? '?' : name.characters.first.toUpperCase(),
    icon: null,
  );
}

// ── What's playing and "When this ends" ──

/// What Always On sees playing, when it matches the app on the TV; null
/// when there is nothing to show (no Always On, no session, Home screen).
AgentMedia? heroMediaOf(AgentLink link, NowPlaying now) {
  if (!link.up || !now.online || now.isHome) return null;
  final m = link.status!.media;
  if (m == null || !m.live) return null;
  if (now.id != null && m.pkg.isNotEmpty && now.id != m.pkg) return null;
  return m;
}

/// "about 21 min", rounded up and never below 1.
String aboutMinutes(Duration d) {
  final m = (d.inSeconds / 60).ceil().clamp(1, 24 * 60);
  return 'about $m min';
}

/// The "When this ends" chip in honest words: a time only when the TV
/// knows how long the video is.
/// Past the [kEndAfterCapMin] cap it says when the break really starts:
/// "In 45 min (55 left in this video)".
String endAfterLabel(AgentMedia m) {
  final left = m.timed ? m.left : null;
  if (left == null) return 'After this one';
  final mins = (left.inSeconds / 60).ceil().clamp(1, 24 * 60);
  if (mins > kEndAfterCapMin) {
    return 'In $kEndAfterCapMin min ($mins left in this video)';
  }
  return 'When this ends · ${aboutMinutes(left)}';
}

/// Longest wait for the video to end before the break starts anyway.
const kEndAfterCapMin = 45;

/// How long the break after this one lasts: an hour, or until bedtime is
/// over when it is bedtime already.
int endAfterBreakMinutes(List<ScheduleRow> schedule, DateTime now) {
  final b = nextBedtime(schedule, now);
  if (b != null && b.now) {
    return (b.end.difference(now).inSeconds / 60).ceil().clamp(1, 1440);
  }
  return 60;
}

/// Shorts the TV closed today, from Always On's journal.
int shortsStopsToday(Iterable<ActivityItem> items, DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return items
      .where(
        (i) =>
            i.entry.ok &&
            i.entry.op == 'shorts' &&
            i.entry.before.startsWith('shorts') &&
            !i.entry.time.isBefore(day),
      )
      .length;
}
