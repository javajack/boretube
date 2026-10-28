import '../../agent/agent_models.dart';

/// A ready-made routine. A preset fills the "shape" of the rules: quiet
/// hours, daily TV time, the volume limit, keeping it silent and how the
/// TV says no. Allowed apps, stock YouTube, video hopping and Tonight-only
/// overrides are the family's own choices and are never touched by a preset.
enum RulePreset { schoolNight, weekend, movieNight }

/// What the preset sets, kept as a small value so it can be shown,
/// applied and compared.
class PresetShape {
  final List<ScheduleRow> schedule;
  final int dailyLimitMin;
  final VolumeLimit volumeLimit;
  final bool alwaysMute;
  final RuleStyle style;

  const PresetShape({
    required this.schedule,
    required this.dailyLimitMin,
    required this.volumeLimit,
    this.alwaysMute = false,
    required this.style,
  });
}

extension RulePresetInfo on RulePreset {
  String get label => switch (this) {
        RulePreset.schoolNight => 'School night',
        RulePreset.weekend => 'Weekend',
        RulePreset.movieNight => 'Movie night',
      };

  /// One line for the template rows.
  String get blurb => switch (this) {
        RulePreset.schoolNight => 'Early bedtimes Sun–Thu, 2 h a day.',
        RulePreset.weekend => 'A little later at night, 3 h a day.',
        RulePreset.movieNight => 'A late night with no daily limit.',
      };

  PresetShape get shape => switch (this) {
        RulePreset.schoolNight => const PresetShape(
            schedule: [
              ScheduleRow(days: [1, 2, 3, 4, 7], from: '21:00', to: '07:00'),
              ScheduleRow(days: [5, 6], from: '22:30', to: '08:30'),
            ],
            dailyLimitMin: 120,
            volumeLimit: VolumeLimit(maxPercent: 30, enabled: true),
            style: RuleStyle.explicit,
          ),
        RulePreset.weekend => const PresetShape(
            schedule: [
              ScheduleRow(days: [1, 2, 3, 4, 7], from: '21:30', to: '07:00'),
              ScheduleRow(days: [5, 6], from: '23:00', to: '09:00'),
            ],
            dailyLimitMin: 180,
            volumeLimit: VolumeLimit(maxPercent: 40, enabled: true),
            style: RuleStyle.explicit,
          ),
        RulePreset.movieNight => const PresetShape(
            schedule: [
              ScheduleRow(
                days: [1, 2, 3, 4, 5, 6, 7],
                from: '23:30',
                to: '08:00',
              ),
            ],
            dailyLimitMin: 0,
            volumeLimit: VolumeLimit(maxPercent: 30),
            style: RuleStyle.explicit,
          ),
      };
}

/// [rules] with [p]'s shape filled in; everything else stays.
AgentRules applyPreset(AgentRules rules, RulePreset p) {
  final s = p.shape;
  return rules.copyWith(
    tvTime: rules.tvTime.copyWith(
      schedule: [for (final r in s.schedule) r.copyWith()],
      dailyLimitMin: s.dailyLimitMin,
    ),
    volumeLimit: s.volumeLimit,
    alwaysMute: s.alwaysMute,
    style: s.style,
  );
}

String _rowKey(ScheduleRow r) =>
    '${([...r.days]..sort()).join(',')}|${r.from}|${r.to}';

/// The preset [rules] currently match, or null for Custom. Windows are
/// compared as a set (order doesn't matter); a disabled volume limit
/// matches whatever its stored cap is.
RulePreset? detectPreset(AgentRules rules) {
  final have = {for (final r in rules.tvTime.schedule) _rowKey(r)};
  for (final p in RulePreset.values) {
    final s = p.shape;
    final want = {for (final r in s.schedule) _rowKey(r)};
    final v = rules.volumeLimit;
    final sameVolume = v.enabled == s.volumeLimit.enabled &&
        (!v.enabled || v.maxPercent == s.volumeLimit.maxPercent);
    if (have.length == rules.tvTime.schedule.length &&
        have.length == want.length &&
        have.containsAll(want) &&
        rules.tvTime.dailyLimitMin == s.dailyLimitMin &&
        sameVolume &&
        rules.alwaysMute == s.alwaysMute &&
        rules.style == s.style) {
      return p;
    }
  }
  return null;
}

/// True for a rules document nobody has shaped yet (the template state).
bool isBlankRoutine(AgentRules r) =>
    r.tvTime.schedule.isEmpty &&
    r.tvTime.dailyLimitMin == 0 &&
    !r.volumeLimit.enabled &&
    !r.alwaysMute;

// ── words ──

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Sun–Thu", "Fri & Sat", "Every day", "Weekdays", "Mon, Wed".
String daysLabel(List<int> days) {
  final d = {...days}..removeWhere((x) => x < 1 || x > 7);
  if (d.isEmpty) return 'No days';
  if (d.length == 7) return 'Every day';
  if (d.length == 5 && d.containsAll([1, 2, 3, 4, 5])) return 'Weekdays';
  if (d.length == 2 && d.containsAll([6, 7])) return 'Weekends';
  // Find one run around the week (Sunday may start it).
  for (var start = 1; start <= 7; start++) {
    final run = [for (var i = 0; i < d.length; i++) ((start - 1 + i) % 7) + 1];
    if (run.every(d.contains) && !d.contains(((start + 5) % 7) + 1)) {
      if (d.length == 1) return dayNames[start - 1];
      if (d.length == 2) {
        return '${dayNames[run.first - 1]} & ${dayNames[run.last - 1]}';
      }
      return '${dayNames[run.first - 1]}–${dayNames[run.last - 1]}';
    }
  }
  return ([...d]..sort()).map((x) => dayNames[x - 1]).join(', ');
}

/// "9:00 pm" from "21:00" (or "21:00" on 24-hour phones).
String hhmmLabel(String hhmm, {bool h24 = false}) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first) ?? 0;
  final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
  final mm = m.toString().padLeft(2, '0');
  if (h24) return '${h.toString().padLeft(2, '0')}:$mm';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$mm ${h < 12 ? 'am' : 'pm'}';
}

/// "2 h", "1 h 30 min", "45 min", "Off".
String minutesLabel(int m) {
  if (m <= 0) return 'Off';
  final h = m ~/ 60;
  final rest = m % 60;
  if (h == 0) return '$rest min';
  return rest == 0 ? '$h h' : '$h h $rest min';
}

/// Plain lines describing a shape (the preset confirm sheet).
List<String> shapeSummary(PresetShape s, {bool h24 = false}) => [
      for (final r in s.schedule)
        'Bedtime ${daysLabel(r.days)}: '
            '${hhmmLabel(r.from, h24: h24)} – ${hhmmLabel(r.to, h24: h24)}',
      s.dailyLimitMin == 0
          ? 'No daily TV time limit'
          : 'Daily TV time: ${minutesLabel(s.dailyLimitMin)}',
      s.volumeLimit.enabled
          ? 'Volume up to ${s.volumeLimit.maxPercent}%'
          : 'No volume limit',
      s.style == RuleStyle.explicit
          ? 'The TV says no with a friendly message'
          : 'The TV says no quietly',
    ];

/// What differs between two rule documents, in parent words (the conflict
/// sheet). Ignores version and author.
List<String> rulesDiff(AgentRules a, AgentRules b) {
  final out = <String>[];
  String sched(AgentRules r) =>
      ({for (final x in r.tvTime.schedule) _rowKey(x)}.toList()..sort())
          .join(';');
  if (sched(a) != sched(b)) out.add('Bedtime and quiet hours');
  if (a.tvTime.dailyLimitMin != b.tvTime.dailyLimitMin) {
    out.add('Daily TV time');
  }
  if (a.allowedApps.mode != b.allowedApps.mode ||
      ({...a.allowedApps.packages}.length != b.allowedApps.packages.length ||
          !{...a.allowedApps.packages}.containsAll(b.allowedApps.packages))) {
    out.add('Allowed apps');
  }
  if (a.volumeLimit.enabled != b.volumeLimit.enabled ||
      a.volumeLimit.maxPercent != b.volumeLimit.maxPercent) {
    out.add('Volume limit');
  }
  if (a.alwaysMute != b.alwaysMute) out.add('Keep it silent');
  if (a.style != b.style) out.add('How the TV says no');
  if (a.stockYouTubeAllowed != b.stockYouTubeAllowed) {
    out.add('Stock YouTube');
  }
  final sa = a.shortsRule;
  final sb = b.shortsRule;
  if (sa.mode != sb.mode ||
      (sa.mode == ShortsMode.budget && sa.perDay != sb.perDay) ||
      (sa.mode == ShortsMode.cooldown && sa.cooldownMin != sb.cooldownMin)) {
    out.add('Video hopping');
  }
  String ov(AgentRules r) => ([
        for (final o in r.overrides) '${o.kind.name}${o.pkg}${o.until}'
      ]..sort())
          .join(';');
  if (ov(a) != ov(b)) out.add('Tonight only');
  return out;
}
