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
import '../../ui/tubby.dart';
import '../home/home_logic.dart';
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

/// Edits the rules document as a draft; Save sends it with its version
/// and handles "the TV has newer rules" (409) with a friendly sheet.
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
  final _shortsKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(rulesClockProvider)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = ref.read(routinesFocusProvider);
      if (f != null) _focus(f);
    });
  }

  /// Brings a card into view once (a nudge asked for it).
  void _focus(String id) {
    ref.read(routinesFocusProvider.notifier).state = null;
    final key = switch (id) {
      'shorts' => _shortsKey,
      _ => null,
    };
    if (key == null) return;
    // The list builds lazily: step down until the card exists, then
    // bring it into view.
    Future<void> reveal(int tries) async {
      if (!mounted) return;
      final c = key.currentContext;
      if (c != null && c.mounted) {
        await Scrollable.ensureVisible(
          c,
          duration: Motion.of(context, Motion.slow),
          curve: Motion.settle,
          alignment: 0.1,
        );
        return;
      }
      if (tries == 0 || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent) return;
      _scroll.jumpTo(
        (p.pixels + p.viewportDimension * 0.8).clamp(0, p.maxScrollExtent),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal(tries - 1));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => reveal(12));
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

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(routinesFocusProvider, (_, next) {
      if (next != null) _focus(next);
    });
    final r = _draft;
    final active = detectPreset(r);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('rules-list'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              0,
              Gap.page,
              Gap.xxl,
            ),
            children: [
              _StatusLine(rules: _base, dirty: _dirty),
              const SizedBox(height: Gap.md),
              _PresetChips(
                active: active,
                onPick: _saving ? null : _choosePreset,
              ),
              if (isBlankRoutine(r)) ...[
                const SizedBox(height: Gap.md),
                _Templates(onPick: _saving ? null : _choosePreset),
              ],
              const SizedBox(height: Gap.md),
              _bedtimeCard(context, r),
              const SizedBox(height: Gap.md),
              _dailyCard(context, r),
              const SizedBox(height: Gap.md),
              _appsCard(context, r),
              const SizedBox(height: Gap.md),
              _shortsCard(context, r),
              const SizedBox(height: Gap.md),
              _volumeCard(context, r),
              const SizedBox(height: Gap.md),
              _silentCard(context, r),
              const SizedBox(height: Gap.md),
              _styleCard(context, r),
              const SectionHeader('Tonight only'),
              _tonightCard(context, r),
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

  // ── cards ──

  Widget _bedtimeCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final t = r.tvTime;
    void setRows(List<ScheduleRow> rows) =>
        _edit((r) => r.copyWith(tvTime: t.copyWith(schedule: rows)));
    return SettingCard(
      key: const Key('rules-tv-time'),
      icon: Icons.bedtime_rounded,
      tone: Tone.warn,
      title: const Text('Bedtime and quiet hours'),
      children: [
        if (t.schedule.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Text(
              'No quiet hours yet. In these windows the TV says no, even '
              'when nobody is home to say it.',
              style: text.bodySmall,
            ),
          ),
        for (var i = 0; i < t.schedule.length; i++) ...[
          _WindowEditor(
            key: Key('rules-schedule-$i'),
            row: t.schedule[i],
            onChanged: (row) => setRows([...t.schedule]..[i] = row),
            onRemove: () => setRows([...t.schedule]..removeAt(i)),
          ),
          const SizedBox(height: Gap.sm),
        ],
        DashedAdd(
          key: const Key('rules-add-schedule'),
          label: t.schedule.isEmpty ? 'Add a bedtime' : 'Add quiet hours',
          expand: true,
          onTap: () => setRows([
            ...t.schedule,
            ScheduleRow(
              days: t.schedule.isEmpty ? const [1, 2, 3, 4, 7] : const [5, 6],
              from: t.schedule.isEmpty ? '21:00' : '22:30',
              to: t.schedule.isEmpty ? '07:00' : '08:30',
            ),
          ]),
        ),
      ],
    );
  }

  Widget _dailyCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final t = r.tvTime;
    final limit = t.dailyLimitMin;
    return SettingCard(
      key: const Key('rules-daily'),
      icon: Icons.timer_rounded,
      tone: Tone.info,
      title: const Text('Daily TV time'),
      value: limit == 0 ? 'No limit' : minutesLabel(limit),
      dim: limit == 0,
      children: [
        Slider(
          key: const Key('rules-daily-slider'),
          value: limit.clamp(0, 300).toDouble(),
          max: 300,
          divisions: 20,
          label: limit == 0 ? 'No limit' : minutesLabel(limit),
          semanticFormatterCallback: (x) =>
              x == 0 ? 'No limit' : minutesLabel(x.round()),
          onChanged: (x) => _edit(
            (r) => r.copyWith(tvTime: t.copyWith(dailyLimitMin: x.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: Text(
            limit == 0
                ? 'Slide to set how much TV a day. Bedtime still applies.'
                : 'Counts screen-on time only, on the TV\'s clock. Resets '
                    'at midnight.',
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _appsCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final a = r.allowedApps;
    void remove(String p) => _edit(
          (r) => r.copyWith(
            allowedApps: a.copyWith(
              packages: [
                for (final x in a.packages)
                  if (x != p) x,
              ],
            ),
          ),
        );
    return SettingCard(
      key: const Key('rules-apps'),
      icon: Icons.apps_rounded,
      tone: Tone.ok,
      title: const Text('Allowed apps'),
      children: [
        SegmentChoice<AppsMode>(
          keyPrefix: 'rules-apps',
          options: const [
            (AppsMode.off, 'Any'),
            (AppsMode.allowlist, 'Only these'),
            (AppsMode.blocklist, 'Block these'),
          ],
          value: a.mode,
          onChanged: (m) =>
              _edit((r) => r.copyWith(allowedApps: a.copyWith(mode: m))),
        ),
        const SizedBox(height: Gap.md),
        Text(
          switch (a.mode) {
            AppsMode.off => 'Every app can open.',
            AppsMode.allowlist => 'Only the apps below open. Anything else '
                'closes and the TV goes Home.',
            AppsMode.blocklist => 'The apps below close as soon as they '
                'open.',
          },
          style: text.bodySmall,
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.settle,
          alignment: Alignment.topCenter,
          child: a.mode == AppsMode.off
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Gap.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (a.packages.isEmpty && a.mode == AppsMode.allowlist)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Tone.warn.color(context),
                              ),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: Text(
                                  'Nothing picked yet, so no app would open.',
                                  style: text.bodySmall!.copyWith(
                                    color: Tone.warn.color(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.sm,
                        children: [
                          for (final p in a.packages)
                            AppPill(pkg: p, onRemove: () => remove(p)),
                          DashedAdd(
                            key: const Key('rules-pick-apps'),
                            label: a.packages.isEmpty ? 'Choose apps' : 'Add',
                            onTap: _pickApps,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _shortsCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final rule = r.shortsRule;
    final mode = rule.mode;
    final perDay =
        rule.perDay.clamp(ShortsRule.minPerDay, ShortsRule.maxPerDay);
    final today = ref.watch(
      agentStatusProvider.select((l) => l.up ? l.status!.shorts : null),
    );
    // Back to Off on a TV that never had a Shorts rule: leave it absent,
    // so the draft matches what's saved.
    void set(ShortsRule s) => _edit(
          (r) => s.mode == ShortsMode.off &&
                  _base.shorts == null &&
                  s.extra.isEmpty
              ? r.copyWith(clearShorts: true)
              : r.copyWith(shorts: s),
        );
    final friendly = r.style == RuleStyle.explicit;
    final stops = mode == ShortsMode.block || mode == ShortsMode.budget;
    return KeyedSubtree(
      key: _shortsKey,
      child: SettingCard(
        key: const Key('rules-shorts'),
        icon: Icons.swipe_vertical_rounded,
        tone: Tone.accent,
        title: const TermTitle('Shorts', LearnTerm.shorts),
        value: mode == ShortsMode.budget ? '$perDay a day' : null,
        dim: mode == ShortsMode.off,
        children: [
          SegmentChoice<ShortsMode>(
            keyPrefix: 'rules-shorts',
            columns: 2,
            options: const [
              (ShortsMode.off, 'Off'),
              (ShortsMode.block, 'Block'),
              (ShortsMode.budget, 'Allow a few'),
              (ShortsMode.report, 'Just tell me'),
            ],
            value: mode,
            onChanged: (m) => set(
              rule.copyWith(
                mode: m,
                perDay: m == ShortsMode.budget ? perDay : null,
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.settle,
            alignment: Alignment.topCenter,
            child: mode != ShortsMode.budget
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Gap.md),
                    child: CountStepper(
                      key: const Key('rules-shorts-per-day'),
                      keyPrefix: 'rules-shorts-per-day',
                      value: perDay,
                      min: ShortsRule.minPerDay,
                      max: ShortsRule.maxPerDay,
                      unit: perDay == 1 ? 'Short per day' : 'Shorts per day',
                      onChanged: (n) => set(rule.copyWith(perDay: n)),
                    ),
                  ),
          ),
          const SizedBox(height: Gap.md),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: Text(
              switch (mode) {
                ShortsMode.off => 'Shorts play as usual. The TV still counts '
                    'them, so you can see how many.',
                ShortsMode.block => 'After three quick Shorts in a row, the '
                    'app closes and the TV goes Home. Full videos keep '
                    'playing.',
                ShortsMode.budget => 'The first $perDay '
                    'Short${perDay == 1 ? '' : 's'} each day play. After '
                    'that, the TV says no until midnight.',
                ShortsMode.report => 'Nothing is stopped. You\'ll see how '
                    'many Shorts were watched, on Home and in History.',
              },
              key: ValueKey('shorts-help-$mode-$perDay'),
              style: text.bodySmall,
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.settle,
            alignment: Alignment.topCenter,
            child: !stops
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Gap.lg),
                    child: Column(
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Gap.lg),
                          child: TvSaysNoPreview(
                            key: const Key('rules-shorts-preview'),
                            style: r.style,
                            headline: mode == ShortsMode.block
                                ? 'Shorts aren\'t on in this house.'
                                : 'That\'s all the Shorts for today.',
                            message: 'Pick a full video instead.',
                          ),
                        ),
                        const SizedBox(height: Gap.sm),
                        Text(
                          friendly
                              ? 'What the TV shows when it stops them.'
                              : 'The app just closes. Pick "Friendly '
                                  'message" below and Tubby says why.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
          ),
          if (today != null &&
              (today.todayCount > 0 || today.lastDetectedAt != null)) ...[
            const SizedBox(height: Gap.md),
            Row(
              key: const Key('rules-shorts-today'),
              children: [
                Icon(Icons.today_rounded, size: 16, color: bt.muted),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    _shortsToday(context, today),
                    style: text.labelMedium!.copyWith(
                      color: bt.inkSoft,
                      fontFeatures: Fonts.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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

  Widget _volumeCard(BuildContext context, AgentRules r) {
    final v = r.volumeLimit;
    final bt = context.bt;
    return InfoCard(
      key: const Key('rules-sound'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchLine(
            key: const Key('rules-volume-limit'),
            leading: IconBadge(
              icon: Icons.volume_down_rounded,
              color: v.enabled ? Tone.info.color(context) : bt.muted,
              size: 40,
            ),
            title: 'Volume limit',
            subtitle: v.enabled
                ? 'Turning it up past ${v.maxPercent}% snaps back'
                : 'Any volume',
            value: v.enabled,
            onChanged: (on) => _edit(
              (r) => r.copyWith(volumeLimit: v.copyWith(enabled: on)),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.settle,
            alignment: Alignment.topCenter,
            child: !v.enabled
                ? const SizedBox(width: double.infinity)
                : Row(
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
                            (r) => r.copyWith(
                              volumeLimit: v.copyWith(maxPercent: x.round()),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${v.maxPercent}%',
                          textAlign: TextAlign.right,
                          style: Fonts.bricolage(
                            20,
                            color: bt.ink,
                            tabularFigures: true,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _silentCard(BuildContext context, AgentRules r) {
    final bt = context.bt;
    return InfoCard(
      key: const Key('rules-silent'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: SwitchLine(
        key: const Key('rules-always-mute'),
        leading: IconBadge(
          icon: Icons.volume_off_rounded,
          color: r.alwaysMute ? Tone.warn.color(context) : bt.muted,
          size: 40,
        ),
        title: 'Keep it silent',
        subtitle: r.alwaysMute
            ? 'The TV stays muted, whatever the remote does'
            : 'Off. Handy for early mornings',
        value: r.alwaysMute,
        onChanged: (on) => _edit((r) => r.copyWith(alwaysMute: on)),
      ),
    );
  }

  Widget _styleCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final bed = nextBedtime(r.tvTime.schedule, _now());
    return SettingCard(
      key: const Key('rules-style'),
      icon: Icons.chat_bubble_rounded,
      tone: Tone.accent,
      title: const Text('How the TV says no'),
      children: [
        SegmentChoice<RuleStyle>(
          keyPrefix: 'rules-style',
          options: const [
            (RuleStyle.sneaky, 'Quietly'),
            (RuleStyle.explicit, 'Friendly message'),
          ],
          value: r.style,
          onChanged: (s) => _edit((r) => r.copyWith(style: s)),
        ),
        const SizedBox(height: Gap.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: TvSaysNoPreview(
            style: r.style,
            backAt: bed == null ? null : friendlyTime(context, bed.end),
          ),
        ),
        const SizedBox(height: Gap.md),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          child: Text(
            r.style == RuleStyle.sneaky
                ? 'The app just closes and the TV goes Home, as if the '
                    'show ended. No message, nothing to argue with.'
                : 'A friendly card from Tubby says TV time is over and when '
                    'it comes back. The TV says no, not you.',
            key: ValueKey(r.style),
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _tonightCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
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
    return InfoCard(
      key: const Key('rules-overrides'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TonightTile(
                  key: const Key('rules-allow-youtube'),
                  icon: Icons.smart_display_rounded,
                  label: 'Allow YouTube tonight',
                  on: ytAllowed,
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
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _TonightTile(
                  key: const Key('rules-mute-30'),
                  icon: Icons.volume_off_rounded,
                  label: 'Quiet for 30 min',
                  on: quiet,
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
              ),
            ],
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            for (final o in active)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Row(
                  children: [
                    Icon(
                      switch (o.kind) {
                        OverrideKind.allowApp => Icons.check_circle_rounded,
                        OverrideKind.muteUntil => Icons.volume_off_rounded,
                        OverrideKind.breakUntil => Icons.pause_circle_rounded,
                      },
                      size: 20,
                      color: bt.mint,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        '${switch (o.kind) {
                          OverrideKind.allowApp =>
                            '${appLabel(o.pkg ?? '')} allowed',
                          OverrideKind.muteUntil => 'Quiet',
                          OverrideKind.breakUntil => 'Paused',
                        }} · until '
                        '${friendlyTime(context, o.untilTime!.toLocal())}',
                        style: text.bodyMedium!.copyWith(color: bt.ink),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : () => _removeOverride(o),
                      child: const Text('End now'),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: Gap.sm),
          Text(
            'These go to the TV right away and end by themselves.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── pieces ──

class _StatusLine extends ConsumerWidget {
  final AgentRules rules;
  final bool dirty;

  const _StatusLine({required this.rules, required this.dirty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final tv = ref.watch(activeTvProvider)?.name ?? 'the TV';
    final when = rules.updatedAtTime;
    final c = dirty ? bt.sunInk : bt.mintInk;
    return Column(
      key: const Key('rules-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          child: Row(
            key: ValueKey(dirty),
            children: [
              Icon(
                dirty ? Icons.edit_rounded : Icons.shield_rounded,
                size: 16,
                color: c,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  dirty
                      ? 'Not saved yet · $tv still runs the old rules'
                      : 'Saved to $tv · runs even when you\'re away',
                  style: text.labelLarge!.copyWith(fontSize: 14, color: c),
                ),
              ),
            ],
          ),
        ),
        if (rules.updatedBy.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Last changed by ${rules.updatedBy}'
            '${when == null ? '' : ' · ${relativeTime(when)}'}',
            key: const Key('rules-updated'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _PresetChips extends StatelessWidget {
  final RulePreset? active;
  final ValueChanged<RulePreset>? onPick;

  const _PresetChips({required this.active, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final p in RulePreset.values)
          InkPill(
            key: Key('preset-${p.name}'),
            label: p.label,
            selected: active == p,
            onTap: active == p || onPick == null ? null : () => onPick!(p),
          ),
        Tooltip(
          message: 'Change anything below and it becomes your own routine',
          child: InkPill(
            key: const Key('preset-custom'),
            label: 'Custom',
            icon: Icons.tune_rounded,
            selected: active == null,
          ),
        ),
      ],
    );
  }
}

/// The empty state that teaches: three starting points.
class _Templates extends StatelessWidget {
  final ValueChanged<RulePreset>? onPick;
  const _Templates({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return InfoCard(
      key: const Key('rules-templates'),
      color: bt.sunTint,
      borderColor: bt.sunTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Tubby(mood: TubbyMood.asleep, size: 52, animate: false),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pick a starting point', style: text.titleMedium),
                    Text(
                      'One tap fills in bedtime, TV time and volume. Tweak '
                      'anything after.',
                      style: text.bodySmall!.copyWith(color: bt.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final p in RulePreset.values) ...[
            if (p != RulePreset.schoolNight) const SizedBox(height: Gap.sm),
            InfoCard(
              key: Key('template-${p.name}'),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              onTap: onPick == null ? null : () => onPick!(p),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.label, style: text.titleSmall),
                        Text(p.blurb, style: text.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: bt.muted),
                ],
              ),
            ),
          ],
        ],
      ),
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
      helpText: from ? 'TV OFF FROM' : 'TV BACK AT',
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
            borderRadius: Radii.field,
            onTap: () => _pick(context, from),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: Gap.sm,
              ),
              child: Text(
                hhmmLabel(v, h24: h24),
                softWrap: false,
                style: Fonts.bricolage(
                  20,
                  color: bt.ink,
                  tabularFigures: true,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: bt.borderStrong,
                  decorationThickness: 2,
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.xs, Gap.md),
      decoration: BoxDecoration(
        color: bt.canvas,
        borderRadius: Radii.tile,
        border: Border.all(color: bt.hairline),
      ),
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
                      size: 18,
                      color: bt.muted,
                    ),
                    time(row.to, false),
                    if (row.crossesMidnight)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text('next day', style: text.bodySmall),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('schedule-remove'),
                tooltip: 'Remove these quiet hours',
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: bt.muted),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: Gap.xs, right: Gap.sm),
            child: LayoutBuilder(
              builder: (context, c) {
                final dot = (c.maxWidth / 7 - 3).clamp(28.0, 36.0);
                return Row(
                  children: [
                    for (final d in _dayOrder)
                      Expanded(
                        child: _DayDot(
                          key: Key('day-$d'),
                          letter: _dayLetter[d]!,
                          word: _dayWord[d]!,
                          size: dot,
                          on: row.days.contains(d),
                          onTap: () {
                            final days = {...row.days};
                            days.contains(d) ? days.remove(d) : days.add(d);
                            onChanged(
                              row.copyWith(days: days.toList()..sort()),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Gap.sm),
          Padding(
            padding: const EdgeInsets.only(left: Gap.sm),
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
  final double size;
  final VoidCallback onTap;

  const _DayDot({
    super.key,
    required this.letter,
    required this.word,
    this.size = 36,
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
        radius: 24,
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              curve: Motion.settle,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? bt.sun : bt.hairline,
              ),
              child: Text(
                letter,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontSize: 14,
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

class _TonightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;

  const _TonightTile({
    super.key,
    required this.icon,
    required this.label,
    required this.on,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? bt.mintTint : bt.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.tile,
          side: BorderSide(color: on ? bt.mint : bt.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: on ? bt.mintInk : bt.skyInk, size: 24),
                  const SizedBox(height: Gap.sm),
                  Text(
                    label,
                    style: text.labelLarge!.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.settle,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.md,
                Gap.xs,
                Gap.md,
                Gap.md,
              ),
              child: Container(
                key: const Key('rules-save-bar'),
                padding: const EdgeInsets.fromLTRB(Gap.lg, 6, 6, 6),
                decoration: BoxDecoration(
                  color: bt.inkFill,
                  borderRadius: Radii.card,
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
                    const SizedBox(width: Gap.xs),
                    SizedBox(
                      width: 112,
                      child: PrimaryButton(
                        key: const Key('rules-save'),
                        icon: saving ? null : Icons.upload_rounded,
                        label: saving ? 'Saving…' : 'Save',
                        height: 48,
                        onPressed: saving ? null : onSave,
                      ),
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
        InfoCard(
          child: Column(
            children: [
              for (final l in shapeSummary(preset.shape, h24: h24))
                CheckLine(l, done: true, minHeight: 32),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            Icon(Icons.apps_rounded, size: 16, color: bt.muted),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Your allowed apps, Shorts and Tonight only stay as they '
                'are.',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        PrimaryButton(
          key: const Key('preset-confirm'),
          label: 'Use ${preset.label}',
          onPressed: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: Gap.sm),
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
          Text('WHAT\'S DIFFERENT', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final d in diff) BtBadge(d, tone: Tone.warn),
            ],
          ),
          const SizedBox(height: Gap.lg),
        ],
        ChoiceCard(
          key: const Key('rules-reload'),
          selected: false,
          tone: Tone.info,
          icon: Icons.tv_rounded,
          title: 'Theirs',
          body: 'Keep what\'s on the TV now. Your edits here are dropped.',
          onTap: () => Navigator.pop(context, 'theirs'),
        ),
        const SizedBox(height: Gap.sm),
        ChoiceCard(
          key: const Key('rules-overwrite'),
          selected: false,
          icon: Icons.phone_android_rounded,
          title: 'Mine',
          body: 'Send my changes. They replace what $by set.',
          onTap: () => Navigator.pop(context, 'mine'),
        ),
        const SizedBox(height: Gap.md),
        Text(
          'Either way, the TV keeps running a routine the whole time.',
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
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.only(left: 6),
      decoration: ShapeDecoration(
        color: bt.hairline,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(pkg: pkg, size: 28),
          const SizedBox(width: Gap.sm),
          Text(name, style: text.labelLarge!.copyWith(fontSize: 14)),
          if (onRemove != null)
            Semantics(
              button: true,
              label: 'Remove $name',
              excludeSemantics: true,
              child: InkResponse(
                radius: 20,
                onTap: onRemove,
                child: SizedBox(
                  width: 40,
                  height: 44,
                  child: Icon(Icons.close_rounded, size: 16, color: bt.muted),
                ),
              ),
            )
          else
            const SizedBox(width: Gap.md),
        ],
      ),
    );
  }
}

/// A coloured letter tile for an app (no icon API over ADB).
class AppAvatar extends StatelessWidget {
  final String pkg;
  final double size;

  const AppAvatar({super.key, required this.pkg, this.size = 36});

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
          height: 1,
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
              padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.blocklist ? 'Apps to block' : 'Apps that can open',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: Gap.md),
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
                  padding: EdgeInsets.all(Gap.lg),
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
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
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
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(Gap.xl),
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
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, 0),
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
    final text = Theme.of(context).textTheme;
    return Semantics(
      checked: on,
      label: appLabel(pkg),
      excludeSemantics: true,
      button: true,
      child: InkWell(
        borderRadius: Radii.tile,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Row(
              children: [
                AppAvatar(pkg: pkg, size: 40),
                const SizedBox(width: Gap.md),
                Expanded(child: Text(appLabel(pkg), style: text.titleSmall)),
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? bt.mintInk : Colors.transparent,
                    border: Border.all(
                      color: on ? bt.mintInk : bt.borderStrong,
                      width: 2,
                    ),
                  ),
                  child: on
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
