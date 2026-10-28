import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_client.dart';
import '../../providers/agent_providers.dart';
import '../../providers/now_playing.dart';
import '../../providers/tv_providers.dart';
import '../../providers/ui_providers.dart';
import '../../ui/components.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/learn.dart';
import '../../ui/tokens.dart';
import '../home/home_logic.dart';
import '../tab_header.dart';
import 'day_ribbon.dart';
import 'presets.dart';
import 'tv_says_no.dart';

/// Shown as `updatedBy` on the TV ("by Parent phone at 19:30").
final rulesAuthorProvider = Provider<String>((ref) => 'Parent phone');

/// Rule-editor clock; tests override it.
final rulesClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

const kStockYouTube = 'com.google.android.youtube.tv';

/// Sunday first, the way most family calendars read.
const _dayOrder = [7, 1, 2, 3, 4, 5, 6];
const _dayLetter = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};
const _dayWord = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// Cool-down minutes offered in the Video hopping sheet.
const _coolMin = 5;
const _coolMax = 30;
const _coolStep = 5;

/// What Video hopping is set to, in a word or two.
String hoppingLabel(ShortsRule s) => switch (s.mode) {
      ShortsMode.off => 'Off',
      ShortsMode.block => 'Gentle nudge',
      ShortsMode.cooldown => 'Cool-down',
      ShortsMode.budget => '${s.perDay} a day',
      ShortsMode.report => 'Just tell me',
    };

/// Edits the rules document as a draft; Save sends it with its version
/// and handles "the TV has newer rules" (409) with a friendly sheet.
///
/// The screen is a day ribbon (the hero), the preset chips, and one plain
/// row per rule. Each row opens a focused sheet with that rule's controls;
/// the sheets edit the same draft, and the ink save bar appears once
/// anything changed.
class RulesEditor extends ConsumerStatefulWidget {
  final AgentRules initial;
  const RulesEditor({super.key, required this.initial});

  @override
  ConsumerState<RulesEditor> createState() => _RulesEditorState();
}

class _RulesEditorState extends ConsumerState<RulesEditor> {
  late AgentRules _base = widget.initial;
  late AgentRules _draft = widget.initial;
  bool _saving = false;

  /// Ticks on every state change so open sheets rebuild with the draft.
  final _changes = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _changes.value++;
  }

  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(rulesClockProvider)();

  bool _focusing = false;

  /// Opens a rule's sheet once (a nudge asked for it), once this tab is
  /// on screen.
  void _focus(String id) {
    _focusing = false;
    ref.read(routinesFocusProvider.notifier).state = null;
    if (id == 'shorts' && mounted) _openShorts();
  }

  bool get _dirty => jsonEncode(_draft.toJson()) != jsonEncode(_base.toJson());

  void _edit(AgentRules Function(AgentRules r) f) =>
      setState(() => _draft = f(_draft));

  AgentRules _stamped(AgentRules r, {int? version}) {
    final now = _now();
    return r.copyWith(
      version: version,
      updatedBy: ref.read(rulesAuthorProvider),
      updatedAt: now.toUtc().toIso8601String(),
      overrides: [
        for (final o in r.overrides)
          if (o.activeAt(now)) o,
      ],
    );
  }

  Future<void> _save({AgentRules? draft, int? overwriteVersion}) async {
    final c = ref.read(agentClientProvider);
    if (c == null || _saving) return;
    final toSend = _stamped(draft ?? _draft, version: overwriteVersion);
    setState(() => _saving = true);
    try {
      final saved = await c.putRules(toSend);
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _base = saved;
        _draft = saved;
      });
      showStatusSnack(context, 'Saved to the TV ✓');
      unawaited(ref.read(agentStatusProvider.notifier).refresh());
    } on AgentConflict catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _conflict(e.current, draft ?? _draft);
    } on AgentException catch (e) {
      if (mounted) {
        showStatusSnack(
          context,
          'Not saved: ${e.message}. Your changes are still here.',
          ok: false,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _conflict(AgentRules current, AgentRules mine) async {
    final choice = await showBtSheet<String>(
      context,
      builder: (_) => ConflictSheet(theirs: current, mine: mine),
    );
    if (!mounted) return;
    if (choice == 'theirs') {
      setState(() {
        _base = current;
        _draft = current;
      });
      showStatusSnack(context, 'Showing what\'s on the TV');
    } else if (choice == 'mine') {
      await _save(draft: mine, overwriteVersion: current.version);
    }
  }

  /// Adds a temporary override and saves at once.
  Future<void> _override(RuleOverride o) async {
    final next = _draft.copyWith(
      overrides: [
        for (final x in _draft.overrides)
          if (!(x.kind == o.kind && x.pkg == o.pkg)) x,
        o,
      ],
    );
    setState(() => _draft = next);
    await _save(draft: next);
  }

  Future<void> _removeOverride(RuleOverride o) async {
    final next = _draft.copyWith(
      overrides: [
        for (final x in _draft.overrides)
          if (!identical(x, o)) x,
      ],
    );
    setState(() => _draft = next);
    await _save(draft: next);
  }

  Future<void> _pickApps() async {
    final picked = await showBtSheet<List<String>>(
      context,
      builder: (_) => AppPickerSheet(
        selected: _draft.allowedApps.packages,
        blocklist: _draft.allowedApps.mode == AppsMode.blocklist,
      ),
    );
    if (picked != null) {
      _edit(
        (r) => r.copyWith(
          allowedApps: r.allowedApps.copyWith(packages: picked),
        ),
      );
    }
  }

  /// Shows what [p] sets; on confirm fills the draft and saves it.
  Future<void> _choosePreset(RulePreset p) async {
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final ok = await showBtSheet<bool>(
      context,
      builder: (_) => PresetSheet(preset: p, h24: h24),
    );
    if (ok != true || !mounted) return;
    final next = applyPreset(_draft, p);
    setState(() => _draft = next);
    await _save(draft: next);
  }

  /// One rule's focused editor. The sheet rebuilds with every draft change.
  Future<void> _open(
    String id,
    String title,
    List<Widget> Function(BuildContext c, AgentRules r) body, {
    Widget Function(BuildContext c)? lead,
  }) =>
      showBtSheet<void>(
        context,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _changes,
          builder: (c, tick, child) => SheetScaffold(
            key: Key('rules-sheet-$id'),
            title: title,
            lead: lead?.call(c),
            children: [
              ...body(c, _draft),
              const SizedBox(height: Gap.related),
              PrimaryButton(
                key: const Key('rules-sheet-done'),
                label: 'Done',
                kind: ButtonKind.ink,
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // A nudge can ask for a rule while this tab is still off stage (the
    // shell keeps tabs alive); open its sheet once the tab shows.
    final focus = ref.watch(routinesFocusProvider);
    if (focus != null && !_focusing && Visibility.of(context)) {
      _focusing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus(focus);
      });
    }
    final r = _draft;
    final active = detectPreset(r);
    final text = Theme.of(context).textTheme;
    final when = _base.updatedAtTime;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('rules-list'),
            padding: const EdgeInsets.only(bottom: Gap.section),
            children: [
              TabHeader(
                title: 'Routines',
                status: _StatusLine(dirty: _dirty),
              ),
              const SizedBox(height: Gap.related),
              StaggerIn(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
                  child: _DayHero(rules: r, now: _now()),
                ),
              ),
              const SizedBox(height: Gap.related),
              StaggerIn(
                index: 1,
                child: _PresetChips(
                  active: active,
                  onPick: _saving ? null : _choosePreset,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isBlankRoutine(r))
                      _Templates(onPick: _saving ? null : _choosePreset),
                    const SizedBox(height: Gap.f13),
                    StaggerIn(index: 2, child: _rules(context, r)),
                    if (_base.updatedBy.isNotEmpty) ...[
                      const SizedBox(height: Gap.related),
                      Text(
                        'Last changed by ${_base.updatedBy}'
                        '${when == null ? '' : ' · ${relativeTime(when)}'}',
                        key: const Key('rules-updated'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _SaveBar(
          visible: _dirty,
          saving: _saving,
          onDiscard: () => setState(() => _draft = _base),
          onSave: _save,
        ),
      ],
    );
  }

  // ── the rows ──

  Widget _rules(BuildContext context, AgentRules r) {
    final now = _now();
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final t = r.tvTime;
    final a = r.allowedApps;
    final v = r.volumeLimit;
    final today = ref.watch(
      agentStatusProvider.select((l) => l.up ? l.status!.shorts : null),
    );
    final activeOverrides = [
      for (final o in r.overrides)
        if (o.activeAt(now)) o,
    ];
    return RowList(
      children: [
        ListRow(
          key: const Key('rules-tv-time'),
          icon: Icons.bedtime_rounded,
          title: 'Bedtime and quiet hours',
          subtitle: t.schedule.isEmpty
              ? 'None yet'
              : [
                  for (final w in t.schedule)
                    '${daysLabel(w.days)} ${hhmmLabel(w.from, h24: h24)}',
                ].join(' · '),
          value: t.schedule.isEmpty ? 'Off' : null,
          onTap: _openBedtime,
        ),
        ListRow(
          key: const Key('rules-daily'),
          icon: Icons.timer_rounded,
          title: 'Daily TV time',
          value:
              t.dailyLimitMin == 0 ? 'No limit' : minutesLabel(t.dailyLimitMin),
          onTap: _openDaily,
        ),
        ListRow(
          key: const Key('rules-apps'),
          icon: Icons.apps_rounded,
          title: 'Allowed apps',
          subtitle: a.mode == AppsMode.off || a.packages.isEmpty
              ? null
              : [for (final p in a.packages) appLabel(p)].join(', '),
          value: switch (a.mode) {
            AppsMode.off => 'Any',
            AppsMode.allowlist => 'Only these',
            AppsMode.blocklist => 'Block these',
          },
          onTap: _openApps,
        ),
        ListRow(
          key: const Key('rules-shorts'),
          icon: Icons.swipe_vertical_rounded,
          title: 'Video hopping',
          subtitle: today == null || today.todayCount == 0
              ? null
              : '${today.todayCount} today',
          value: hoppingLabel(r.shortsRule),
          onTap: _openShorts,
        ),
        ListRow(
          key: const Key('rules-sound'),
          icon: Icons.volume_down_rounded,
          title: 'Volume',
          value: v.enabled ? 'Up to ${v.maxPercent}%' : 'Any',
          onTap: _openVolume,
        ),
        SwitchLine(
          key: const Key('rules-always-mute'),
          leading: Icon(
            Icons.volume_off_rounded,
            size: Sizes.icon,
            color: context.bt.inkSoft,
          ),
          title: 'Keep it silent',
          subtitle: r.alwaysMute ? 'Stays muted all the time' : null,
          value: r.alwaysMute,
          onChanged: (on) => _edit((r) => r.copyWith(alwaysMute: on)),
        ),
        ListRow(
          key: const Key('rules-style'),
          icon: Icons.chat_bubble_rounded,
          title: 'How the TV says no',
          value: r.style == RuleStyle.explicit ? 'Friendly' : 'Quietly',
          onTap: _openStyle,
        ),
        ListRow(
          key: const Key('rules-overrides'),
          icon: Icons.event_rounded,
          title: 'Tonight only',
          value: activeOverrides.isEmpty
              ? 'Nothing on'
              : '${activeOverrides.length} on now',
          onTap: _openTonight,
        ),
      ],
    );
  }

  // ── the sheets ──

  Future<void> _openBedtime() => _open(
        'tv-time',
        'Bedtime and quiet hours',
        lead: (_) => const Text(
          'The TV says no in these windows, even when nobody is home.',
        ),
        (c, r) {
          final t = r.tvTime;
          void setRows(List<ScheduleRow> rows) => _edit(
                (d) => d.copyWith(tvTime: d.tvTime.copyWith(schedule: rows)),
              );
          return [
            if (t.schedule.isNotEmpty) ...[
              RowList(
                edges: true,
                children: [
                  for (var i = 0; i < t.schedule.length; i++)
                    _WindowEditor(
                      key: Key('rules-schedule-$i'),
                      row: t.schedule[i],
                      onChanged: (row) => setRows([...t.schedule]..[i] = row),
                      onRemove: () => setRows([...t.schedule]..removeAt(i)),
                    ),
                ],
              ),
              const SizedBox(height: Gap.inside),
            ],
            DashedAdd(
              key: const Key('rules-add-schedule'),
              label: t.schedule.isEmpty ? 'Add a bedtime' : 'Add quiet hours',
              expand: true,
              onTap: () => setRows([
                ...t.schedule,
                ScheduleRow(
                  days:
                      t.schedule.isEmpty ? const [1, 2, 3, 4, 7] : const [5, 6],
                  from: t.schedule.isEmpty ? '21:00' : '22:30',
                  to: t.schedule.isEmpty ? '07:00' : '08:30',
                ),
              ]),
            ),
          ];
        },
      );

  Future<void> _openDaily() => _open(
        'daily',
        'Daily TV time',
        (c, r) {
          final text = Theme.of(c).textTheme;
          final bt = c.bt;
          final limit = r.tvTime.dailyLimitMin;
          final label = limit == 0 ? 'No limit' : minutesLabel(limit);
          return [
            Text(
              label,
              style: Fonts.bricolage(
                TypeSize.title,
                color: limit == 0 ? bt.muted : bt.ink,
                tabularFigures: true,
              ),
            ),
            Slider(
              key: const Key('rules-daily-slider'),
              value: limit.clamp(0, 300).toDouble(),
              max: 300,
              divisions: 20,
              label: label,
              semanticFormatterCallback: (x) =>
                  x == 0 ? 'No limit' : minutesLabel(x.round()),
              onChanged: (x) => _edit(
                (d) => d.copyWith(
                  tvTime: d.tvTime.copyWith(dailyLimitMin: x.round()),
                ),
              ),
            ),
            Text(
              limit == 0
                  ? 'Slide to set how much TV a day. Bedtime still applies.'
                  : 'Screen-on time on the TV\'s clock. Resets at midnight.',
              style: text.bodySmall,
            ),
          ];
        },
      );

  Future<void> _openApps() => _open(
        'apps',
        'Allowed apps',
        (c, r) {
          final text = Theme.of(c).textTheme;
          final a = r.allowedApps;
          void remove(String p) => _edit(
                (d) => d.copyWith(
                  allowedApps: d.allowedApps.copyWith(
                    packages: [
                      for (final x in d.allowedApps.packages)
                        if (x != p) x,
                    ],
                  ),
                ),
              );
          return [
            RadioList<AppsMode>(
              keyPrefix: 'rules-apps',
              options: const [
                RadioOption(
                  AppsMode.off,
                  'Any app',
                  detail: 'Every app can open.',
                ),
                RadioOption(
                  AppsMode.allowlist,
                  'Only these',
                  detail: 'Anything else closes and the TV goes Home.',
                ),
                RadioOption(
                  AppsMode.blocklist,
                  'Block these',
                  detail: 'These close as soon as they open.',
                ),
              ],
              value: a.mode,
              onChanged: (m) => _edit(
                (d) => d.copyWith(allowedApps: d.allowedApps.copyWith(mode: m)),
              ),
            ),
            AnimatedSize(
              duration: Motion.of(c, Motion.sheet),
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: a.mode == AppsMode.off
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: Gap.related),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (a.packages.isEmpty &&
                              a.mode == AppsMode.allowlist)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Gap.f13),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: Sizes.iconSmall,
                                    color: Tone.warn.color(c),
                                  ),
                                  const SizedBox(width: Gap.f8),
                                  Expanded(
                                    child: Text(
                                      'Nothing picked yet, so no app would '
                                      'open.',
                                      style: text.bodySmall!.copyWith(
                                        color: Tone.warn.color(c),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Wrap(
                            spacing: Gap.f8,
                            runSpacing: Gap.f8,
                            children: [
                              for (final p in a.packages)
                                AppPill(pkg: p, onRemove: () => remove(p)),
                              DashedAdd(
                                key: const Key('rules-pick-apps'),
                                label:
                                    a.packages.isEmpty ? 'Choose apps' : 'Add',
                                onTap: _pickApps,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ];
        },
      );

  Future<void> _openShorts() => _open(
        'shorts',
        'Video hopping',
        lead: (c) => Row(
          children: [
            const Expanded(
              child: Text('Quick videos, one after another.'),
            ),
            InfoDot(LearnTerm.shorts, color: c.bt.muted),
          ],
        ),
        _shortsBody,
      );

  List<Widget> _shortsBody(BuildContext c, AgentRules r) {
    final text = Theme.of(c).textTheme;
    final bt = c.bt;
    final rule = r.shortsRule;
    final mode = rule.mode;
    final perDay =
        rule.perDay.clamp(ShortsRule.minPerDay, ShortsRule.maxPerDay);
    final cool = rule.cooldownMin;
    final today = ref.read(agentStatusProvider).up
        ? ref.read(agentStatusProvider).status!.shorts
        : null;
    // Back to Off on a TV that never had the rule: leave it absent, so the
    // draft matches what's saved.
    void set(ShortsRule s) => _edit(
          (d) => s.mode == ShortsMode.off &&
                  _base.shorts == null &&
                  s.extra.isEmpty
              ? d.copyWith(clearShorts: true)
              : d.copyWith(shorts: s),
        );
    // "Allow a few" is no longer offered; it stays readable while the TV
    // has it.
    final budget =
        mode == ShortsMode.budget || _base.shortsRule.mode == ShortsMode.budget;
    final friendly = r.style == RuleStyle.explicit;
    final stops = mode == ShortsMode.block ||
        mode == ShortsMode.cooldown ||
        mode == ShortsMode.budget;
    Widget reveal(bool on, Widget child) => AnimatedSize(
          duration: Motion.of(c, Motion.sheet),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: on ? child : const SizedBox(width: double.infinity),
        );
    return [
      RadioList<ShortsMode>(
        keyPrefix: 'rules-shorts',
        options: [
          const RadioOption(
            ShortsMode.off,
            'Off',
            detail: 'Videos play as usual, still counted.',
          ),
          const RadioOption(
            ShortsMode.block,
            'Gentle nudge',
            detail: 'Closes the app with a friendly card.',
          ),
          RadioOption(
            ShortsMode.cooldown,
            'Cool-down',
            detail: 'Closes it, then video apps rest for $cool min.',
          ),
          if (budget)
            RadioOption(
              ShortsMode.budget,
              'Allow a few',
              detail: 'The first $perDay each day play, then the TV says no.',
            ),
          const RadioOption(
            ShortsMode.report,
            'Just tell me',
            detail: 'Nothing stops. You see how many, on Home.',
          ),
        ],
        value: mode,
        onChanged: (m) => set(
          rule.copyWith(
            mode: m,
            perDay: m == ShortsMode.budget ? perDay : null,
          ),
        ),
      ),
      reveal(
        mode == ShortsMode.cooldown,
        RowList(
          edges: true,
          children: [
            ListRow(
              title: 'Video apps rest for',
              trailing: CountStepper(
                key: const Key('rules-shorts-cool-min'),
                keyPrefix: 'rules-shorts-cool-min',
                value: cool,
                min: cool < _coolMin ? cool : _coolMin,
                max: cool > _coolMax ? cool : _coolMax,
                step: _coolStep,
                unit: 'min',
                onChanged: (n) => set(rule.copyWith(cooldownMin: n)),
              ),
            ),
          ],
        ),
      ),
      reveal(
        mode == ShortsMode.budget,
        RowList(
          edges: true,
          children: [
            ListRow(
              title: 'Shorts a day',
              trailing: CountStepper(
                key: const Key('rules-shorts-per-day'),
                keyPrefix: 'rules-shorts-per-day',
                value: perDay,
                min: ShortsRule.minPerDay,
                max: ShortsRule.maxPerDay,
                unit: '',
                onChanged: (n) => set(rule.copyWith(perDay: n)),
              ),
            ),
          ],
        ),
      ),
      reveal(
        stops,
        Padding(
          padding: const EdgeInsets.only(top: Gap.related),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.f34),
                child: TvSaysNoPreview(
                  key: const Key('rules-shorts-preview'),
                  style: r.style,
                  headline: switch (mode) {
                    ShortsMode.cooldown => 'Time for a video break.',
                    ShortsMode.budget => 'That\'s all the Shorts for today.',
                    _ => 'That\'s a lot of quick videos.',
                  },
                  message: mode == ShortsMode.cooldown
                      ? 'Video apps are back in $cool min.'
                      : 'Pick a full video instead.',
                ),
              ),
              const SizedBox(height: Gap.f8),
              Text(
                friendly
                    ? 'What the TV shows when it steps in.'
                    : 'Quiet style: the app just closes, no card.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
      if (today != null &&
          (today.todayCount > 0 || today.lastDetectedAt != null)) ...[
        const SizedBox(height: Gap.related),
        Row(
          key: const Key('rules-shorts-today'),
          children: [
            Icon(Icons.today_rounded, size: Sizes.iconSmall, color: bt.muted),
            const SizedBox(width: Gap.f8),
            Expanded(
              child: Text(
                _shortsToday(c, today),
                style: text.labelMedium!.copyWith(
                  color: bt.inkSoft,
                  fontFeatures: Fonts.tabular,
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  /// "Today: 7 Shorts · last at 6:42 pm".
  String _shortsToday(BuildContext context, AgentShorts s) {
    final n = s.todayCount;
    final last = s.lastDetectedAt;
    final sameDay = last != null && DateUtils.isSameDay(last.toLocal(), _now());
    return [
      'Today: ${n == 0 ? 'no Shorts' : n == 1 ? '1 Short' : '$n Shorts'}',
      if (s.active)
        'on now'
      else if (n > 0 && sameDay)
        'last at ${friendlyTime(context, last.toLocal())}',
    ].join(' · ');
  }

  Future<void> _openVolume() => _open(
        'sound',
        'Volume',
        (c, r) {
          final v = r.volumeLimit;
          final bt = c.bt;
          return [
            RowList(
              edges: true,
              children: [
                SwitchLine(
                  key: const Key('rules-volume-limit'),
                  title: 'Volume limit',
                  subtitle: v.enabled
                      ? 'Past ${v.maxPercent}% it snaps back'
                      : 'Any volume',
                  value: v.enabled,
                  onChanged: (on) => _edit(
                    (d) => d.copyWith(
                      volumeLimit: d.volumeLimit.copyWith(enabled: on),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: Motion.of(c, Motion.sheet),
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: !v.enabled
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: Gap.f13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              key: const Key('rules-volume-slider'),
                              value: v.maxPercent.clamp(5, 100).toDouble(),
                              min: 5,
                              max: 100,
                              divisions: 19,
                              label: '${v.maxPercent}%',
                              onChanged: (x) => _edit(
                                (d) => d.copyWith(
                                  volumeLimit: d.volumeLimit
                                      .copyWith(maxPercent: x.round()),
                                ),
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(minWidth: Sizes.row),
                            child: Text(
                              '${v.maxPercent}%',
                              textAlign: TextAlign.right,
                              style: Fonts.bricolage(
                                TypeSize.headline,
                                color: bt.ink,
                                tabularFigures: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ];
        },
      );

  Future<void> _openStyle() => _open(
        'style',
        'How the TV says no',
        (c, r) {
          final bed = nextBedtime(r.tvTime.schedule, _now());
          return [
            RadioList<RuleStyle>(
              keyPrefix: 'rules-style',
              options: const [
                RadioOption(
                  RuleStyle.sneaky,
                  'Quietly',
                  detail: 'The app closes, as if the show ended.',
                ),
                RadioOption(
                  RuleStyle.explicit,
                  'Friendly message',
                  detail: 'Tubby says TV time is over, and when it\'s back.',
                ),
              ],
              value: r.style,
              onChanged: (s) => _edit((d) => d.copyWith(style: s)),
            ),
            const SizedBox(height: Gap.related),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.f34),
              child: TvSaysNoPreview(
                style: r.style,
                backAt: bed == null ? null : friendlyTime(c, bed.end),
              ),
            ),
          ];
        },
      );

  Future<void> _openTonight() => _open(
        'overrides',
        'Tonight only',
        lead: (_) => const Text(
          'These go to the TV right away and end by themselves.',
        ),
        (c, r) {
          final bt = c.bt;
          final now = _now();
          final active = [
            for (final o in r.overrides)
              if (o.activeAt(now)) o,
          ];
          final tonight = DateTime(now.year, now.month, now.day, 23, 59);
          final ytAllowed = active.any(
            (o) => o.kind == OverrideKind.allowApp && o.pkg == kStockYouTube,
          );
          final quiet = active.any((o) => o.kind == OverrideKind.muteUntil);
          return [
            RowList(
              edges: true,
              children: [
                ListRow(
                  key: const Key('rules-allow-youtube'),
                  icon: Icons.smart_display_rounded,
                  iconColor: ytAllowed ? bt.mintInk : null,
                  title: 'Allow YouTube tonight',
                  subtitle: 'Until midnight',
                  value: ytAllowed ? 'On' : null,
                  valueColor: bt.mintInk,
                  chevron: false,
                  onTap: _saving
                      ? null
                      : () => _override(
                            RuleOverride(
                              kind: OverrideKind.allowApp,
                              pkg: kStockYouTube,
                              until: tonight.toUtc().toIso8601String(),
                            ),
                          ),
                ),
                ListRow(
                  key: const Key('rules-mute-30'),
                  icon: Icons.volume_off_rounded,
                  iconColor: quiet ? bt.mintInk : null,
                  title: 'Quiet for 30 min',
                  subtitle: 'The TV stays muted till then',
                  value: quiet ? 'On' : null,
                  valueColor: bt.mintInk,
                  chevron: false,
                  onTap: _saving
                      ? null
                      : () => _override(
                            RuleOverride(
                              kind: OverrideKind.muteUntil,
                              until: now
                                  .add(const Duration(minutes: 30))
                                  .toUtc()
                                  .toIso8601String(),
                            ),
                          ),
                ),
              ],
            ),
            if (active.isNotEmpty) ...[
              const GroupHeading('On now'),
              RowList(
                children: [
                  for (final o in active)
                    ListRow(
                      icon: switch (o.kind) {
                        OverrideKind.allowApp => Icons.check_circle_rounded,
                        OverrideKind.muteUntil => Icons.volume_off_rounded,
                        OverrideKind.breakUntil => Icons.pause_circle_rounded,
                      },
                      iconColor: bt.mintInk,
                      title: '${switch (o.kind) {
                        OverrideKind.allowApp =>
                          '${appLabel(o.pkg ?? '')} allowed',
                        OverrideKind.muteUntil => 'Quiet',
                        OverrideKind.breakUntil => 'Paused',
                      }} · until '
                          '${friendlyTime(c, o.untilTime!.toLocal())}',
                      trailing: TextButton(
                        onPressed: _saving ? null : () => _removeOverride(o),
                        child: const Text('End now'),
                      ),
                    ),
                ],
              ),
            ],
          ];
        },
      );
}

// ── pieces ──

/// The one line under the title: saved, or not yet.
class _StatusLine extends StatelessWidget {
  final bool dirty;

  const _StatusLine({required this.dirty});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final c = dirty ? bt.sunInk : bt.mintInk;
    return AnimatedSwitcher(
      key: const Key('rules-header'),
      duration: Motion.of(context, Motion.flip),
      child: Row(
        key: ValueKey(dirty),
        children: [
          Icon(
            dirty ? Icons.edit_rounded : Icons.shield_rounded,
            size: Sizes.iconSmall,
            color: c,
          ),
          const SizedBox(width: Gap.f4),
          Flexible(
            child: Text(
              dirty
                  ? 'The TV runs the old rules until you save'
                  : 'Saved to the TV · runs even when you\'re away',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium!.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero: today as a 24-hour ribbon, and the rules in one line.
class _DayHero extends StatelessWidget {
  final AgentRules rules;
  final DateTime now;

  const _DayHero({required this.rules, required this.now});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final schedule = rules.tvTime.schedule;
    final bed = nextBedtime(schedule, now);
    final sameDay = bed != null && DateUtils.isSameDay(bed.start, now);
    final line = schedule.isEmpty
        ? 'No quiet hours yet'
        : bed != null && bed.now
            ? 'Quiet until ${friendlyTime(context, bed.end)}'
            : sameDay
                ? 'Quiet from ${friendlyTime(context, bed.start)}'
                : 'No quiet hours left today';
    final limit = rules.tvTime.dailyLimitMin;
    final v = rules.volumeLimit;
    final summary = [
      limit == 0 ? 'No daily limit' : 'TV time ${minutesLabel(limit)}',
      if (v.enabled) 'Volume ≤ ${v.maxPercent}%',
      if (rules.alwaysMute) 'Muted',
    ].join(' · ');
    return Surface(
      key: const Key('rules-hero'),
      radius: Radii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Today', style: text.titleMedium),
              const SizedBox(width: Gap.inside),
              Expanded(
                child: Text(
                  line,
                  key: const Key('rules-hero-line'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(
                    color: bt.sunInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.f8),
          DayRibbon(
            schedule: schedule,
            now: now,
            semanticLabel: 'Today. $line.',
          ),
          Text(
            summary,
            key: const Key('rules-summary'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall!.copyWith(fontFeatures: Fonts.tabular),
          ),
        ],
      ),
    );
  }
}

/// Presets as one compact chip row, scrolling sideways past the gutter;
/// the selected chip is kept in view.
class _PresetChips extends StatefulWidget {
  final RulePreset? active;
  final ValueChanged<RulePreset>? onPick;

  const _PresetChips({required this.active, required this.onPick});

  @override
  State<_PresetChips> createState() => _PresetChipsState();
}

class _PresetChipsState extends State<_PresetChips> {
  final _selected = GlobalKey();
  bool _first = true;

  void _reveal() {
    final c = _selected.currentContext;
    if (c == null || !c.mounted) return;
    final ro = c.findRenderObject();
    if (ro == null) return;
    // Only the chip row scrolls; the page stays where it is.
    Scrollable.of(c).position.ensureVisible(
          ro,
          alignment: Phi.minor,
          duration: _first ? Duration.zero : Motion.of(c, Motion.sheet),
          curve: Motion.enter,
        );
    _first = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(_PresetChips old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final onPick = widget.onPick;
    Widget keep(bool on, Widget child) =>
        on ? KeyedSubtree(key: _selected, child: child) : child;
    final chips = [
      for (final p in RulePreset.values)
        keep(
          active == p,
          BtChip(
            key: Key('preset-${p.name}'),
            label: p.label,
            selected: active == p,
            onTap: active == p || onPick == null ? null : () => onPick(p),
          ),
        ),
      keep(
        active == null,
        Tooltip(
          message: 'Change any rule and it becomes your own routine',
          child: BtChip(
            key: const Key('preset-custom'),
            label: 'Custom',
            icon: Icons.tune_rounded,
            selected: active == null,
          ),
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.f8),
            chips[i],
          ],
        ],
      ),
    );
  }
}

/// The empty state that teaches: three starting points, as rows.
class _Templates extends StatelessWidget {
  final ValueChanged<RulePreset>? onPick;
  const _Templates({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('rules-templates'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupHeading('Pick a starting point', first: true),
        RowList(
          children: [
            for (final p in RulePreset.values)
              ListRow(
                key: Key('template-${p.name}'),
                title: p.label,
                subtitle: p.blurb,
                onTap: onPick == null ? null : () => onPick!(p),
              ),
          ],
        ),
        const GroupHeading('Or set each rule'),
      ],
    );
  }
}

/// One quiet-hours window: the times big, the days as dots.
class _WindowEditor extends StatelessWidget {
  final ScheduleRow row;
  final ValueChanged<ScheduleRow> onChanged;
  final VoidCallback onRemove;

  const _WindowEditor({
    super.key,
    required this.row,
    required this.onChanged,
    required this.onRemove,
  });

  static TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(p.first)?.clamp(0, 23) ?? 0,
      minute: p.length > 1 ? int.tryParse(p[1])?.clamp(0, 59) ?? 0 : 0,
    );
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(BuildContext context, bool from) async {
    final t = await showTimePicker(
      context: context,
      helpText: from ? 'TV off from' : 'TV back at',
      initialTime: _parse(from ? row.from : row.to),
    );
    if (t == null) return;
    onChanged(from ? row.copyWith(from: _fmt(t)) : row.copyWith(to: _fmt(t)));
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    Widget time(String v, bool from) => Semantics(
          button: true,
          label: '${from ? 'From' : 'Until'} ${hhmmLabel(v, h24: h24)}',
          excludeSemantics: true,
          child: InkWell(
            key: Key(from ? 'schedule-from' : 'schedule-to'),
            borderRadius: Radii.chip,
            onTap: () => _pick(context, from),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.f4,
                vertical: Gap.f8,
              ),
              child: Text(
                hhmmLabel(v, h24: h24),
                softWrap: false,
                style: Fonts.bricolage(
                  TypeSize.headline,
                  color: bt.ink,
                  tabularFigures: true,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: bt.borderStrong,
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.f8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    time(row.from, true),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: Sizes.iconSmall,
                      color: bt.muted,
                    ),
                    time(row.to, false),
                    if (row.crossesMidnight)
                      Padding(
                        padding: const EdgeInsets.only(left: Gap.f4),
                        child: Text('next day', style: text.bodySmall),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('schedule-remove'),
                tooltip: 'Remove these quiet hours',
                onPressed: onRemove,
                icon: Icon(
                  Icons.close_rounded,
                  size: Sizes.icon,
                  color: bt.muted,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in _dayOrder)
                Expanded(
                  child: _DayDot(
                    key: Key('day-$d'),
                    letter: _dayLetter[d]!,
                    word: _dayWord[d]!,
                    on: row.days.contains(d),
                    onTap: () {
                      final days = {...row.days};
                      days.contains(d) ? days.remove(d) : days.add(d);
                      onChanged(row.copyWith(days: days.toList()..sort()));
                    },
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: Gap.f4),
            child: Text(daysLabel(row.days), style: text.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String letter;
  final String word;
  final bool on;
  final VoidCallback onTap;

  const _DayDot({
    super.key,
    required this.letter,
    required this.word,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      selected: on,
      label: word,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: Sizes.touch / 2,
        child: SizedBox(
          height: Sizes.touch,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.flip),
              curve: Motion.enter,
              width: Sizes.chip,
              height: Sizes.chip,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? bt.sun : bt.wash,
              ),
              child: Text(
                letter,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: on ? const Color(0xFF3D2700) : bt.muted,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The slim ink save bar: only there when something changed.
class _SaveBar extends StatelessWidget {
  final bool visible;
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  const _SaveBar({
    required this.visible,
    required this.saving,
    required this.onDiscard,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.sheet),
      reverseDuration: Motion.of(context, Motion.flip),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: child),
      ),
      child: !visible
          ? const SizedBox(key: ValueKey('saved'), width: double.infinity)
          : Padding(
              key: const ValueKey('dirty'),
              padding: const EdgeInsets.fromLTRB(
                Gap.gutter,
                Gap.f8,
                Gap.gutter,
                Gap.f13,
              ),
              child: Container(
                key: const Key('rules-save-bar'),
                constraints: const BoxConstraints(minHeight: Sizes.row),
                padding: const EdgeInsets.only(
                  left: Gap.related,
                  right: (Sizes.row - Sizes.control) / 2,
                ),
                decoration: BoxDecoration(
                  color: bt.inkFill,
                  borderRadius: Radii.control,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Not saved yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall!.copyWith(color: bt.onInkFill),
                      ),
                    ),
                    TextButton(
                      key: const Key('rules-discard'),
                      style: TextButton.styleFrom(
                        foregroundColor: bt.onInkFill.withValues(alpha: 0.8),
                      ),
                      onPressed: saving ? null : onDiscard,
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: Gap.f4),
                    PrimaryButton(
                      key: const Key('rules-save'),
                      label: saving ? 'Saving…' : 'Save',
                      height: Sizes.control,
                      onPressed: saving ? null : onSave,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// "School night: here's what it sets", then Use or Not now.
class PresetSheet extends StatelessWidget {
  final RulePreset preset;
  final bool h24;

  const PresetSheet({super.key, required this.preset, this.h24 = false});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return SheetScaffold(
      key: const Key('preset-sheet'),
      title: preset.label,
      lead: Text(preset.blurb),
      children: [
        for (final l in shapeSummary(preset.shape, h24: h24))
          CheckLine(l, done: true),
        const SizedBox(height: Gap.f13),
        Row(
          children: [
            Icon(Icons.apps_rounded, size: Sizes.iconSmall, color: bt.muted),
            const SizedBox(width: Gap.f8),
            Expanded(
              child: Text(
                'Allowed apps, video hopping and Tonight only stay as they '
                'are.',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.related),
        PrimaryButton(
          key: const Key('preset-confirm'),
          label: 'Use ${preset.label}',
          onPressed: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: Gap.f8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep my settings'),
        ),
      ],
    );
  }
}

/// Someone else changed the rules while you edited: keep theirs or mine.
class ConflictSheet extends StatelessWidget {
  final AgentRules theirs;
  final AgentRules mine;

  const ConflictSheet({super.key, required this.theirs, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final when = theirs.updatedAtTime;
    final by = theirs.updatedBy.isEmpty ? 'Another phone' : theirs.updatedBy;
    final diff = rulesDiff(theirs, mine);
    return SheetScaffold(
      key: const Key('rules-conflict'),
      title: 'The TV has newer rules',
      lead: Text(
        '$by changed them'
        '${when == null ? '' : ' at ${friendlyTime(context, when.toLocal())}'}'
        ' while you were editing. Which should the TV keep?',
      ),
      children: [
        if (diff.isNotEmpty) ...[
          Text('What\'s different', style: text.titleSmall),
          const SizedBox(height: Gap.f8),
          Wrap(
            spacing: Gap.f8,
            runSpacing: Gap.f8,
            children: [
              for (final d in diff) BtBadge(d, tone: Tone.warn),
            ],
          ),
          const SizedBox(height: Gap.related),
        ],
        RowList(
          edges: true,
          children: [
            ListRow(
              key: const Key('rules-reload'),
              icon: Icons.tv_rounded,
              title: 'Keep theirs',
              subtitle: 'What\'s on the TV now. Your edits go.',
              onTap: () => Navigator.pop(context, 'theirs'),
            ),
            ListRow(
              key: const Key('rules-overwrite'),
              icon: Icons.phone_android_rounded,
              title: 'Send mine',
              subtitle: 'Your edits replace theirs.',
              onTap: () => Navigator.pop(context, 'mine'),
            ),
          ],
        ),
        const SizedBox(height: Gap.related),
        Text(
          'The TV keeps a routine running either way.',
          textAlign: TextAlign.center,
          style: text.bodySmall!.copyWith(color: bt.muted),
        ),
      ],
    );
  }
}

/// An app as a removable pill: its tile, its name, ×.
class AppPill extends StatelessWidget {
  final String pkg;
  final VoidCallback? onRemove;

  const AppPill({super.key, required this.pkg, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final name = appLabel(pkg);
    return Container(
      key: Key('app-pill-$pkg'),
      constraints: const BoxConstraints(minHeight: Sizes.control),
      padding: const EdgeInsets.only(left: Gap.f8),
      decoration: BoxDecoration(color: bt.wash, borderRadius: Radii.control),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(pkg: pkg, size: Sizes.iconControl),
          const SizedBox(width: Gap.f8),
          Text(name, style: text.labelMedium!.copyWith(color: bt.ink)),
          if (onRemove != null)
            Semantics(
              button: true,
              label: 'Remove $name',
              excludeSemantics: true,
              child: InkResponse(
                radius: Sizes.touch / 2,
                onTap: onRemove,
                child: SizedBox(
                  width: Sizes.control,
                  height: Sizes.control,
                  child: Icon(
                    Icons.close_rounded,
                    size: Sizes.iconSmall,
                    color: bt.muted,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: Gap.f13),
        ],
      ),
    );
  }
}

/// A coloured letter tile for an app (no icon API over ADB).
class AppAvatar extends StatelessWidget {
  final String pkg;
  final double size;

  const AppAvatar({super.key, required this.pkg, this.size = Sizes.tile});

  static const _known = {
    'org.smarttube.stable': Color(0xFFFF3D2E),
    'org.smarttube.beta': Color(0xFFFF3D2E),
    'com.teamsmart.videomanager.tv': Color(0xFFFF3D2E),
    'com.google.android.youtube.tv': Color(0xFFFF0033),
    'com.google.android.youtube.tvkids': Color(0xFFE62117),
    'com.netflix.ninja': Color(0xFF141414),
    'com.amazon.amazonvideo.livingroom': Color(0xFF1A98FF),
    'com.disney.disneyplus': Color(0xFF113CCF),
    'com.spotify.tv.android': Color(0xFF1DB954),
  };

  static const _tones = [
    Color(0xFFE5735A),
    Color(0xFF3A8DFF),
    Color(0xFF1FBF8F),
    Color(0xFFC98200),
    Color(0xFF8C7CFF),
    Color(0xFFF2A65A),
  ];

  @override
  Widget build(BuildContext context) {
    final label = appLabel(pkg);
    final known = _known[pkg];
    final c = known ??
        _tones[pkg.codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: known ?? c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        label.isEmpty ? '?' : label[0].toUpperCase(),
        style: Fonts.bricolage(
          size * 0.46,
          color: known != null ? Colors.white : c,
          height: TypeSize.tightLeading,
        ),
      ),
    );
  }
}

/// Picks TV apps (from `TvOps.listApps`) for the allow or block list.
class AppPickerSheet extends ConsumerStatefulWidget {
  final List<String> selected;
  final bool blocklist;

  const AppPickerSheet({
    super.key,
    required this.selected,
    this.blocklist = false,
  });

  @override
  ConsumerState<AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends ConsumerState<AppPickerSheet> {
  late final Set<String> _picked = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final apps = ref.watch(appsProvider);
    final launcher =
        ref.watch(tvOpsProvider).valueOrNull?.profile.launcher?.pkg;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.gutter,
                0,
                Gap.gutter,
                Gap.f13,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.blocklist ? 'Apps to block' : 'Apps that can open',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: Gap.f13),
                  TextField(
                    key: const Key('pick-search'),
                    onChanged: (v) => setState(() => _q = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Find an app',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: apps.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Gap.f13),
                  child: SkeletonCard(rows: 5),
                ),
                error: (e, _) => const EmptyState(
                  icon: Icons.apps_outage_rounded,
                  title: 'Couldn\'t list the TV\'s apps',
                  message: 'Check the TV is on, then try again.',
                ),
                data: (list) {
                  final all = [
                    for (final a in list)
                      if (a.launchable && a.pkg != launcher) a.pkg,
                    for (final p in widget.selected)
                      if (!list.any((a) => a.pkg == p)) p,
                  ]..sort((a, b) => appLabel(a).compareTo(appLabel(b)));
                  final shown = [
                    for (final p in all)
                      if (_q.isEmpty || appLabel(p).toLowerCase().contains(_q))
                        p,
                  ];
                  if (all.isEmpty) {
                    return const EmptyState(
                      icon: Icons.apps_rounded,
                      title: 'No apps found',
                      message: 'Listing the TV\'s apps needs Home mode.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.gutter,
                    ),
                    children: [
                      RowList(
                        children: [
                          for (final p in shown)
                            _PickRow(
                              key: Key('pick-$p'),
                              pkg: p,
                              on: _picked.contains(p),
                              onTap: () => setState(
                                () => _picked.contains(p)
                                    ? _picked.remove(p)
                                    : _picked.add(p),
                              ),
                            ),
                        ],
                      ),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(Gap.f21),
                          child: Text(
                            'No app called "$_q" on this TV.',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium!.copyWith(color: bt.muted),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.gutter,
                Gap.f13,
                Gap.gutter,
                0,
              ),
              child: PrimaryButton(
                key: const Key('pick-done'),
                kind: ButtonKind.ink,
                label: _picked.isEmpty
                    ? 'Done'
                    : 'Use ${_picked.length} '
                        'app${_picked.length == 1 ? '' : 's'}',
                onPressed: () => Navigator.pop(context, _picked.toList()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final String pkg;
  final bool on;
  final VoidCallback onTap;

  const _PickRow({
    super.key,
    required this.pkg,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      checked: on,
      label: appLabel(pkg),
      excludeSemantics: true,
      button: true,
      child: ListRow(
        leading: AppAvatar(pkg: pkg, size: Sizes.iconControl),
        title: appLabel(pkg),
        chevron: false,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        trailing: AnimatedSwitcher(
          duration: Motion.of(context, Motion.flip),
          child: Icon(
            on ? Icons.check_circle_rounded : Icons.circle_outlined,
            key: ValueKey(on),
            size: Sizes.iconControl,
            color: on ? bt.mintInk : bt.faint,
          ),
        ),
      ),
    );
  }
}
