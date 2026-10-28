import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_models.dart';
import '../ops/baseline.dart';
import '../ops/restore_planner.dart';
import '../providers/agent_providers.dart';
import '../providers/tv_providers.dart';
import '../ui/components.dart';
import '../ui/controls.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'tv/common.dart';

const _confirmWord = 'RESTORE';

/// Put the TV back the way it was: over Home mode, step by step, checked
/// and logged. Works even if Always On is broken.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  RestoreTarget _target = RestoreTarget.undoBoretube;
  bool _helper = false;
  bool _commands = false;
  final _confirm = TextEditingController();

  /// Set once a run starts: the plan being run and a result per action.
  RestorePlan? _running;
  List<RestoreStepResult?> _results = const [];
  bool _done = false;

  RestoreRequest get _req => (
        target: _target,
        removeHelper: _target == RestoreTarget.stock && _helper,
      );

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(RestorePlan plan) async {
    final runner = await ref.read(restoreRunnerProvider.future);
    if (runner == null || !mounted) return;
    FocusScope.of(context).unfocus();
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _running = plan;
      _results = List.filled(plan.actions.length, null);
      _done = false;
    });
    final results = await runner.run(
      plan,
      onStep: (i, r) {
        if (mounted) setState(() => _results = [..._results]..[i] = r);
      },
    );
    final agentGone = results.any(
      (r) => r.ok && r.step.kind == RestoreStepKind.uninstallAgent,
    );
    final id = ref.read(activeTvIdProvider);
    if (agentGone && id != null) {
      await ref.read(agentTokenStoreProvider).delete(id);
      ref.invalidate(agentTokenProvider);
    }
    ref.invalidate(journalEntriesProvider);
    ref.invalidate(healthProvider);
    if (mounted) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAdb = ref.watch(activeHasAdbProvider);
    final running = _running != null;
    return PopScope(
      canPop: !running || _done,
      child: !hasAdb
          ? Scaffold(
              appBar: AppBar(),
              body: const AdbRequired(what: 'Putting the TV back'),
            )
          : DetailPage(
              title: running
                  ? (_done ? 'Done' : 'Putting it back…')
                  : 'Put the TV back',
              subtitle: running
                  ? null
                  : 'Runs from this phone directly, so it works even if '
                      'Always On is broken. Every step is checked and kept '
                      'in History.',
              children: running ? _progress(context) : _chooser(context),
            ),
    );
  }

  List<Widget> _chooser(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final plan = ref.watch(restorePlanProvider(_req));
    final ready = plan.valueOrNull;
    final matches = _confirm.text.trim().toUpperCase() == _confirmWord;
    final canRun = ready != null && !ready.isEmpty && matches;
    return [
      const SectionHeader(
        'How far back',
        padding: EdgeInsets.fromLTRB(Gap.xs, 0, Gap.xs, Gap.sm),
      ),
      ChoiceCard(
        key: const Key('restore-undo'),
        selected: _target == RestoreTarget.undoBoretube,
        icon: Icons.undo_rounded,
        title: 'Undo boretube',
        body: 'Only what boretube changed: apps it switched off come back, '
            'YouTube returns if boretube hid it, and Always On is removed.',
        onTap: () => setState(() => _target = RestoreTarget.undoBoretube),
      ),
      const SizedBox(height: Gap.sm),
      ChoiceCard(
        key: const Key('restore-stock'),
        selected: _target == RestoreTarget.stock,
        icon: Icons.tv_rounded,
        title: 'Like a new TV',
        body: 'Every clean-up app back on, YouTube and YouTube Music back, '
            'Always On removed. Things the TV needs are never touched.',
        onTap: () => setState(() => _target = RestoreTarget.stock),
        footer: _target == RestoreTarget.stock
            ? SwitchLine(
                key: const Key('restore-helper'),
                title: 'Also undo the calm home screen',
                subtitle: 'The Home button goes back to Google TV\'s own '
                    'home. The launcher app stays installed.',
                value: _helper,
                onChanged: (v) => setState(() => _helper = v),
              )
            : null,
      ),
      SectionHeader(
        'What will happen',
        trailing: TextButton(
          key: const Key('restore-show-commands'),
          style: TextButton.styleFrom(foregroundColor: bt.muted),
          onPressed: () => setState(() => _commands = !_commands),
          child: Text(_commands ? 'Hide details' : 'Exact commands'),
        ),
      ),
      plan.when(
        loading: () => const SkeletonCard(rows: 4),
        error: (e, _) => InfoCard(
          child: EmptyState(
            icon: Icons.wifi_off_rounded,
            tone: Tone.bad,
            title: 'Couldn\'t read the TV',
            message: 'Is it on and on this Wi-Fi? Then try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(restorePlanProvider(_req)),
          ),
        ),
        data: (p) => p == null
            ? const SizedBox.shrink()
            : _PlanPreview(plan: p, commands: _commands),
      ),
      if (ready != null && !ready.isEmpty) ...[
        const SizedBox(height: Gap.xl),
        InfoCard(
          key: const Key('restore-confirm-card'),
          color: bt.berryTint,
          borderColor: bt.berryBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                  style: text.titleSmall!.copyWith(color: bt.berryInk),
                  children: const [
                    TextSpan(text: 'To be sure, type '),
                    TextSpan(
                      text: _confirmWord,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.sm),
              TextField(
                key: const Key('restore-confirm'),
                controller: _confirm,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                style: text.titleMedium!.copyWith(letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: _confirmWord,
                  suffixIcon: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: matches
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('ok'),
                            color: bt.mintInk,
                          )
                        : const SizedBox(key: ValueKey('no'), width: 24),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              PrimaryButton(
                key: const Key('restore-run'),
                kind: ButtonKind.berry,
                icon: Icons.settings_backup_restore_rounded,
                label: 'Put it back · ${ready.actions.length} '
                    'step${ready.actions.length == 1 ? '' : 's'}',
                onPressed: canRun ? () => _run(ready) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(
          'Keep this app open while it runs, and wait a minute before '
          'restarting the TV so the changes stick.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    ];
  }

  List<Widget> _progress(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final plan = _running!;
    final actions = plan.actions;
    final finished = _results.whereType<RestoreStepResult>().toList();
    final failed = finished.where((r) => !r.ok).toList();
    return [
      if (_done)
        InfoCard(
          key: const Key('restore-summary'),
          radius: Radii.hero,
          color: failed.isEmpty ? bt.mintTint : bt.sunTint,
          borderColor: failed.isEmpty ? bt.mintTint : bt.sunTint,
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tubby(
                mood: failed.isEmpty ? TubbyMood.cleaning : TubbyMood.calm,
                size: 64,
                beaming: failed.isEmpty,
                animate: false,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                failed.isEmpty
                    ? 'The TV is back the way it was'
                    : '${finished.length - failed.length} of '
                        '${finished.length} steps worked',
                style: text.headlineMedium,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                failed.isEmpty
                    ? 'Every step was checked on the TV. Wait a minute '
                        'before restarting the TV so the changes stick.'
                    : 'The rest still ran. Run it again to retry what '
                        'didn\'t work. Wait a minute before restarting the '
                        'TV.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Gap.lg),
              PrimaryButton(
                label: 'Done',
                kind: ButtonKind.ink,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        )
      else
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${finished.length} of ${actions.length}',
                      style: Fonts.bricolage(
                        28,
                        color: bt.ink,
                        tabularFigures: true,
                      ),
                    ),
                  ),
                  const DelayedSpinner(color: Color(0xFF3A8DFF), size: 18),
                ],
              ),
              const SizedBox(height: Gap.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    end: actions.isEmpty ? 0 : finished.length / actions.length,
                  ),
                  duration: Motion.of(context, Motion.slow),
                  curve: Motion.settle,
                  builder: (context, v, _) => LinearProgressIndicator(
                    minHeight: 8,
                    value: v,
                    color: bt.mint,
                    backgroundColor: bt.hairline,
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text('Keep this app open', style: text.bodySmall),
            ],
          ),
        ),
      SectionHeader('Steps · ${actions.length}'),
      GroupCard(
        children: [
          for (var i = 0; i < actions.length; i++)
            _ResultRow(
              key: Key('restore-step-$i'),
              step: actions[i],
              result: _results[i],
              running: i == finished.length && !_done,
            ),
        ],
      ),
    ];
  }
}

class _PlanPreview extends StatelessWidget {
  final RestorePlan plan;
  final bool commands;

  const _PlanPreview({required this.plan, required this.commands});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    var n = 0;
    return GroupCard(
      children: [
        if (plan.isEmpty)
          const StatusRow(
            tone: Tone.ok,
            icon: Icons.check_rounded,
            title: 'Nothing to change',
            detail: 'The TV already looks like this.',
          ),
        for (final s in plan.steps)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.runs ? bt.skyTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: s.runs
                      ? Text(
                          '${++n}',
                          style: text.labelLarge!.copyWith(
                            fontSize: 13,
                            color: bt.skyInk,
                            fontFeatures: Fonts.tabular,
                          ),
                        )
                      : Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: bt.muted,
                        ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: text.titleSmall),
                      if (s.why.isNotEmpty && (commands || !s.runs))
                        Text(s.why, style: text.bodySmall),
                      if (commands && s.command != null) ...[
                        const SizedBox(height: Gap.xs),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Gap.sm),
                          decoration: BoxDecoration(
                            color: bt.hairline,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            s.command!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontFamilyFallback: ['Roboto'],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final RestoreStep step;
  final RestoreStepResult? result;
  final bool running;

  const _ResultRow({
    super.key,
    required this.step,
    required this.result,
    required this.running,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final bt = context.bt;
    final Widget trailing = r == null
        ? running
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: bt.sky,
                ),
              )
            : Icon(Icons.more_horiz_rounded, color: bt.faint)
        : Icon(
            r.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: r.ok ? bt.mint : bt.berry,
            key: Key(r.ok ? 'restore-ok' : 'restore-failed'),
          );
    return StatusRow(
      tone: r == null ? Tone.idle : (r.ok ? Tone.ok : Tone.bad),
      icon: switch (step.kind) {
        RestoreStepKind.uninstallAgent => Icons.shield_outlined,
        RestoreStepKind.enable => Icons.toggle_on_outlined,
        RestoreStepKind.installExisting => Icons.download_rounded,
        RestoreStepKind.removeLauncherHelper => Icons.accessibility_new,
        RestoreStepKind.setHome => Icons.home_outlined,
        RestoreStepKind.note => Icons.info_outline_rounded,
      },
      title: step.title,
      detail: r == null
          ? (running ? 'Working on it…' : 'Waiting')
          : r.ok
              ? 'Done · checked on the TV'
              : 'Didn\'t work: ${r.detail}',
      detailLines: 2,
      trailing: trailing,
    );
  }
}

class BaselineCard extends ConsumerWidget {
  const BaselineCard({super.key});

  void _view(BuildContext context, TvBaseline b) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Baseline snapshot'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              b.export(),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['Roboto'],
                  fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copy(context, b),
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, TvBaseline b) async {
    await Clipboard.setData(ClipboardData(text: b.export()));
    if (context.mounted) showStatusSnack(context, 'Baseline copied as JSON');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final baseline = ref.watch(baselineProvider);
    return baseline.when(
      loading: () => const SkeletonCard(rows: 1),
      error: (e, _) => InfoCard(
        child: Text('Couldn\'t read the baseline: $e', style: text.bodySmall),
      ),
      data: (b) => b == null
          ? InfoCard(
              child: Text(
                'Captured automatically the first time this phone connects '
                'to the TV directly.',
                style: text.bodySmall,
              ),
            )
          : InfoCard(
              key: const Key('restore-baseline'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconBadge(
                        icon: Icons.photo_camera_back_rounded,
                        color: Tone.info.color(context),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Captured ${_date(b.capturedAt)}',
                              style: text.titleSmall,
                            ),
                            Text(
                              '${b.disabled.length} apps off · '
                              '${b.uninstalled.length} removed · YouTube '
                              '${b.stockYouTube ?? '—'}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    b.buildFingerprint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Roboto'],
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('baseline-view'),
                          onPressed: () => _view(context, b),
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text('View JSON'),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('baseline-copy'),
                          onPressed: () => _copy(context, b),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  static String _date(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} ${clockTime(t)}';
}
