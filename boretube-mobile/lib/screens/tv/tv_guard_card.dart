import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_client.dart';
import '../../agent/agent_installer.dart';
import '../../providers/agent_providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import '../shell_screen.dart';

/// TV Guard at the top of TV › Health: an install invitation, or its
/// state and kill switches.
class TvGuardCard extends ConsumerWidget {
  const TvGuardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(agentStatusProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: link.installed
          ? _InstalledCard(key: const Key('tv-guard-installed'), link: link)
          : const _InstallInvite(key: Key('tv-guard-invite')),
    );
  }
}

/// Opens the install (or repair) stepper and refreshes TV Guard after.
Future<void> runAgentSetup(
  BuildContext context,
  WidgetRef ref, {
  required bool repair,
}) async {
  final installer = await ref.read(agentInstallerProvider.future);
  if (!context.mounted) return;
  if (installer == null) {
    showStatusSnack(context, 'Connect over ADB first', ok: false);
    return;
  }
  await showAgentSetupSheet(
    context,
    title: repair ? 'Repairing TV Guard' : 'Installing TV Guard',
    start: repair ? installer.repair : installer.install,
  );
  ref.invalidate(agentTokenProvider);
  ref.invalidate(journalEntriesProvider);
  ref.invalidate(agentJournalProvider);
  await ref.read(agentStatusProvider.notifier).refresh();
}

class _InstallInvite extends ConsumerWidget {
  const _InstallInvite({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ok = StatusColors.of(context).ok;
    final bundle = ref.watch(agentBundleProvider);
    final missing = bundle.hasValue && bundle.value == null;
    const points = [
      (
        Icons.nights_stay_rounded,
        'Runs on the TV 24/7, even when your '
            'phone is away or off'
      ),
      (Icons.rule_rounded, 'Allowed apps, volume limit and TV time'),
      (Icons.healing_rounded, 'Heals itself after TV updates'),
    ];
    return InfoCard(
      padding: const EdgeInsets.all(Gap.xl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            ok.withValues(alpha: 0.16),
            scheme.surfaceContainerLow,
          ),
          scheme.surfaceContainerLow,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.shield_moon_rounded, color: ok, size: 48),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TV Guard', style: text.titleLarge),
                    Text('Not installed', style: text.bodySmall),
                  ],
                ),
              ),
              const TagChip('Optional', tone: Tone.ok),
            ],
          ),
          const SizedBox(height: Gap.lg),
          for (final (icon, line) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: ok),
                  const SizedBox(width: Gap.md),
                  Expanded(child: Text(line, style: text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            key: const Key('tv-guard-install'),
            onPressed: missing
                ? null
                : () => runAgentSetup(context, ref, repair: false),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Install TV Guard'),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            missing
                ? AgentBundleMissing.message
                : 'Takes about a minute. You can remove it any time; the '
                    'TV keeps working without it.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InstalledCard extends ConsumerStatefulWidget {
  final AgentLink link;
  const _InstalledCard({super.key, required this.link});

  @override
  ConsumerState<_InstalledCard> createState() => _InstalledCardState();
}

class _InstalledCardState extends ConsumerState<_InstalledCard> {
  String? _busy;

  Future<void> _do(String what, Future<void> Function(AgentClient c) f,
      {String? done}) async {
    final c = ref.read(agentClientProvider);
    if (c == null || _busy != null) return;
    setState(() => _busy = what);
    try {
      await f(c);
      await ref.read(agentStatusProvider.notifier).refresh();
      if (mounted && done != null) showStatusSnack(context, done);
    } on AgentException catch (e) {
      if (mounted) {
        showStatusSnack(context, 'Didn\'t work: ${e.message}', ok: false);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _mode(AgentMode m) async {
    if (m == AgentMode.safe &&
        !await confirmAction(
          context,
          title: 'Turn on safe mode?',
          message: 'TV Guard stops enforcing rules and the watchdog makes '
              'no changes. It keeps reporting, so you can see what it '
              'would do. Turn it off here any time.',
          confirmLabel: 'Safe mode',
          icon: Icons.health_and_safety_rounded,
        )) {
      return;
    }
    await _do(
      m.name,
      (c) => c.setMode(m),
      done: switch (m) {
        AgentMode.normal => 'TV Guard is back on',
        AgentMode.paused => 'TV Guard paused',
        AgentMode.safe => 'Safe mode on',
      },
    );
  }

  Future<void> _approve() async {
    final fp = widget.link.status?.buildFingerprint ?? '';
    final ok = await confirmAction(
      context,
      title: 'Approve this TV update?',
      message: 'The TV installed a software update. TV Guard paused its '
          'clean-up until you approve, in case the update changed '
          'something.\n\n$fp\n\nApprove if the TV works normally.',
      confirmLabel: 'Approve',
      icon: Icons.system_update_tv_rounded,
    );
    if (ok) {
      await _do('approve', (c) => c.approveBuild(), done: 'Update approved');
    }
  }

  Future<void> _runChecks() async {
    WatchdogReport? report;
    await _do('checks', (c) async {
      report = await c.runWatchdog();
    });
    final r = report;
    if (r == null || !mounted) return;
    ref.invalidate(agentJournalProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          r.ok ? Icons.fact_check_rounded : Icons.report_rounded,
          size: 32,
          color: r.ok
              ? StatusColors.of(context).ok
              : StatusColors.of(context).warn,
        ),
        title: const Text('TV Guard checks', textAlign: TextAlign.center),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                r.detail.isNotEmpty
                    ? r.detail
                    : r.lines.isEmpty
                        ? 'Everything checked out; nothing needed changing.'
                        : '${r.lines.length} items',
              ),
              for (final l in r.lines)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(l)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _uninstall() async {
    final ok = await confirmAction(
      context,
      title: 'Uninstall TV Guard?',
      message: 'Rules, breaks and the watchdog stop on the TV. Nothing '
          'else changes — the TV keeps working normally. You can install '
          'it again later.',
      confirmLabel: 'Uninstall',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = 'uninstall');
    try {
      final installer = await ref.read(agentInstallerProvider.future);
      final done = await installer?.uninstall() ?? false;
      if (!mounted) return;
      showStatusSnack(
        context,
        done ? 'TV Guard removed' : 'Couldn\'t remove TV Guard (needs ADB)',
        ok: done,
      );
      ref.invalidate(agentTokenProvider);
      ref.invalidate(journalEntriesProvider);
    } catch (e) {
      if (mounted) showStatusSnack(context, 'Didn\'t work: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final s = link.status;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final state = guardStateOf(link: link, onBreak: false, classic: false);
    final (label, tone) = GuardPill.look(state);
    final color = tone.color(context);
    final down = state == GuardState.down;
    final mode = s?.mode;
    final busy = _busy != null;

    Widget fact(String k, String v, {Tone? t}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k.toUpperCase(), style: text.labelSmall),
              const SizedBox(height: 2),
              Text(
                v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(color: t?.color(context)),
              ),
            ],
          ),
        );

    return InfoCard(
      padding: const EdgeInsets.all(Gap.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            color.withValues(alpha: 0.14),
            scheme.surfaceContainerLow,
          ),
          scheme.surfaceContainerLow,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: switch (state) {
                  GuardState.down => Icons.gpp_bad_rounded,
                  GuardState.safe => Icons.health_and_safety_rounded,
                  GuardState.paused => Icons.pause_circle_rounded,
                  GuardState.limited => Icons.gpp_maybe_rounded,
                  _ => Icons.verified_user_rounded,
                },
                color: color,
                size: 48,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TV Guard', style: text.titleLarge),
                    Text(
                      s == null
                          ? (down ? 'Not answering' : 'Checking…')
                          : 'v${s.version} · up ${_uptime(s.uptimeSec)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              TagChip(label, tone: tone),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                fact(
                  'Mode',
                  switch (s.mode) {
                    AgentMode.normal => 'Enforcing',
                    AgentMode.paused => 'Paused',
                    AgentMode.safe => 'Safe mode',
                  },
                  t: s.mode == AgentMode.normal ? Tone.ok : Tone.warn,
                ),
                fact(
                  'TV access',
                  switch (s.selfAdb) {
                    SelfAdb.ok => 'Allowed',
                    SelfAdb.needsApproval => 'Needs Allow',
                    SelfAdb.unavailable => 'Off',
                    SelfAdb.unknown => '—',
                  },
                  t: s.selfAdb == SelfAdb.ok ? Tone.ok : Tone.warn,
                ),
                fact('Rules', 'v${s.activeRulesVersion}'),
              ],
            ),
          ],
          if (down) ...[
            const SizedBox(height: Gap.lg),
            _Banner(
              key: const Key('tv-guard-down'),
              tone: Tone.bad,
              icon: Icons.portable_wifi_off_rounded,
              text: link.kind == AgentLinkKind.authFailed
                  ? 'TV Guard doesn\'t recognise this phone any more.'
                  : 'TV Guard isn\'t answering. Rules may not be running.',
            ),
          ],
          if (s != null && s.selfAdb == SelfAdb.needsApproval) ...[
            const SizedBox(height: Gap.md),
            const _Banner(
              tone: Tone.warn,
              icon: Icons.tv_rounded,
              text: 'Look at the TV and choose "Always allow" so TV Guard '
                  'can close apps. Tap Repair if the prompt is gone.',
            ),
          ] else if (s != null && s.isLimited) ...[
            const SizedBox(height: Gap.md),
            _Banner(
              key: const Key('tv-guard-limited'),
              tone: Tone.warn,
              icon: Icons.gpp_maybe_rounded,
              text: s.limitedReasons.isEmpty
                  ? 'TV Guard is running in limited mode. Repair may fix '
                      'it.'
                  : 'Limited: ${s.limitedReasons.join(' · ')}'
                      '${s.needsPhoneGrant ? '. Repair gives it the '
                          'missing permission.' : ''}',
            ),
          ],
          if (s != null && s.activeReasons.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Row(
              key: const Key('tv-guard-active'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 18, color: Tone.ok.color(context)),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Now: ${s.activeReasons.join(' · ')}',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (s != null && s.buildChangedSinceApproval) ...[
            const SizedBox(height: Gap.md),
            _Banner(
              key: const Key('tv-guard-approve-banner'),
              tone: Tone.info,
              icon: Icons.system_update_tv_rounded,
              text: 'The TV updated its software. Clean-up'
                  '${s.watchdogPending > 0 ? ' (${s.watchdogPending} '
                      'change${s.watchdogPending == 1 ? '' : 's'})' : ''} '
                  'is on hold until you approve.',
              action: FilledButton.tonal(
                key: const Key('tv-guard-approve'),
                onPressed: busy ? null : _approve,
                child: const Text('Approve this TV update'),
              ),
            ),
          ],
          if (s != null && s.clockSkewWarn) ...[
            const SizedBox(height: Gap.md),
            const _Banner(
              tone: Tone.warn,
              icon: Icons.schedule_rounded,
              text: 'The TV\'s clock is off by more than 2 minutes, so '
                  'TV time may start or end early.',
            ),
          ],
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              if (mode == AgentMode.normal)
                _CardButton(
                  key: const Key('tv-guard-pause'),
                  icon: Icons.pause_rounded,
                  label: 'Pause',
                  busy: _busy == 'paused',
                  onPressed: busy ? null : () => _mode(AgentMode.paused),
                )
              else if (mode != null)
                _CardButton(
                  key: const Key('tv-guard-resume'),
                  icon: Icons.play_arrow_rounded,
                  label: mode == AgentMode.safe ? 'Leave safe mode' : 'Resume',
                  filled: true,
                  busy: _busy == 'normal',
                  onPressed: busy ? null : () => _mode(AgentMode.normal),
                ),
              if (mode != null && mode != AgentMode.safe)
                _CardButton(
                  key: const Key('tv-guard-safe'),
                  icon: Icons.health_and_safety_outlined,
                  label: 'Safe mode',
                  busy: _busy == 'safe',
                  onPressed: busy ? null : () => _mode(AgentMode.safe),
                ),
              if (s != null)
                _CardButton(
                  key: const Key('tv-guard-checks'),
                  icon: Icons.fact_check_outlined,
                  label: 'Run checks now',
                  busy: _busy == 'checks',
                  onPressed: busy ? null : _runChecks,
                ),
              _CardButton(
                key: const Key('tv-guard-repair'),
                icon: Icons.build_rounded,
                label: 'Repair',
                filled: down,
                onPressed: busy
                    ? null
                    : () => runAgentSetup(context, ref, repair: true),
              ),
              _CardButton(
                key: const Key('tv-guard-uninstall'),
                icon: Icons.delete_outline_rounded,
                label: 'Uninstall',
                busy: _busy == 'uninstall',
                onPressed: busy ? null : _uninstall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _uptime(int sec) {
    if (sec < 3600) return '${(sec / 60).floor()} min';
    if (sec < 86400) return '${(sec / 3600).floor()} h';
    return '${(sec / 86400).floor()} days';
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onPressed;

  const _CardButton({
    super.key,
    required this.icon,
    required this.label,
    this.filled = false,
    this.busy = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final lead = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18);
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: Gap.md),
      ),
    );
    return filled
        ? FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: lead,
            label: Text(label),
          )
        : OutlinedButton.icon(
            style: style,
            onPressed: onPressed,
            icon: lead,
            label: Text(label),
          );
  }
}

class _Banner extends StatelessWidget {
  final Tone tone;
  final IconData icon;
  final String text;
  final Widget? action;

  const _Banner({
    super.key,
    required this.tone,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = tone.color(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: Radii.tile,
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: c),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: Gap.md),
            action!,
          ],
        ],
      ),
    );
  }
}

// ── install / repair stepper ──

Future<void> showAgentSetupSheet(
  BuildContext context, {
  required String title,
  required Stream<InstallProgress> Function() start,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => AgentSetupSheet(title: title, start: start),
    );

/// Live progress of an install or repair, step by step, with a "Look at
/// the TV" moment when the TV asks to allow TV Guard's own debugging.
class AgentSetupSheet extends StatefulWidget {
  final String title;
  final Stream<InstallProgress> Function() start;

  const AgentSetupSheet({super.key, required this.title, required this.start});

  @override
  State<AgentSetupSheet> createState() => _AgentSetupSheetState();
}

class _AgentSetupSheetState extends State<AgentSetupSheet> {
  StreamSubscription<InstallProgress>? _sub;
  InstallProgress? _p;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    _sub?.cancel();
    setState(() => _p = null);
    _sub = widget.start().listen((p) {
      if (mounted) setState(() => _p = p);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final text = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    final finished = p?.finished ?? false;
    final steps = p?.steps ?? const <InstallStep>[];
    final done = steps.where((s) => s.finished).length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      finished
                          ? (p!.ok ? 'TV Guard is ready' : 'Didn\'t finish')
                          : widget.title,
                      style: text.titleLarge,
                    ),
                  ),
                  if (!finished && steps.isNotEmpty)
                    Text('$done/${steps.length}', style: text.labelMedium),
                ],
              ),
              const SizedBox(height: Gap.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: steps.isEmpty ? null : done / steps.length,
                  color: finished && !(p?.ok ?? false) ? status.bad : null,
                ),
              ),
              if (p != null && p.awaitingApproval) ...[
                const SizedBox(height: Gap.lg),
                const _LookAtTv(),
              ],
              const SizedBox(height: Gap.md),
              InfoCard(
                padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                child: Column(
                  children: [
                    for (final s in steps) _StepRow(step: s),
                    if (steps.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(Gap.lg),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
              if (finished) ...[
                const SizedBox(height: Gap.lg),
                if (!p!.ok)
                  Text(
                    'Nothing was left half-done: you can try again, or '
                    'close and use Repair later.',
                    style: text.bodySmall,
                  ),
                if (p.ok)
                  Text(
                    'Rules you set on the Rules tab now run on the TV, '
                    'even when this phone is away.',
                    style: text.bodySmall,
                  ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    if (!p.ok) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('setup-retry'),
                          onPressed: _run,
                          child: const Text('Try again'),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                    ],
                    Expanded(
                      child: FilledButton(
                        key: const Key('setup-done'),
                        onPressed: () => Navigator.pop(context),
                        child: Text(p.ok ? 'Done' : 'Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LookAtTv extends StatelessWidget {
  const _LookAtTv();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final warn = StatusColors.of(context).warn;
    return InfoCard(
      key: const Key('setup-look-at-tv'),
      color: Color.alphaBlend(
        warn.withValues(alpha: 0.12),
        Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      borderColor: warn.withValues(alpha: 0.5),
      child: Row(
        children: [
          PulsingIcon(icon: Icons.tv_rounded, size: 36, color: warn),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Look at the TV', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'It asks "Allow USB debugging?" for TV Guard. Tick '
                  '"Always allow", then choose Allow.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final InstallStep step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final s = StatusColors.of(context);
    final text = Theme.of(context).textTheme;
    final Widget lead = switch (step.state) {
      SetupStepState.running => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      SetupStepState.pending =>
        Icon(Icons.radio_button_unchecked_rounded, color: s.idle, size: 22),
      SetupStepState.waiting => Icon(Icons.visibility_rounded, color: s.warn),
      SetupStepState.done => Icon(Icons.check_circle_rounded, color: s.ok),
      SetupStepState.warn => Icon(Icons.error_outline_rounded, color: s.warn),
      SetupStepState.failed => Icon(Icons.cancel_rounded, color: s.bad),
      SetupStepState.skipped =>
        Icon(Icons.remove_circle_outline_rounded, color: s.idle, size: 22),
    };
    final dim = step.state == SetupStepState.pending ||
        step.state == SetupStepState.skipped;
    return Padding(
      key: Key('step-${step.id.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Center(child: lead)),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: text.titleSmall?.copyWith(
                    color: dim
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                if (step.detail.isNotEmpty)
                  Text(
                    step.detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
