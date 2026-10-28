import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_client.dart';
import '../../providers/agent_providers.dart';
import '../../providers/now_playing.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';

/// Shown as `updatedBy` on the TV ("by Parent phone at 19:30").
final rulesAuthorProvider = Provider<String>((ref) => 'Parent phone');

/// Rule-editor clock; tests override it.
final rulesClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

const kStockYouTube = 'com.google.android.youtube.tv';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Edits the rules document as a draft; Save sends it with its version
/// and handles "the TV has newer rules" (409).
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

  DateTime _now() => ref.read(rulesClockProvider)();

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
      unawaited(HapticFeedback.lightImpact());
      setState(() {
        _base = saved;
        _draft = saved;
      });
      showStatusSnack(context, 'Saved to the TV');
      unawaited(ref.read(agentStatusProvider.notifier).refresh());
    } on AgentConflict catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _conflict(e.current, draft ?? _draft);
    } on AgentException catch (e) {
      if (mounted) {
        showStatusSnack(context, 'Not saved: ${e.message}', ok: false);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _conflict(AgentRules current, AgentRules mine) async {
    final when = current.updatedAtTime;
    final by = current.updatedBy.isEmpty ? 'another phone' : current.updatedBy;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('rules-conflict'),
        icon: const Icon(Icons.sync_problem_rounded, size: 32),
        title: const Text('TV has newer rules', textAlign: TextAlign.center),
        content: Text(
          'Changed by $by'
          '${when == null ? '' : ' at ${clockTime(when.toLocal())}'} '
          '(version ${current.version}).\n\n'
          'Reload to see them, or overwrite them with yours.',
        ),
        actions: [
          TextButton(
            key: const Key('rules-overwrite'),
            onPressed: () => Navigator.pop(context, 'overwrite'),
            child: const Text('Overwrite'),
          ),
          FilledButton(
            key: const Key('rules-reload'),
            onPressed: () => Navigator.pop(context, 'reload'),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'reload') {
      setState(() {
        _base = current;
        _draft = current;
      });
    } else if (choice == 'overwrite') {
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
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
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

  @override
  Widget build(BuildContext context) {
    final r = _draft;
    final tv = ref.watch(activeTvProvider);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.sm,
              Gap.page,
              Gap.xxl,
            ),
            children: [
              _Header(rules: _base, tvName: tv?.name ?? 'TV'),
              const SectionHeader('Allowed apps'),
              _appsCard(context, r),
              const SectionHeader('Sound'),
              _soundCard(context, r),
              const SectionHeader('TV time'),
              _tvTimeCard(context, r),
              const SectionHeader('When a rule kicks in'),
              _styleCard(context, r),
              const SectionHeader('Temporary'),
              _overridesCard(context, r),
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

  // ── sections ──

  Widget _appsCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final a = r.allowedApps;
    return InfoCard(
      key: const Key('rules-apps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<AppsMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: AppsMode.off, label: Text('Any')),
              ButtonSegment(
                value: AppsMode.allowlist,
                label: Text('Allow only'),
              ),
              ButtonSegment(
                value: AppsMode.blocklist,
                label: Text('Block'),
              ),
            ],
            selected: {a.mode},
            onSelectionChanged: (s) => _edit(
              (r) => r.copyWith(allowedApps: a.copyWith(mode: s.first)),
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            switch (a.mode) {
              AppsMode.off => 'Every app can open.',
              AppsMode.allowlist => 'Only the apps below open. Anything '
                  'else is closed.',
              AppsMode.blocklist => 'The apps below are closed when they '
                  'open.',
            },
            style: text.bodySmall,
          ),
          if (a.mode != AppsMode.off) ...[
            const SizedBox(height: Gap.md),
            if (a.packages.isEmpty)
              Text(
                a.mode == AppsMode.allowlist
                    ? 'No apps picked yet: nothing would open.'
                    : 'No apps picked yet.',
                style: text.bodySmall?.copyWith(
                  color: Tone.warn.color(context),
                ),
              )
            else
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final p in a.packages)
                    InputChip(
                      avatar: AppAvatar(pkg: p, size: 22),
                      label: Text(appLabel(p)),
                      onDeleted: () => _edit(
                        (r) => r.copyWith(
                          allowedApps: a.copyWith(
                            packages: [
                              for (final x in a.packages)
                                if (x != p) x,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: Gap.md),
            OutlinedButton.icon(
              key: const Key('rules-pick-apps'),
              onPressed: _pickApps,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Choose apps'),
            ),
          ],
          const Divider(height: Gap.xl),
          _SwitchRow(
            key: const Key('rules-stock-youtube'),
            icon: Icons.smart_display_rounded,
            title: 'Let stock YouTube stay',
            subtitle: r.stockYouTubeAllowed
                ? 'Always On leaves YouTube installed'
                : 'Always On removes YouTube if it comes back',
            value: r.stockYouTubeAllowed,
            onChanged: (v) => _edit((r) => r.copyWith(stockYouTubeAllowed: v)),
          ),
        ],
      ),
    );
  }

  Widget _soundCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final v = r.volumeLimit;
    return InfoCard(
      key: const Key('rules-sound'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            key: const Key('rules-volume-limit'),
            icon: Icons.volume_down_rounded,
            title: 'Volume limit',
            subtitle: v.enabled
                ? 'Capped at ${v.maxPercent}% — turning it up snaps back'
                : 'Off',
            value: v.enabled,
            onChanged: (on) => _edit(
              (r) => r.copyWith(volumeLimit: v.copyWith(enabled: on)),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: v.enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Row(
              children: [
                const SizedBox(width: Gap.xs),
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
                  width: 44,
                  child: Text(
                    '${v.maxPercent}%',
                    textAlign: TextAlign.right,
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const Divider(),
          _SwitchRow(
            key: const Key('rules-always-mute'),
            icon: Icons.volume_off_rounded,
            title: 'Always mute',
            subtitle: r.alwaysMute ? 'The TV stays silent' : 'Off',
            value: r.alwaysMute,
            onChanged: (on) => _edit((r) => r.copyWith(alwaysMute: on)),
          ),
        ],
      ),
    );
  }

  Widget _tvTimeCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final t = r.tvTime;
    void setRows(List<ScheduleRow> rows) =>
        _edit((r) => r.copyWith(tvTime: t.copyWith(schedule: rows)));
    final limit = t.dailyLimitMin;
    return InfoCard(
      key: const Key('rules-tv-time'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quiet hours', style: text.titleSmall),
          Text(
            'The TV is off-limits in these windows.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Gap.md),
          for (var i = 0; i < t.schedule.length; i++) ...[
            _ScheduleRowEditor(
              key: Key('rules-schedule-$i'),
              row: t.schedule[i],
              onChanged: (row) => setRows([...t.schedule]..[i] = row),
              onRemove: () => setRows([...t.schedule]..removeAt(i)),
            ),
            const SizedBox(height: Gap.sm),
          ],
          OutlinedButton.icon(
            key: const Key('rules-add-schedule'),
            onPressed: () => setRows([...t.schedule, const ScheduleRow()]),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add quiet hours'),
          ),
          const Divider(height: Gap.xl),
          Row(
            children: [
              Expanded(child: Text('Daily limit', style: text.titleSmall)),
              Text(
                limit == 0 ? 'Off' : _minutes(limit),
                key: const Key('rules-daily-label'),
                style: text.titleSmall,
              ),
            ],
          ),
          Slider(
            key: const Key('rules-daily-slider'),
            value: limit.clamp(0, 300).toDouble(),
            max: 300,
            divisions: 20,
            label: limit == 0 ? 'Off' : _minutes(limit),
            onChanged: (x) => _edit(
              (r) => r.copyWith(tvTime: t.copyWith(dailyLimitMin: x.round())),
            ),
          ),
          Text(
            'Counts screen-on time only, on the TV\'s clock.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _styleCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    return InfoCard(
      key: const Key('rules-style'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<RuleStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: RuleStyle.sneaky,
                icon: Icon(Icons.visibility_off_rounded),
                label: Text('Sneaky'),
              ),
              ButtonSegment(
                value: RuleStyle.explicit,
                icon: Icon(Icons.campaign_rounded),
                label: Text('Explicit'),
              ),
            ],
            selected: {r.style},
            onSelectionChanged: (s) => _edit((r) => r.copyWith(style: s.first)),
          ),
          const SizedBox(height: Gap.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              r.style == RuleStyle.sneaky
                  ? 'The app just closes and the TV goes Home, as if it '
                      'crashed. No message.'
                  : 'A friendly card says "TV time is over" and when it '
                      'comes back, then the TV goes Home.',
              key: ValueKey(r.style),
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overridesCard(BuildContext context, AgentRules r) {
    final text = Theme.of(context).textTheme;
    final now = _now();
    final active = [
      for (final o in r.overrides)
        if (o.activeAt(now)) o,
    ];
    final tonight = DateTime(now.year, now.month, now.day, 23, 59);
    return InfoCard(
      key: const Key('rules-overrides'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonalIcon(
                key: const Key('rules-allow-youtube'),
                onPressed: _saving
                    ? null
                    : () => _override(
                          RuleOverride(
                            kind: OverrideKind.allowApp,
                            pkg: kStockYouTube,
                            until: tonight.toUtc().toIso8601String(),
                          ),
                        ),
                icon: const Icon(Icons.smart_display_rounded),
                label: const Text('Allow YouTube tonight'),
              ),
              const SizedBox(height: Gap.sm),
              FilledButton.tonalIcon(
                key: const Key('rules-mute-30'),
                onPressed: _saving
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
                icon: const Icon(Icons.volume_off_rounded),
                label: const Text('Mute for 30 min'),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'These save to the TV right away and end by themselves.',
            style: text.bodySmall,
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
                        OverrideKind.allowApp => Icons.check_circle_outline,
                        OverrideKind.muteUntil => Icons.volume_off_outlined,
                        OverrideKind.breakUntil => Icons.coffee_outlined,
                      },
                      size: 20,
                      color: Tone.ok.color(context),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        '${switch (o.kind) {
                          OverrideKind.allowApp =>
                            'Allowed: ${appLabel(o.pkg ?? '')}',
                          OverrideKind.muteUntil => 'Muted',
                          OverrideKind.breakUntil => 'Break',
                        }} · until '
                        '${clockTime(o.untilTime!.toLocal())}',
                        style: text.bodyMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'End now',
                      onPressed: _saving ? null : () => _removeOverride(o),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _minutes(int m) {
    final h = m ~/ 60;
    final rest = m % 60;
    if (h == 0) return '$rest min';
    return rest == 0 ? '$h h' : '$h h $rest min';
  }
}

class _Header extends StatelessWidget {
  final AgentRules rules;
  final String tvName;

  const _Header({required this.rules, required this.tvName});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ok = StatusColors.of(context).ok;
    final when = rules.updatedAtTime;
    return InfoCard(
      key: const Key('rules-header'),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            ok.withValues(alpha: 0.12),
            scheme.surfaceContainerLow,
          ),
          scheme.surfaceContainerLow,
        ],
      ),
      child: Row(
        children: [
          IconBadge(icon: Icons.shield_rounded, color: ok, size: 44),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rules on $tvName', style: text.titleMedium),
                Text(
                  rules.updatedBy.isEmpty
                      ? 'Enforced by Always On, 24/7'
                      : '${rules.updatedBy}'
                          '${when == null ? '' : ' · ${relativeTime(when)}'}',
                  key: const Key('rules-updated'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          TagChip('v${rules.version}', tone: Tone.ok),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = value ? Tone.accent.color(context) : Tone.idle.color(context);
    return InkWell(
      borderRadius: Radii.tile,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            IconBadge(icon: icon, color: c, size: 36),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRowEditor extends StatelessWidget {
  final ScheduleRow row;
  final ValueChanged<ScheduleRow> onChanged;
  final VoidCallback onRemove;

  const _ScheduleRowEditor({
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
      initialTime: _parse(from ? row.from : row.to),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    onChanged(from ? row.copyWith(from: _fmt(t)) : row.copyWith(to: _fmt(t)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget time(String label, String v, bool from) => Expanded(
          child: OutlinedButton(
            key: Key(from ? 'schedule-from' : 'schedule-to'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            ),
            onPressed: () => _pick(context, from),
            child: Column(
              children: [
                Text(label, style: text.labelSmall),
                Text(v, style: text.titleMedium),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: Radii.tile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 1; d <= 7; d++)
                _DayChip(
                  letter: _dayLetters[d - 1],
                  on: row.days.contains(d),
                  onTap: () {
                    final days = {...row.days};
                    days.contains(d) ? days.remove(d) : days.add(d);
                    onChanged(row.copyWith(days: days.toList()..sort()));
                  },
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              time('FROM', row.from, true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              time(row.crossesMidnight ? 'NEXT DAY' : 'TO', row.to, false),
              const SizedBox(width: Gap.xs),
              IconButton(
                key: const Key('schedule-remove'),
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String letter;
  final bool on;
  final VoidCallback onTap;

  const _DayChip({
    required this.letter,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: on,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: on ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            letter,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Container(
              key: const Key('rules-save-bar'),
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.md,
                Gap.page,
                Gap.md,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Unsaved changes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: saving ? null : onDiscard,
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: Gap.xs),
                  FilledButton.icon(
                    key: const Key('rules-save'),
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A coloured letter tile for an app (no icon API over ADB).
class AppAvatar extends StatelessWidget {
  final String pkg;
  final double size;

  const AppAvatar({super.key, required this.pkg, this.size = 36});

  static const _tones = [
    Color(0xFFE5735A),
    Color(0xFF6FA8DC),
    Color(0xFF5CC2A5),
    Color(0xFFE8C468),
    Color(0xFFB48EE0),
    Color(0xFFF2A65A),
  ];

  @override
  Widget build(BuildContext context) {
    final label = appLabel(pkg);
    final c =
        _tones[pkg.codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        label.isEmpty ? '?' : label[0].toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

/// Picks TV apps (from `TvOps.listApps`) for the allow/block list.
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final apps = ref.watch(appsProvider);
    final launcher =
        ref.watch(tvOpsProvider).valueOrNull?.profile.launcher?.pkg;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.xl,
                Gap.sm,
                Gap.xl,
                Gap.sm,
              ),
              child: Text(
                widget.blocklist ? 'Apps to block' : 'Apps allowed',
                style: text.titleLarge,
              ),
            ),
            Expanded(
              child: apps.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Gap.lg),
                  child: SkeletonCard(rows: 5),
                ),
                error: (e, _) => EmptyState(
                  icon: Icons.apps_outage_rounded,
                  title: 'Couldn\'t list the TV\'s apps',
                  message: '$e',
                ),
                data: (list) {
                  final shown = [
                    for (final a in list)
                      if (a.launchable && a.pkg != launcher) a.pkg,
                    for (final p in widget.selected)
                      if (!list.any((a) => a.pkg == p)) p,
                  ]..sort((a, b) => appLabel(a).compareTo(appLabel(b)));
                  if (shown.isEmpty) {
                    return const EmptyState(
                      icon: Icons.apps_rounded,
                      title: 'No apps found',
                      message: 'Listing apps needs Home mode.',
                    );
                  }
                  return ListView(
                    children: [
                      for (final p in shown)
                        CheckboxListTile(
                          key: Key('pick-$p'),
                          value: _picked.contains(p),
                          onChanged: (v) => setState(
                            () =>
                                v == true ? _picked.add(p) : _picked.remove(p),
                          ),
                          secondary: AppAvatar(pkg: p),
                          title: Text(appLabel(p)),
                          subtitle: Text(
                            p,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: FilledButton(
                key: const Key('pick-done'),
                onPressed: () => Navigator.pop(context, _picked.toList()),
                child: Text('Use ${_picked.length} '
                    'app${_picked.length == 1 ? '' : 's'}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
