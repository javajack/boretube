// Typed models for the TV Guard agent API (contract v1, see
// docs/superpowers/plans/2026-10-28-boretube-v2-p2.md).
//
// Parsing is lenient (unknown enum values fall back, times may be epoch
// ms or ISO strings) so a newer agent never breaks the app; unknown
// top-level rule fields are kept and written back on PUT.

/// The agent's package; also pinned by the installer.
const kAgentPackage = 'com.rakesh.boretube.agent';

/// The API version this app speaks.
const kAgentApi = 1;

/// Parses an epoch-ms number or an ISO-8601 string.
DateTime? parseAgentTime(Object? v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String) {
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    if (n != null) return DateTime.fromMillisecondsSinceEpoch(n);
    return DateTime.tryParse(v);
  }
  return null;
}

T _enum<T extends Enum>(List<T> values, Object? v, T fallback) {
  for (final e in values) {
    if (e.name == v) return e;
  }
  return fallback;
}

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

bool _bool(Object? v) => v == true || v == 'true' || (v is num && v != 0);

String _str(Object? v) => v == null ? '' : (v is String ? v : '$v');

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

List<Object?> _list(Object? v) => v is List ? v : const [];

// ── status ──

enum SelfAdb { ok, needsApproval, unavailable, unknown }

enum AgentMode { normal, paused, safe }

class AgentNow {
  final String? foreground;
  final int volume;
  final int min;
  final int max;
  final bool muted;

  const AgentNow({
    this.foreground,
    this.volume = 0,
    this.min = 0,
    this.max = 100,
    this.muted = false,
  });

  int get percent =>
      max <= min ? 0 : ((volume - min) * 100 / (max - min)).round();

  factory AgentNow.fromJson(Map<String, dynamic> j) => AgentNow(
        foreground: (j['foreground'] as String?)?.isEmpty ?? true
            ? null
            : j['foreground'] as String,
        volume: _int(j['volume']),
        min: _int(j['min']),
        max: _int(j['max'], 100),
        muted: _bool(j['muted']),
      );

  Map<String, dynamic> toJson() => {
        'foreground': foreground,
        'volume': volume,
        'min': min,
        'max': max,
        'muted': muted,
      };
}

class AgentBreak {
  final bool active;
  final DateTime? endsAt;

  const AgentBreak({this.active = false, this.endsAt});

  factory AgentBreak.fromJson(Map<String, dynamic> j) => AgentBreak(
        active: _bool(j['active']),
        endsAt: parseAgentTime(j['endsAt']),
      );

  Map<String, dynamic> toJson() => {
        'active': active,
        'endsAt': endsAt?.toUtc().toIso8601String(),
      };
}

enum AgentHealthStatus { ok, warn, fail, unknown }

class AgentHealth {
  final String id;
  final AgentHealthStatus status;
  final String detail;

  const AgentHealth({
    required this.id,
    required this.status,
    this.detail = '',
  });

  static AgentHealthStatus _status(Object? v) => switch (v) {
        'ok' || 'pass' || 'good' => AgentHealthStatus.ok,
        'warn' || 'warning' || 'pending' => AgentHealthStatus.warn,
        'fail' || 'error' || 'bad' => AgentHealthStatus.fail,
        _ => AgentHealthStatus.unknown,
      };

  factory AgentHealth.fromJson(Map<String, dynamic> j) => AgentHealth(
        id: _str(j['id']),
        status: _status(j['status']),
        detail: _str(j['detail']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'status': status.name, 'detail': detail};
}

enum MediaState { none, stopped, paused, playing, buffering, error, other }

enum MediaSource { listener, dumpsys, unknown }

/// `status.media` (1.1.0+): the foreground app's media session. Absent
/// when there is none, or the agent can't read sessions.
class AgentMedia {
  final String pkg;
  final String? title;

  /// The channel, artist or show line under the title.
  final String? artist;
  final MediaState state;
  final int positionMs;

  /// Only from the listener path; never guessed.
  final int? durationMs;
  final int? remainingMs;
  final MediaSource source;

  const AgentMedia({
    required this.pkg,
    this.title,
    this.artist,
    this.state = MediaState.other,
    this.positionMs = 0,
    this.durationMs,
    this.remainingMs,
    this.source = MediaSource.unknown,
  });

  /// Something is on (playing, paused or loading), not over.
  bool get live =>
      state == MediaState.playing ||
      state == MediaState.paused ||
      state == MediaState.buffering;

  /// The duration is known (so "about N min" is honest).
  bool get timed => durationMs != null && durationMs! > 0;

  /// What is left, from [remainingMs] or the duration and position.
  Duration? get left {
    final r = remainingMs ??
        (timed ? (durationMs! - positionMs).clamp(0, durationMs!) : null);
    return r == null ? null : Duration(milliseconds: r);
  }

  /// 0..1 through the video, when the duration is known.
  double? get progress =>
      timed ? (positionMs / durationMs!).clamp(0.0, 1.0) : null;

  static String? _opt(Object? v) {
    final s = _str(v).trim();
    return s.isEmpty ? null : s;
  }

  static int? _optInt(Object? v) => v == null ? null : _int(v);

  factory AgentMedia.fromJson(Map<String, dynamic> j) => AgentMedia(
        pkg: _str(j['pkg']),
        title: _opt(j['title']),
        artist: _opt(j['artist']),
        state: _enum(MediaState.values, j['state'], MediaState.other),
        positionMs: _int(j['positionMs']),
        durationMs: _optInt(j['durationMs']),
        remainingMs: _optInt(j['remainingMs']),
        source: _enum(MediaSource.values, j['source'], MediaSource.unknown),
      );

  Map<String, dynamic> toJson() => {
        'pkg': pkg,
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        'state': state.name,
        'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
        if (remainingMs != null) 'remainingMs': remainingMs,
        'source': source.name,
      };
}

/// `status.endAfter` (1.1.0+): "pause after this one" is armed.
class AgentEndAfter {
  final bool armed;
  final DateTime? startedAt;

  /// The latest the break starts, even if the video never ends.
  final DateTime? capAt;
  final String? title;
  final String? pkg;
  final int? breakMin;

  const AgentEndAfter({
    this.armed = false,
    this.startedAt,
    this.capAt,
    this.title,
    this.pkg,
    this.breakMin,
  });

  factory AgentEndAfter.fromJson(Map<String, dynamic> j) => AgentEndAfter(
        armed: _bool(j['armed']),
        startedAt: parseAgentTime(j['startedAt']),
        capAt: parseAgentTime(j['capAt']),
        title: AgentMedia._opt(j['title']),
        pkg: AgentMedia._opt(j['pkg']),
        breakMin: AgentMedia._optInt(j['breakMin']),
      );

  Map<String, dynamic> toJson() => {
        'armed': armed,
        if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
        if (capAt != null) 'capAt': capAt!.millisecondsSinceEpoch,
        if (title != null) 'title': title,
        if (pkg != null) 'pkg': pkg,
        if (breakMin != null) 'breakMin': breakMin,
      };
}

/// What the TV does about Shorts and video hopping (`rules.shorts.mode`).
/// [cooldown] (agent 1.3.0+) closes the video apps for
/// `rules.shorts.cooldownMin` minutes; [budget] is still read but no longer
/// offered in the app.
enum ShortsMode { off, block, cooldown, budget, report }

/// `status.shorts` (1.1.0+): today's Shorts count and the rule in force.
class AgentShorts {
  final ShortsMode mode;
  final int todayCount;
  final DateTime? lastDetectedAt;

  /// A Shorts session is going on right now.
  final bool active;

  /// The daily budget (budget mode only).
  final int? perDay;

  /// Video apps stay closed until then (cool-down mode); null when no
  /// cool-down is running or the agent is older.
  final DateTime? cooldownUntil;

  const AgentShorts({
    this.mode = ShortsMode.off,
    this.todayCount = 0,
    this.lastDetectedAt,
    this.active = false,
    this.perDay,
    this.cooldownUntil,
  });

  factory AgentShorts.fromJson(Map<String, dynamic> j) => AgentShorts(
        mode: _enum(ShortsMode.values, j['mode'], ShortsMode.off),
        todayCount: _int(j['todayCount']),
        lastDetectedAt: parseAgentTime(j['lastDetectedAt']),
        active: _bool(j['active']),
        perDay: AgentMedia._optInt(j['perDay']),
        cooldownUntil: parseAgentTime(j['cooldownUntil']),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'todayCount': todayCount,
        if (lastDetectedAt != null)
          'lastDetectedAt': lastDetectedAt!.millisecondsSinceEpoch,
        'active': active,
        if (perDay != null) 'perDay': perDay,
        if (cooldownUntil != null)
          'cooldownUntil': cooldownUntil!.millisecondsSinceEpoch,
      };
}

/// `GET /v1/status`.
class AgentStatus {
  final String agentId;
  final String version;
  final int api;
  final int uptimeSec;
  final int bootCount;
  final SelfAdb selfAdb;
  final AgentMode mode;
  final AgentNow now;
  final int activeRulesVersion;
  final AgentBreak breakState;
  final List<AgentHealth> health;
  final String buildFingerprint;
  final bool buildChangedSinceApproval;
  final bool clockSkewWarn;

  /// Seconds the TV clock differs from the phone's (`X-Phone-Time`).
  final int clockSkewSec;

  /// The agent can't do everything (e.g. no self-ADB, a missing grant).
  final bool limited;
  final List<String> limitedReasons;

  /// A permission is missing: the phone re-runs its grant commands.
  final bool needsPhoneGrant;

  /// How it drives sound, e.g. `audioManager` or `adbKeys`.
  final String soundPath;

  /// Watchdog ops held until the parent approves the build.
  final int watchdogPending;

  /// What is being enforced right now, in plain words.
  final List<String> activeReasons;

  /// The foreground media session (1.1.0+), or null.
  final AgentMedia? media;

  /// "Pause after this one" (1.1.0+).
  final AgentEndAfter endAfter;

  /// Today's Shorts (1.1.0+), or null from an older agent.
  final AgentShorts? shorts;

  const AgentStatus({
    required this.agentId,
    required this.version,
    this.api = kAgentApi,
    this.uptimeSec = 0,
    this.bootCount = 0,
    this.selfAdb = SelfAdb.ok,
    this.mode = AgentMode.normal,
    this.now = const AgentNow(),
    this.activeRulesVersion = 0,
    this.breakState = const AgentBreak(),
    this.health = const [],
    this.buildFingerprint = '',
    this.buildChangedSinceApproval = false,
    this.clockSkewWarn = false,
    this.clockSkewSec = 0,
    this.limited = false,
    this.limitedReasons = const [],
    this.needsPhoneGrant = false,
    this.soundPath = '',
    this.watchdogPending = 0,
    this.activeReasons = const [],
    this.media,
    this.endAfter = const AgentEndAfter(),
    this.shorts,
  });

  /// The health entry [id], if the agent reports it.
  AgentHealth? healthOf(String id) {
    for (final h in health) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// The agent can't read media sessions properly (listener access is
  /// missing). False when an older agent doesn't report it.
  bool get mediaAccessMissing {
    final h = healthOf('mediaAccess');
    return h != null && h.status != AgentHealthStatus.ok;
  }

  /// Self-ADB isn't approved, or the agent says it is limited.
  bool get isLimited => limited || selfAdb != SelfAdb.ok;

  factory AgentStatus.fromJson(Map<String, dynamic> j) => AgentStatus(
        agentId: _str(j['agentId']),
        version: _str(j['version']),
        api: _int(j['api'], kAgentApi),
        uptimeSec: _int(j['uptimeSec']),
        bootCount: _int(j['bootCount']),
        selfAdb: _enum(SelfAdb.values, j['selfAdb'], SelfAdb.unknown),
        mode: _enum(AgentMode.values, j['mode'], AgentMode.normal),
        now: AgentNow.fromJson(_map(j['now'])),
        activeRulesVersion: _int(j['activeRulesVersion']),
        breakState: AgentBreak.fromJson(_map(j['break'])),
        health: [
          for (final h in _list(j['health']))
            if (h is Map) AgentHealth.fromJson(h.cast<String, dynamic>()),
        ],
        buildFingerprint: _str(j['buildFingerprint']),
        buildChangedSinceApproval: _bool(j['buildChangedSinceApproval']),
        clockSkewWarn: _bool(j['clockSkewWarn']),
        clockSkewSec: _int(j['clockSkewSec']),
        limited: _bool(j['limited']),
        limitedReasons: [for (final r in _list(j['limitedReasons'])) _str(r)],
        needsPhoneGrant: _bool(j['needsPhoneGrant']),
        soundPath: _str(j['soundPath']),
        watchdogPending: j['watchdogPending'] is List
            ? (j['watchdogPending'] as List).length
            : _int(j['watchdogPending']),
        activeReasons: [for (final r in _list(j['activeReasons'])) _str(r)],
        media: j['media'] is Map ? AgentMedia.fromJson(_map(j['media'])) : null,
        endAfter: AgentEndAfter.fromJson(_map(j['endAfter'])),
        shorts:
            j['shorts'] is Map ? AgentShorts.fromJson(_map(j['shorts'])) : null,
      );

  Map<String, dynamic> toJson() => {
        'agentId': agentId,
        'version': version,
        'api': api,
        'uptimeSec': uptimeSec,
        'bootCount': bootCount,
        'selfAdb': selfAdb.name,
        'mode': mode.name,
        'now': now.toJson(),
        'activeRulesVersion': activeRulesVersion,
        'break': breakState.toJson(),
        'health': [for (final h in health) h.toJson()],
        'buildFingerprint': buildFingerprint,
        'buildChangedSinceApproval': buildChangedSinceApproval,
        'clockSkewWarn': clockSkewWarn,
        'clockSkewSec': clockSkewSec,
        'limited': limited,
        'limitedReasons': limitedReasons,
        'needsPhoneGrant': needsPhoneGrant,
        'soundPath': soundPath,
        'watchdogPending': watchdogPending,
        'activeReasons': activeReasons,
        if (media != null) 'media': media!.toJson(),
        if (endAfter.armed) 'endAfter': endAfter.toJson(),
        if (shorts != null) 'shorts': shorts!.toJson(),
      };
}

/// `GET/POST /v1/watchdog`: what the watchdog would do (or did).
class WatchdogReport {
  final bool ok;
  final String detail;
  final List<String> lines;
  final Map<String, dynamic> raw;

  const WatchdogReport({
    this.ok = true,
    this.detail = '',
    this.lines = const [],
    this.raw = const {},
  });

  static String _line(Object? o) {
    if (o is! Map) return _str(o);
    final m = o.cast<String, dynamic>();
    final head = [
      for (final k in const ['op', 'action', 'kind', 'id'])
        if (m[k] != null) _str(m[k]),
    ].take(1).join();
    final target = _str(m['target'] ?? m['pkg'] ?? m['package']);
    final status = _str(m['status'] ?? m['result'] ?? m['state']);
    final why = _str(m['detail'] ?? m['reason'] ?? m['why']);
    return [
      [head, target].where((s) => s.isNotEmpty).join(' '),
      if (status.isNotEmpty) status,
      if (why.isNotEmpty) why,
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  factory WatchdogReport.fromJson(Object? j) {
    if (j is List) {
      return WatchdogReport(lines: [for (final o in j) _line(o)]);
    }
    final m = _map(j);
    List<Object?> list = const [];
    for (final k in const ['ops', 'planned', 'steps', 'actions', 'report']) {
      if (m[k] is List) {
        list = m[k] as List;
        break;
      }
    }
    return WatchdogReport(
      ok: m['ok'] == null || _bool(m['ok']),
      detail: _str(m['detail'] ?? m['summary']),
      lines: [
        for (final o in list)
          if (_line(o).isNotEmpty) _line(o),
      ],
      raw: m,
    );
  }
}

// ── rules ──

enum RuleStyle { sneaky, explicit }

enum AppsMode { off, allowlist, blocklist }

class AllowedApps {
  final AppsMode mode;
  final List<String> packages;

  const AllowedApps({this.mode = AppsMode.off, this.packages = const []});

  factory AllowedApps.fromJson(Map<String, dynamic> j) => AllowedApps(
        mode: _enum(AppsMode.values, j['mode'], AppsMode.off),
        packages: [for (final p in _list(j['packages'])) _str(p)],
      );

  Map<String, dynamic> toJson() => {'mode': mode.name, 'packages': packages};

  AllowedApps copyWith({AppsMode? mode, List<String>? packages}) => AllowedApps(
        mode: mode ?? this.mode,
        packages: packages ?? this.packages,
      );
}

class VolumeLimit {
  final int maxPercent;
  final bool enabled;

  const VolumeLimit({this.maxPercent = 30, this.enabled = false});

  factory VolumeLimit.fromJson(Map<String, dynamic> j) => VolumeLimit(
        maxPercent: _int(j['maxPercent'], 30).clamp(0, 100),
        enabled: _bool(j['enabled']),
      );

  Map<String, dynamic> toJson() =>
      {'maxPercent': maxPercent, 'enabled': enabled};

  VolumeLimit copyWith({int? maxPercent, bool? enabled}) => VolumeLimit(
        maxPercent: maxPercent ?? this.maxPercent,
        enabled: enabled ?? this.enabled,
      );
}

/// A blocked window. [days] are ISO weekdays (1 = Monday … 7 = Sunday);
/// [from]/[to] are "HH:MM" on the TV's clock. A window whose [to] is
/// before [from] runs past midnight.
class ScheduleRow {
  final List<int> days;
  final String from;
  final String to;

  const ScheduleRow({
    this.days = const [1, 2, 3, 4, 5],
    this.from = '21:00',
    this.to = '07:00',
  });

  bool get crossesMidnight => to.compareTo(from) <= 0;

  factory ScheduleRow.fromJson(Map<String, dynamic> j) => ScheduleRow(
        days: [for (final d in _list(j['days'])) _int(d)]..sort(),
        from: _str(j['from']).isEmpty ? '21:00' : _str(j['from']),
        to: _str(j['to']).isEmpty ? '07:00' : _str(j['to']),
      );

  Map<String, dynamic> toJson() => {'days': days, 'from': from, 'to': to};

  ScheduleRow copyWith({List<int>? days, String? from, String? to}) =>
      ScheduleRow(
        days: days ?? this.days,
        from: from ?? this.from,
        to: to ?? this.to,
      );
}

class TvTime {
  final List<ScheduleRow> schedule;

  /// Minutes per day; 0 = no daily limit.
  final int dailyLimitMin;

  const TvTime({this.schedule = const [], this.dailyLimitMin = 0});

  factory TvTime.fromJson(Map<String, dynamic> j) => TvTime(
        schedule: [
          for (final r in _list(j['schedule']))
            if (r is Map) ScheduleRow.fromJson(r.cast<String, dynamic>()),
        ],
        dailyLimitMin: _int(j['dailyLimitMin']),
      );

  Map<String, dynamic> toJson() => {
        'schedule': [for (final r in schedule) r.toJson()],
        'dailyLimitMin': dailyLimitMin,
      };

  TvTime copyWith({List<ScheduleRow>? schedule, int? dailyLimitMin}) => TvTime(
        schedule: schedule ?? this.schedule,
        dailyLimitMin: dailyLimitMin ?? this.dailyLimitMin,
      );
}

/// `rules.shorts` (1.1.0+). Absent means off; [extra] keeps fields this
/// app doesn't know.
class ShortsRule {
  final ShortsMode mode;

  /// Shorts a day before the TV says no ([ShortsMode.budget] only).
  final int perDay;

  /// Minutes the video apps stay closed ([ShortsMode.cooldown] only).
  final int cooldownMin;
  final Map<String, dynamic> extra;

  static const defaultPerDay = 5;
  static const minPerDay = 1;
  static const maxPerDay = 20;
  static const defaultCooldownMin = 10;

  const ShortsRule({
    this.mode = ShortsMode.off,
    this.perDay = defaultPerDay,
    this.cooldownMin = defaultCooldownMin,
    this.extra = const {},
  });

  factory ShortsRule.fromJson(Map<String, dynamic> j) => ShortsRule(
        mode: _enum(ShortsMode.values, j['mode'], ShortsMode.off),
        perDay: j['perDay'] == null
            ? defaultPerDay
            : _int(j['perDay'], defaultPerDay).clamp(0, 1000),
        cooldownMin: j['cooldownMin'] == null
            ? defaultCooldownMin
            : _int(j['cooldownMin'], defaultCooldownMin).clamp(1, 240),
        extra: {
          for (final e in j.entries)
            if (e.key != 'mode' && e.key != 'perDay' && e.key != 'cooldownMin')
              e.key: e.value,
        },
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'mode': mode.name,
        'perDay': perDay,
        if (mode == ShortsMode.cooldown || cooldownMin != defaultCooldownMin)
          'cooldownMin': cooldownMin,
      };

  ShortsRule copyWith({ShortsMode? mode, int? perDay, int? cooldownMin}) =>
      ShortsRule(
        mode: mode ?? this.mode,
        perDay: perDay ?? this.perDay,
        cooldownMin: cooldownMin ?? this.cooldownMin,
        extra: extra,
      );
}

enum OverrideKind { allowApp, muteUntil, breakUntil }

class RuleOverride {
  final OverrideKind kind;
  final String? pkg;

  /// ISO-8601 (kept as sent so a PUT writes it back unchanged).
  final String until;

  const RuleOverride({required this.kind, this.pkg, required this.until});

  DateTime? get untilTime => parseAgentTime(until);

  bool activeAt(DateTime now) {
    final u = untilTime;
    return u != null && u.isAfter(now);
  }

  factory RuleOverride.fromJson(Map<String, dynamic> j) => RuleOverride(
        kind: _enum(OverrideKind.values, j['kind'], OverrideKind.allowApp),
        pkg: (j['pkg'] as String?)?.isEmpty ?? true ? null : j['pkg'] as String,
        until: _str(j['until']),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (pkg != null) 'pkg': pkg,
        'until': until,
      };
}

/// The rules document (`GET/PUT /v1/rules`).
class AgentRules {
  final int version;
  final String updatedBy;

  /// ISO-8601, kept as sent.
  final String updatedAt;
  final RuleStyle style;
  final AllowedApps allowedApps;
  final VolumeLimit volumeLimit;
  final bool alwaysMute;
  final TvTime tvTime;
  final List<RuleOverride> overrides;
  final bool stockYouTubeAllowed;

  /// The Shorts rule; null when the TV has none (written back absent).
  final ShortsRule? shorts;

  /// Top-level fields this app doesn't know; written back on PUT.
  final Map<String, dynamic> extra;

  const AgentRules({
    this.version = 0,
    this.updatedBy = '',
    this.updatedAt = '',
    this.style = RuleStyle.sneaky,
    this.allowedApps = const AllowedApps(),
    this.volumeLimit = const VolumeLimit(),
    this.alwaysMute = false,
    this.tvTime = const TvTime(),
    this.overrides = const [],
    this.stockYouTubeAllowed = false,
    this.shorts,
    this.extra = const {},
  });

  /// The Shorts rule in force (off when absent).
  ShortsRule get shortsRule => shorts ?? const ShortsRule();

  DateTime? get updatedAtTime => parseAgentTime(updatedAt);

  static const _known = {
    'version',
    'updatedBy',
    'updatedAt',
    'style',
    'allowedApps',
    'volumeLimit',
    'alwaysMute',
    'tvTime',
    'overrides',
    'stockYouTubeAllowed',
    'shorts',
  };

  /// Whether [j] looks like a rules document (vs. an error body).
  static bool looksLike(Object? j) => j is Map && j['version'] is num;

  factory AgentRules.fromJson(Map<String, dynamic> j) => AgentRules(
        version: _int(j['version']),
        updatedBy: _str(j['updatedBy']),
        updatedAt: _str(j['updatedAt']),
        style: _enum(RuleStyle.values, j['style'], RuleStyle.sneaky),
        allowedApps: AllowedApps.fromJson(_map(j['allowedApps'])),
        volumeLimit: VolumeLimit.fromJson(_map(j['volumeLimit'])),
        alwaysMute: _bool(j['alwaysMute']),
        tvTime: TvTime.fromJson(_map(j['tvTime'])),
        overrides: [
          for (final o in _list(j['overrides']))
            if (o is Map) RuleOverride.fromJson(o.cast<String, dynamic>()),
        ],
        stockYouTubeAllowed: _bool(j['stockYouTubeAllowed']),
        shorts:
            j['shorts'] is Map ? ShortsRule.fromJson(_map(j['shorts'])) : null,
        extra: {
          for (final e in j.entries)
            if (!_known.contains(e.key)) e.key: e.value,
        },
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'version': version,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt,
        'style': style.name,
        'allowedApps': allowedApps.toJson(),
        'volumeLimit': volumeLimit.toJson(),
        'alwaysMute': alwaysMute,
        'tvTime': tvTime.toJson(),
        'overrides': [for (final o in overrides) o.toJson()],
        'stockYouTubeAllowed': stockYouTubeAllowed,
        if (shorts != null) 'shorts': shorts!.toJson(),
      };

  AgentRules copyWith({
    int? version,
    String? updatedBy,
    String? updatedAt,
    RuleStyle? style,
    AllowedApps? allowedApps,
    VolumeLimit? volumeLimit,
    bool? alwaysMute,
    TvTime? tvTime,
    List<RuleOverride>? overrides,
    bool? stockYouTubeAllowed,
    ShortsRule? shorts,

    /// Drops [shorts] (back to "absent", which means off).
    bool clearShorts = false,
  }) =>
      AgentRules(
        version: version ?? this.version,
        updatedBy: updatedBy ?? this.updatedBy,
        updatedAt: updatedAt ?? this.updatedAt,
        style: style ?? this.style,
        allowedApps: allowedApps ?? this.allowedApps,
        volumeLimit: volumeLimit ?? this.volumeLimit,
        alwaysMute: alwaysMute ?? this.alwaysMute,
        tvTime: tvTime ?? this.tvTime,
        overrides: overrides ?? this.overrides,
        stockYouTubeAllowed: stockYouTubeAllowed ?? this.stockYouTubeAllowed,
        shorts: clearShorts ? null : shorts ?? this.shorts,
        extra: extra,
      );
}

// ── actions ──

enum AgentActionKind {
  mute,
  unmute,
  stop,
  volume,
  bore,
  restore,
  startBreak,
  endBreak,
  muteFor,

  /// Start a break when the foreground video ends (1.1.0+).
  endAfter,
  cancelEndAfter;

  /// The wire name (`break` is a Dart keyword).
  String get wire => this == startBreak ? 'break' : name;
}

/// `POST /v1/action` body.
class AgentAction {
  final AgentActionKind kind;

  /// Volume percent for [AgentActionKind.volume].
  final int? value;

  /// Duration for `break` and `muteFor`.
  final int? minutes;

  /// `endAfter`: the latest the break starts, in minutes from now.
  final int? capMin;

  /// `endAfter`: how long the break that follows lasts.
  final int? breakMin;

  const AgentAction(
    this.kind, {
    this.value,
    this.minutes,
    this.capMin,
    this.breakMin,
  });

  /// "Pause after this one". The agent's defaults are 45 and 60.
  const AgentAction.endAfter({this.capMin = 45, this.breakMin = 60})
      : kind = AgentActionKind.endAfter,
        value = null,
        minutes = null;

  const AgentAction.volume(int percent)
      : kind = AgentActionKind.volume,
        value = percent,
        minutes = null,
        capMin = null,
        breakMin = null;

  const AgentAction.startBreak(int this.minutes)
      : kind = AgentActionKind.startBreak,
        value = null,
        capMin = null,
        breakMin = null;

  const AgentAction.muteFor(int this.minutes)
      : kind = AgentActionKind.muteFor,
        value = null,
        capMin = null,
        breakMin = null;

  Map<String, dynamic> toJson() => {
        'action': kind.wire,
        if (value != null) 'value': value,
        if (minutes != null) 'minutes': minutes,
        if (capMin != null) 'capMin': capMin,
        if (breakMin != null) 'breakMin': breakMin,
      };

  factory AgentAction.fromJson(Map<String, dynamic> j) {
    final a = j['action'];
    final kind = a == 'break'
        ? AgentActionKind.startBreak
        : _enum(AgentActionKind.values, a, AgentActionKind.restore);
    return AgentAction(
      kind,
      value: j['value'] == null ? null : _int(j['value']),
      minutes: j['minutes'] == null ? null : _int(j['minutes']),
      capMin: j['capMin'] == null ? null : _int(j['capMin']),
      breakMin: j['breakMin'] == null ? null : _int(j['breakMin']),
    );
  }
}

/// `{ok, detail}`; `endsAt` when the agent includes it for break/muteFor.
class AgentActionResult {
  final bool ok;
  final String detail;
  final DateTime? endsAt;

  const AgentActionResult({required this.ok, this.detail = '', this.endsAt});

  factory AgentActionResult.fromJson(Map<String, dynamic> j) =>
      AgentActionResult(
        ok: _bool(j['ok']),
        detail: _str(j['detail']),
        endsAt: parseAgentTime(j['endsAt']),
      );
}

// ── journal ──

enum JournalSource { agent, watchdog, rule, phone }

class AgentJournalEntry {
  final DateTime time;
  final String op;
  final String target;
  final String before;
  final String after;
  final bool ok;
  final JournalSource source;

  const AgentJournalEntry({
    required this.time,
    required this.op,
    this.target = '',
    this.before = '',
    this.after = '',
    this.ok = true,
    this.source = JournalSource.agent,
  });

  factory AgentJournalEntry.fromJson(Map<String, dynamic> j) =>
      AgentJournalEntry(
        time:
            parseAgentTime(j['time']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        op: _str(j['op']),
        target: _str(j['target']),
        before: _str(j['before']),
        after: _str(j['after']),
        ok: j['ok'] == null || _bool(j['ok']),
        source: _enum(JournalSource.values, j['source'], JournalSource.agent),
      );

  Map<String, dynamic> toJson() => {
        'time': time.millisecondsSinceEpoch,
        'op': op,
        'target': target,
        'before': before,
        'after': after,
        'ok': ok,
        'source': source.name,
      };
}

// ── restore ──

enum RestoreTarget { undoBoretube, stock }
