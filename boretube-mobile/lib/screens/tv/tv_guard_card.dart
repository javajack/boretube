import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../agent/agent_client.dart';
import '../../agent/agent_installer.dart';
import '../../providers/agent_providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/learn.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';
import '../../watch/always_on_alerts.dart';
import '../shell_screen.dart';

/// Always On in Better TV: a dark-ink card with its state and every
/// control, or the invitation to set it up.
class TvGuardCard extends ConsumerWidget {
  const TvGuardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(agentStatusProvider);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      child: link.installed
          ? _InstalledCard(key: const Key('tv-guard-installed'), link: link)
          : const _InstallInvite(key: Key('tv-guard-invite')),
    );
  }
}

/// Opens the install (or repair) stepper and refreshes Always On after.
Future<void> runAgentSetup(
  BuildContext context,
  WidgetRef ref, {
  required bool repair,
}) async {
  final installer = await ref.read(agentInstallerProvider.future);
  if (!context.mounted) return;
  if (installer == null) {
    showStatusSnack(context, 'Unlock Home mode first', ok: false);
    return;
  }
  await showAgentSetupSheet(
    context,
    title: repair ? 'Repairing Always On' : 'Setting up Always On',
    start: repair ? installer.repair : installer.install,
  );
  ref.invalidate(agentTokenProvider);
  ref.invalidate(journalEntriesProvider);
  ref.invalidate(agentJournalProvider);
  await ref.read(agentStatusProvider.notifier).refresh();
  if (!repair && ref.read(agentStatusProvider).installed && context.mounted) {
    await enableAlertsAfterInstall(context, ref);
  }
}

/// The dark surface the Always On card sits on (navy in both themes).
Color _cardInk(BtColors bt) => bt.screen;

const _onInk = Color(0xFFFFFFFF);
const _onInkSoft = Color(0xFFB9BAD6);
const _inkButton = Color(0xFF2A2B4D);
const _inkButtonBorder = Color(0xFF3B3C60);

class _DarkCard extends StatelessWidget {
  final Widget child;
  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Container(
      decoration: BoxDecoration(
        color: _cardInk(bt),
        borderRadius: Radii.hero,
        border: Border.all(color: _inkButtonBorder.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: _onInk,
                displayColor: _onInk,
              ),
        ),
        child: child,
      ),
    );
  }
}

class _InstallInvite extends ConsumerWidget {
  const _InstallInvite({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final bundle = ref.watch(agentBundleProvider);
    final missing = bundle.hasValue && bundle.value == null;
    final hasAdb = ref.watch(activeHasAdbProvider);
    const points = [
      (Icons.nights_stay_rounded, 'Bedtime runs even when you\'re out'),
      (Icons.rule_rounded, 'Daily TV time, apps and volume, kept by the TV'),
      (Icons.healing_rounded, 'Tidies up again after TV updates'),
    ];
    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Tubby(
                mood: TubbyMood.guard,
                size: 52,
                animate: false,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TermTitle(
                      'Always On',
                      LearnTerm.alwaysOn,
                      style: text.titleMedium!.copyWith(
                        color: _onInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      dotColor: _onInkSoft,
                    ),
                    Text(
                      'Not set up · optional',
                      style: text.bodySmall!.copyWith(color: _onInkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final (icon, line) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF7FDDBE)),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      line,
                      style: text.bodyMedium!.copyWith(
                        color: _onInk,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Gap.sm),
          PrimaryButton(
            key: const Key('tv-guard-install'),
            label: hasAdb ? 'Make it Always On' : 'Unlock Home mode first',
            icon: hasAdb ? Icons.shield_rounded : Icons.home_rounded,
            kind: ButtonKind.mint,
            onPressed: missing
                ? null
                : hasAdb
                    ? () => runAgentSetup(context, ref, repair: false)
                    : () => context.push('/adb-guide'),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            missing
                ? AgentBundleMissing.message
                : 'About a minute, one OK on the TV. Remove it any time; the '
                    'TV keeps working without it.',
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(color: _onInkSoft),
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

  Future<void> _do(
    String what,
    Future<void> Function(AgentClient c) f, {
    String? done,
  }) async {
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
          title: 'Hands off for now?',
          message: 'Always On stops enforcing routines and changes nothing '
              'on the TV. It keeps watching and reporting, so you can see '
              'what it would do. Turn it back on here any time.',
          confirmLabel: 'Hands off',
          icon: Icons.back_hand_rounded,
        )) {
      return;
    }
    await _do(
      m.name,
      (c) => c.setMode(m),
      done: switch (m) {
        AgentMode.normal => 'Always On is back on',
        AgentMode.paused => 'Always On paused',
        AgentMode.safe => 'Hands off: watching only',
      },
    );
  }

  Future<void> _approve() async {
    final fp = widget.link.status?.buildFingerprint ?? '';
    final ok = await confirmAction(
      context,
      title: 'Does the TV work normally?',
      message: 'Your TV installed a software update. Always On waits to '
          'tidy up until you say the TV still works as it should.'
          '${fp.isEmpty ? '' : '\n\n$fp'}',
      confirmLabel: 'Yes, approve',
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
    await showBtSheet<void>(
      context,
      builder: (sheet) => SheetScaffold(
        key: const Key('tv-guard-report'),
        title: r.ok ? 'All checked' : 'Checked, with notes',
        lead: Text(
          r.detail.isNotEmpty
              ? r.detail
              : r.lines.isEmpty
                  ? 'Everything checked out. Nothing needed changing.'
                  : '${r.lines.length} things looked at.',
        ),
        children: [
          if (r.lines.isNotEmpty)
            InfoCard(
              child: Column(
                children: [
                  for (final l in r.lines) CheckLine(l, done: r.ok),
                ],
              ),
            ),
          const SizedBox(height: Gap.lg),
          PrimaryButton(
            label: 'Done',
            kind: ButtonKind.ink,
            onPressed: () => Navigator.pop(sheet),
          ),
        ],
      ),
    );
  }

  Future<void> _uninstall() async {
    final ok = await confirmAction(
      context,
      title: 'Remove Always On?',
      message: 'Routines, breaks and tidy-ups stop on the TV. Nothing else '
          'changes; the TV keeps working normally. You can set it up again '
          'later.',
      confirmLabel: 'Remove',
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
        done
            ? 'Always On removed'
            : 'Couldn\'t remove Always On. It needs Home mode.',
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
    final bt = context.bt;
    final state = guardStateOf(link: link, onBreak: false, classic: false);
    final (label, tone) = guardLook(state);
    final down = state == GuardState.down;
    final mode = s?.mode;
    final busy = _busy != null;
    final (tileColor, tileIcon) = switch (state) {
      GuardState.down => (bt.berry, Icons.gpp_bad_rounded),
      GuardState.safe => (bt.sky, Icons.back_hand_rounded),
      GuardState.paused => (bt.sun, Icons.pause_rounded),
      GuardState.limited => (bt.sun, Icons.gpp_maybe_rounded),
      GuardState.checking => (_inkButtonBorder, Icons.shield_outlined),
      _ => (bt.mint, Icons.verified_user_rounded),
    };
    final line = s == null
        ? (down
            ? link.kind == AgentLinkKind.authFailed
                ? 'Doesn\'t recognise this phone'
                : 'Not answering'
            : 'Checking…')
        : switch (state) {
            GuardState.on || GuardState.onBreak => 'Guarding your routines · '
                'up ${_uptime(s.uptimeSec)}',
            GuardState.paused => 'Paused by you · routines on hold',
            GuardState.safe => 'Hands off · watching, changing nothing',
            GuardState.limited => 'Running, but can\'t close apps yet',
            _ => label,
          };

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: Radii.tile,
                ),
                child: Icon(
                  tileIcon,
                  color: const Color(0xFF0B0C1E),
                  size: 24,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TermTitle(
                      'Always On',
                      LearnTerm.alwaysOn,
                      style: text.titleMedium!.copyWith(
                        color: _onInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      dotColor: _onInkSoft,
                    ),
                    Text(
                      line,
                      key: const Key('tv-guard-line'),
                      style: text.bodySmall!.copyWith(
                        color: state == GuardState.on
                            ? const Color(0xFFB7F0DC)
                            : _onInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              _InkBadge(
                label: state == GuardState.on ? 'On' : label,
                tone: tone,
              ),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                _fact(
                  context,
                  'Routines',
                  switch (s.mode) {
                    AgentMode.normal => 'Enforcing',
                    AgentMode.paused => 'Paused',
                    AgentMode.safe => 'Hands off',
                  },
                ),
                _fact(
                  context,
                  'Close apps',
                  switch (s.selfAdb) {
                    SelfAdb.ok => 'Allowed',
                    SelfAdb.needsApproval => 'Needs OK',
                    SelfAdb.unavailable => 'Off',
                    SelfAdb.unknown => '—',
                  },
                ),
                _fact(context, 'Version', s.version),
              ],
            ),
          ],
          if (down) ...[
            const SizedBox(height: Gap.lg),
            _InkNote(
              key: const Key('tv-guard-down'),
              color: bt.berry,
              icon: Icons.portable_wifi_off_rounded,
              text: link.kind == AgentLinkKind.authFailed
                  ? 'Always On doesn\'t recognise this phone any more. Repair '
                      'pairs them again.'
                  : 'Always On isn\'t answering, so routines may not be '
                      'running. Repair usually fixes it.',
            ),
          ],
          if (s != null && s.selfAdb == SelfAdb.needsApproval) ...[
            const SizedBox(height: Gap.md),
            _InkNote(
              color: bt.sun,
              icon: Icons.tv_rounded,
              text: 'Look at your TV and choose "Always allow" so Always On '
                  'can close apps. Tap Repair if the prompt is gone.',
            ),
          ] else if (s != null && s.isLimited) ...[
            const SizedBox(height: Gap.md),
            _InkNote(
              key: const Key('tv-guard-limited'),
              color: bt.sun,
              icon: Icons.gpp_maybe_rounded,
              text: s.limitedReasons.isEmpty
                  ? 'Always On can\'t do everything yet. Repair may fix it.'
                  : 'Not everything works yet: '
                      '${s.limitedReasons.join(' · ')}'
                      '${s.needsPhoneGrant ? '. Repair gives it the missing '
                          'permission.' : ''}',
            ),
          ],
          if (s != null && s.activeReasons.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Row(
              key: const Key('tv-guard-active'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Color(0xFF7FDDBE),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Right now: ${s.activeReasons.join(' · ')}',
                    style: text.bodySmall!.copyWith(color: _onInkSoft),
                  ),
                ),
              ],
            ),
          ],
          if (s != null && s.buildChangedSinceApproval) ...[
            const SizedBox(height: Gap.md),
            _InkNote(
              key: const Key('tv-guard-approve-banner'),
              color: bt.sky,
              icon: Icons.system_update_tv_rounded,
              text: 'Your TV installed an update. Tidying up'
                  '${s.watchdogPending > 0 ? ' (${s.watchdogPending} '
                      'change${s.watchdogPending == 1 ? '' : 's'})' : ''} '
                  'waits until you approve.',
              action: PrimaryButton(
                key: const Key('tv-guard-approve'),
                label: 'Approve update',
                kind: ButtonKind.mint,
                height: 48,
                onPressed: busy ? null : _approve,
              ),
            ),
          ],
          if (s != null && s.clockSkewWarn) ...[
            const SizedBox(height: Gap.md),
            _InkNote(
              color: bt.sun,
              icon: Icons.schedule_rounded,
              text: 'The TV\'s clock is more than 2 minutes off, so TV time '
                  'may start or end early.',
            ),
          ],
          const SizedBox(height: Gap.lg),
          LayoutBuilder(
            builder: (context, c) {
              final buttons = <Widget>[
                if (mode == AgentMode.normal)
                  _InkButton(
                    key: const Key('tv-guard-pause'),
                    icon: Icons.pause_rounded,
                    label: 'Pause',
                    busy: _busy == 'paused',
                    onPressed: busy ? null : () => _mode(AgentMode.paused),
                  )
                else if (mode != null)
                  _InkButton(
                    key: const Key('tv-guard-resume'),
                    icon: Icons.play_arrow_rounded,
                    label: mode == AgentMode.safe ? 'Turn back on' : 'Resume',
                    highlight: true,
                    busy: _busy == 'normal',
                    onPressed: busy ? null : () => _mode(AgentMode.normal),
                  ),
                if (s != null)
                  _InkButton(
                    key: const Key('tv-guard-checks'),
                    icon: Icons.fact_check_rounded,
                    label: 'Check now',
                    busy: _busy == 'checks',
                    onPressed: busy ? null : _runChecks,
                  ),
                if (mode != null && mode != AgentMode.safe)
                  _InkButton(
                    key: const Key('tv-guard-safe'),
                    icon: Icons.back_hand_rounded,
                    label: 'Hands off for now',
                    busy: _busy == 'safe',
                    onPressed: busy ? null : () => _mode(AgentMode.safe),
                  ),
                _InkButton(
                  key: const Key('tv-guard-repair'),
                  icon: Icons.build_rounded,
                  label: 'Repair',
                  highlight: down,
                  onPressed: busy
                      ? null
                      : () => runAgentSetup(context, ref, repair: true),
                ),
              ];
              final w = (c.maxWidth - Gap.sm) / 2;
              return Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final b in buttons) SizedBox(width: w, child: b),
                ],
              );
            },
          ),
          const SizedBox(height: Gap.xs),
          Align(
            child: TextButton.icon(
              key: const Key('tv-guard-uninstall'),
              style: TextButton.styleFrom(foregroundColor: _onInkSoft),
              onPressed: busy ? null : _uninstall,
              icon: _busy == 'uninstall'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _onInkSoft,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove Always On'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, String k, String v) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall!.copyWith(
                color: _onInkSoft,
                letterSpacing: 1,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(color: _onInk),
            ),
          ],
        ),
      ),
    );
  }

  static String _uptime(int sec) {
    if (sec < 3600) return '${(sec / 60).floor()} min';
    if (sec < 86400) return '${(sec / 3600).floor()} h';
    return '${(sec / 86400).floor()} days';
  }
}

class _InkBadge extends StatelessWidget {
  final String label;
  final Tone tone;
  const _InkBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final hue = tone == Tone.idle ? _onInkSoft : tone.hue(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: hue.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontSize: 12,
                  color: _onInk,
                ),
          ),
        ],
      ),
    );
  }
}

class _InkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final bool highlight;
  final VoidCallback? onPressed;

  const _InkButton({
    super.key,
    required this.icon,
    required this.label,
    this.busy = false,
    this.highlight = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final fg = highlight ? const Color(0xFF06392A) : _onInk;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !busy ? 0.5 : 1,
        child: Material(
          color: highlight ? bt.mint : _inkButton,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.buttons,
            side: BorderSide(
              color: highlight ? bt.mint : _inkButtonBorder,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: Gap.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          )
                        : Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              fontSize: 13.5,
                              color: fg,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkNote extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;

  const _InkNote({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: Radii.tile,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: _onInk,
                        fontSize: 14,
                      ),
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
      useSafeArea: true,
      builder: (_) => AgentSetupSheet(title: title, start: start),
    );

/// Step titles in parent words (the installer's own say "TV Guard").
String setupStepTitle(InstallStepId id) => switch (id) {
      InstallStepId.diagnose => 'Look for Always On',
      InstallStepId.verify => 'Check the download',
      InstallStepId.push => 'Copy it to the TV',
      InstallStepId.install => 'Install it',
      InstallStepId.enable => 'Switch it back on',
      InstallStepId.grant => 'Give it permission',
      InstallStepId.start => 'Start it',
      InstallStepId.token => 'Pair it with this phone',
      InstallStepId.approve => 'OK it on the TV',
      InstallStepId.profile => 'Send your TV\'s settings',
      InstallStepId.check => 'Final check',
    };

/// Live progress of an install or repair, step by step, with a "Look at
/// your TV" moment when the TV asks to allow Always On.
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
      if (!mounted) return;
      if (p.finished && !(_p?.finished ?? false)) {
        unawaited(
          p.ok ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact(),
        );
      }
      setState(() => _p = p);
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
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final finished = p?.finished ?? false;
    final ok = p?.ok ?? false;
    final steps = p?.steps ?? const <InstallStep>[];
    final done = steps.where((s) => s.finished).length;
    return ConstrainedBox(
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
                if (finished) ...[
                  Tubby(
                    mood: ok ? TubbyMood.guard : TubbyMood.calm,
                    size: 44,
                    beaming: ok,
                    animate: false,
                  ),
                  const SizedBox(width: Gap.md),
                ],
                Expanded(
                  child: Text(
                    finished
                        ? (ok ? 'Always On is ready' : 'Didn\'t finish')
                        : widget.title,
                    style: text.headlineMedium,
                  ),
                ),
                if (!finished && steps.isNotEmpty)
                  Text(
                    '$done/${steps.length}',
                    style: Fonts.bricolage(
                      18,
                      color: bt.muted,
                      tabularFigures: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  end: steps.isEmpty ? 0 : done / steps.length,
                ),
                duration: Motion.of(context, Motion.slow),
                curve: Motion.settle,
                builder: (context, v, _) => LinearProgressIndicator(
                  minHeight: 6,
                  value: steps.isEmpty ? null : v,
                  color: finished && !ok ? bt.berry : bt.mint,
                  backgroundColor: bt.hairline,
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.settle,
              child: p != null && p.awaitingApproval
                  ? const Padding(
                      padding: EdgeInsets.only(top: Gap.lg),
                      child: _LookAtTv(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
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
              Text(
                ok
                    ? 'Your routines now run on the TV, even when this phone '
                        'is away.'
                    : 'Nothing was left half-done. Try again, or close and '
                        'use Repair later.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  if (!ok) ...[
                    Expanded(
                      child: PrimaryButton(
                        key: const Key('setup-retry'),
                        label: 'Try again',
                        kind: ButtonKind.outline,
                        onPressed: _run,
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('setup-done'),
                      label: ok ? 'Done' : 'Close',
                      kind: ok ? ButtonKind.mint : ButtonKind.ink,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
    final bt = context.bt;
    return Container(
      key: const Key('setup-look-at-tv'),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: bt.sunTint,
        borderRadius: Radii.card,
        border: Border.all(color: bt.sun.withValues(alpha: 0.6)),
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            PulsingIcon(icon: Icons.tv_rounded, size: 40, color: bt.sunInk),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Look at your TV', style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'It asks "Allow USB debugging?". Tick "Always allow", '
                    'then choose Allow.',
                    style: text.bodyMedium!.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final Widget lead = switch (step.state) {
      SetupStepState.running => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: bt.sky),
        ),
      SetupStepState.pending =>
        Icon(Icons.radio_button_unchecked_rounded, color: bt.faint, size: 20),
      SetupStepState.waiting => Icon(Icons.visibility_rounded, color: s.warn),
      SetupStepState.done => Icon(Icons.check_circle_rounded, color: bt.mint),
      SetupStepState.warn => Icon(Icons.error_rounded, color: bt.sun),
      SetupStepState.failed => Icon(Icons.cancel_rounded, color: bt.berry),
      SetupStepState.skipped =>
        Icon(Icons.remove_circle_outline_rounded, color: bt.faint, size: 20),
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
          SizedBox(
            width: 24,
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: KeyedSubtree(key: ValueKey(step.state), child: lead),
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setupStepTitle(step.id),
                  style: text.titleSmall!.copyWith(
                    color: dim ? bt.muted : bt.ink,
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
