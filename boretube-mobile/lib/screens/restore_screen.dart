import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_models.dart';
import '../ops/baseline.dart';
import '../ops/restore_planner.dart';
import '../providers/agent_providers.dart';
import '../providers/tv_providers.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import 'tv/common.dart';

const _confirmWord = 'RESTORE';

/// TV › Settings › Restore TV: put the TV back, over ADB, step by step.
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
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasAdb = ref.watch(activeHasAdbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Restore TV')),
      body: !hasAdb
          ? const AdbRequired(what: 'Restore')
          : _running != null
              ? _progress(context)
              : _chooser(context),
    );
  }

  Widget _chooser(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = ref.watch(restorePlanProvider(_req));
    final ready = plan.valueOrNull;
    final canRun =
        ready != null && !ready.isEmpty && _confirm.text.trim() == _confirmWord;
    return ListView(
      padding: tvListPadding,
      children: [
        InfoCard(
          child: Row(
            children: [
              IconBadge(
                icon: Icons.settings_backup_restore_rounded,
                color: Tone.accent.color(context),
                size: 44,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'Put the TV back the way it was. This runs from your '
                  'phone directly, so it works even if Always On is broken. '
                  'Every step is checked and logged in Activity.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SectionHeader('How far back'),
        _TargetCard(
          key: const Key('restore-undo'),
          selected: _target == RestoreTarget.undoBoretube,
          icon: Icons.undo_rounded,
          title: 'Undo boretube',
          body: 'Reverses only what boretube changed: turns back on the '
              'apps it turned off, puts stock YouTube back if boretube '
              'removed it, and removes Always On.',
          onTap: () => setState(() => _target = RestoreTarget.undoBoretube),
        ),
        const SizedBox(height: Gap.md),
        _TargetCard(
          key: const Key('restore-stock'),
          selected: _target == RestoreTarget.stock,
          icon: Icons.tv_rounded,
          title: 'Back to stock',
          body: 'Like a new TV: turns every clean-up app back on, puts back '
              'YouTube and YouTube Music, and removes Always On. System apps '
              '(Wi-Fi setup, Google TV home, screensaver) are never touched.',
          onTap: () => setState(() => _target = RestoreTarget.stock),
          footer: _target == RestoreTarget.stock
              ? CheckboxListTile(
                  key: const Key('restore-helper'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _helper,
                  onChanged: (v) => setState(() => _helper = v ?? false),
                  title: const Text('Also remove the custom launcher helper'),
                  subtitle: const Text(
                    'Home goes back to Google TV\'s own home screen. The '
                    'launcher app itself stays installed.',
                  ),
                )
              : null,
        ),
        SectionHeader(
          'What will happen',
          trailing: TextButton.icon(
            key: const Key('restore-show-commands'),
            onPressed: () => setState(() => _commands = !_commands),
            icon: Icon(
              _commands ? Icons.expand_less_rounded : Icons.code_rounded,
              size: 18,
            ),
            label: Text(_commands ? 'Hide commands' : 'Exact commands'),
          ),
        ),
        plan.when(
          loading: () => const SkeletonCard(rows: 4),
          error: (e, _) => InfoCard(
            child: EmptyState(
              icon: Icons.wifi_off_rounded,
              tone: Tone.bad,
              title: 'Couldn\'t read the TV',
              message: '$e',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(restorePlanProvider(_req)),
            ),
          ),
          data: (p) => p == null
              ? const SizedBox.shrink()
              : _PlanPreview(plan: p, commands: _commands),
        ),
        const SizedBox(height: Gap.xl),
        if (ready != null && !ready.isEmpty) ...[
          Text(
            'Type $_confirmWord to confirm',
            style: text.titleSmall,
          ),
          const SizedBox(height: Gap.sm),
          TextField(
            key: const Key('restore-confirm'),
            controller: _confirm,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: _confirmWord,
              prefixIcon: Icon(Icons.keyboard_rounded),
            ),
          ),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const Key('restore-run'),
            onPressed: canRun ? () => _run(ready) : null,
            icon: const Icon(Icons.settings_backup_restore_rounded),
            label: Text(
              'Restore TV · ${ready.actions.length} '
              'step${ready.actions.length == 1 ? '' : 's'}',
            ),
          ),
        ],
        const SectionHeader('Baseline snapshot'),
        const _BaselineCard(),
      ],
    );
  }

  Widget _progress(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    final plan = _running!;
    final actions = plan.actions;
    final finished = _results.whereType<RestoreStepResult>().toList();
    final failed = finished.where((r) => !r.ok).toList();
    return ListView(
      padding: tvListPadding,
      children: [
        if (_done)
          InfoCard(
            key: const Key('restore-summary'),
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: failed.isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.report_rounded,
                  color: failed.isEmpty ? status.ok : status.warn,
                  size: 52,
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  failed.isEmpty
                      ? 'TV restored'
                      : '${finished.length - failed.length} of '
                          '${finished.length} steps worked',
                  style: text.headlineSmall,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  failed.isEmpty
                      ? 'Every step was checked on the TV. Wait a minute '
                          'before restarting the TV so the changes stick.'
                      : 'The rest still ran. You can run Restore again to '
                          'retry what didn\'t work. Wait a minute before '
                          'restarting the TV.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: Gap.lg),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          )
        else
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Restoring…', style: text.titleLarge),
                const SizedBox(height: Gap.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: actions.isEmpty
                        ? null
                        : finished.length / actions.length,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  '${finished.length} of ${actions.length} · keep the app '
                  'open',
                  style: text.bodySmall,
                ),
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
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Widget? footer;

  const _TargetCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = scheme.primary;
    return InfoCard(
      onTap: onTap,
      color: selected
          ? Color.alphaBlend(
              accent.withValues(alpha: 0.10),
              scheme.surfaceContainerLow,
            )
          : null,
      borderColor: selected ? accent.withValues(alpha: 0.7) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: icon,
                color: selected ? accent : StatusColors.of(context).idle,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(body, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : scheme.onSurfaceVariant,
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: Gap.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  final RestorePlan plan;
  final bool commands;

  const _PlanPreview({required this.plan, required this.commands});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
                SizedBox(
                  width: 28,
                  child: s.runs
                      ? Text('${++n}', style: text.titleSmall)
                      : Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: text.titleSmall),
                      if (s.why.isNotEmpty) Text(s.why, style: text.bodySmall),
                      if (commands && s.command != null) ...[
                        const SizedBox(height: Gap.xs),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Gap.sm),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
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
    final s = StatusColors.of(context);
    final Widget trailing = r == null
        ? running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Icon(Icons.more_horiz_rounded, color: s.idle)
        : Icon(
            r.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: r.ok ? s.ok : s.bad,
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
          ? step.command
          : r.ok
              ? '${r.before} → ${r.after}'
              : 'Didn\'t work: ${r.detail}',
      detailLines: 2,
      trailing: trailing,
    );
  }
}

class _BaselineCard extends ConsumerWidget {
  const _BaselineCard();

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
