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
      duration: Motion.of(context, Motion.sheet),
      child: link.installed
          ? _InstalledCard(key: const Key('tv-guard-installed'), link: link)
          : const _InstallInvite(key: Key('tv-guard-invite')),
    );
  }
}

/// Opens the install (or repair, or [update]) stepper and refreshes
/// Always On after.
Future<void> runAgentSetup(
  BuildContext context,
  WidgetRef ref, {
  required bool repair,
  bool update = false,
}) async {
  final installer = await ref.read(agentInstallerProvider.future);
  if (!context.mounted) return;
  if (installer == null) {
    showStatusSnack(context, 'Unlock Home mode first', ok: false);
    return;
  }
  await showAgentSetupSheet(
    context,
    title: update
        ? 'Updating Always On'
        : repair
            ? ref.read(agentUpdateProvider) != null
                ? 'Repairing and updating Always On'
                : 'Repairing Always On'
            : 'Setting up Always On',
    start: update
        ? installer.update
        : repair
            ? installer.repair
            : installer.install,
    doneLine: update
        ? 'Always On is up to date. Your routines kept running the whole '
            'time.'
        : null,
  );
  ref.invalidate(agentTokenProvider);
  ref.invalidate(journalEntriesProvider);
  ref.invalidate(agentJournalProvider);
  await ref.read(agentStatusProvider.notifier).refresh();
  if (!repair &&
      !update &&
      ref.read(agentStatusProvider).installed &&
      context.mounted) {
    await enableAlertsAfterInstall(context, ref);
  }
}

/// White text on the navy Always On surface (the same in both themes).
const _onInk = Color(0xFFFFFFFF);
const _onInkSoft = Color(0xFFB9BAD6);
const _onInkOk = Color(0xFF7FDDBE);
const _inkButton = Color(0xFF2A2B4D);
const _inkButtonBorder = Color(0xFF3B3C60);

/// The one card on Better TV: the navy Always On surface.
class _InkSurface extends StatelessWidget {
  final Widget child;
  const _InkSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Surface(
      color: bt.screen,
      borderColor: _inkButtonBorder,
      radius: Radii.hero,
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

/// Icon tile, "Always On" with its learn dot, and the state line.
class _InkHeader extends StatelessWidget {
  final Widget lead;
  final String line;
  final Color lineColor;

  const _InkHeader({
    required this.lead,
    required this.line,
    this.lineColor = _onInkSoft,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        lead,
        const SizedBox(width: Gap.inside),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TermTitle(
                'Always On',
                LearnTerm.alwaysOn,
                style: Fonts.bricolage(
                  TypeSize.headline,
                  weight: FontWeight.w700,
                  height: TypeSize.tightLeading,
                  color: _onInk,
                ),
                dotColor: _onInkSoft,
              ),
              const SizedBox(height: Gap.f4),
              Text(
                line,
                key: const Key('tv-guard-line'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: lineColor),
              ),
            ],
          ),
        ),
      ],
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
    return _InkSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InkHeader(
            lead: Tubby(
              mood: TubbyMood.guard,
              size: Sizes.avatar,
              animate: false,
            ),
            line: 'Not set up · optional',
          ),
          const SizedBox(height: Gap.inside),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your routines run on the TV, even when you\'re out.',
                  style: text.bodySmall!.copyWith(color: _onInk),
                ),
              ),
              const InfoButton(
                color: _onInkSoft,
                title: 'What Always On does',
                body: 'Always On is a small helper on the TV. Bedtime runs '
                    'even when you\'re out, and daily TV time, apps and '
                    'volume are kept by the TV itself. It tidies up again '
                    'after TV updates.\n\nIt takes about a minute and one OK '
                    'on the TV. Remove it any time; the TV keeps working '
                    'without it.',
              ),
            ],
          ),
          const SizedBox(height: Gap.inside),
          if (hasAdb)
            PrimaryButton(
              key: const Key('tv-guard-install'),
              label: 'Make it Always On',
              icon: Icons.shield_rounded,
              kind: ButtonKind.mint,
              onPressed: missing
                  ? null
                  : () => runAgentSetup(context, ref, repair: false),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('tv-guard-install'),
                style: TextButton.styleFrom(foregroundColor: _onInkOk),
                onPressed: () => context.push('/adb-guide'),
                icon: const Icon(Icons.home_rounded, size: Sizes.icon),
                label: const Text('Unlock Home mode first'),
              ),
            ),
          if (missing) ...[
            const SizedBox(height: Gap.f8),
            Text(
              AgentBundleMissing.message,
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: _onInkSoft),
            ),
          ],
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
            RowList(
              children: [
                for (final l in r.lines)
                  CheckLine(l, done: r.ok, minHeight: Sizes.control),
              ],
            ),
          const SizedBox(height: Gap.related),
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

  /// Closes the More sheet, then runs [f].
  VoidCallback _fromSheet(BuildContext sheet, VoidCallback f) => () {
        Navigator.pop(sheet);
        f();
      };

  Future<void> _more(String line) {
    final s = widget.link.status;
    final mode = s?.mode;
    return showBtSheet<void>(
      context,
      builder: (sheet) => SheetScaffold(
        key: const Key('tv-guard-more-sheet'),
        title: 'Always On',
        lead: Text(line),
        children: [
          if (s != null) ...[
            RowList(
              children: [
                ListRow(
                  icon: Icons.rule_rounded,
                  title: 'Routines',
                  value: switch (s.mode) {
                    AgentMode.normal => 'Running',
                    AgentMode.paused => 'Paused',
                    AgentMode.safe => 'Hands off',
                  },
                ),
                ListRow(
                  icon: Icons.close_rounded,
                  title: 'Can close apps',
                  value: switch (s.selfAdb) {
                    SelfAdb.ok => 'Yes',
                    SelfAdb.needsApproval => 'Needs an OK',
                    SelfAdb.unavailable => 'No',
                    SelfAdb.unknown => '—',
                  },
                ),
                ListRow(
                  icon: Icons.info_outline_rounded,
                  title: 'Version',
                  value: s.version,
                ),
              ],
            ),
            const SizedBox(height: Gap.related),
          ],
          RowList(
            edges: s != null,
            children: [
              if (mode != null && mode != AgentMode.safe)
                ListRow(
                  key: const Key('tv-guard-safe'),
                  icon: Icons.back_hand_rounded,
                  title: 'Hands off for now',
                  subtitle: 'Watches and reports, changes nothing',
                  chevron: false,
                  onTap: _fromSheet(sheet, () => _mode(AgentMode.safe)),
                ),
              if (mode != null)
                ListRow(
                  key: const Key('tv-guard-repair'),
                  icon: Icons.build_rounded,
                  title: 'Repair',
                  subtitle: 'Pairs it again and fixes permissions',
                  chevron: false,
                  onTap: _fromSheet(
                    sheet,
                    () => runAgentSetup(context, ref, repair: true),
                  ),
                ),
              ListRow(
                key: const Key('tv-guard-uninstall'),
                icon: Icons.delete_outline_rounded,
                iconColor: StatusColors.of(context).bad,
                title: 'Remove Always On',
                subtitle: 'The TV keeps working without it',
                chevron: false,
                onTap: _fromSheet(sheet, _uninstall),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final s = link.status;
    final bt = context.bt;
    final state = guardStateOf(link: link, onBreak: false, classic: false);
    final (label, _) = guardLook(state);
    final down = state == GuardState.down;
    final mode = s?.mode;
    final busy = _busy != null;
    final update = ref.watch(agentUpdateProvider);
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
    final oldMedia = s != null &&
        update != null &&
        compareVersions(s.version, '1.1.0') < 0 &&
        compareVersions(update.versionName, '1.1.0') >= 0;

    final notes = <Widget>[
      if (down)
        _InkLine(
          key: const Key('tv-guard-down'),
          color: bt.berry,
          icon: Icons.portable_wifi_off_rounded,
          text: link.kind == AgentLinkKind.authFailed
              ? 'It doesn\'t recognise this phone. Repair pairs them again.'
              : 'Routines may not be running. Repair usually fixes it.',
        ),
      if (s != null && s.selfAdb == SelfAdb.needsApproval)
        _InkLine(
          color: bt.sun,
          icon: Icons.tv_rounded,
          text: 'On the TV, choose "Always allow" so it can close apps.',
        )
      else if (s != null && s.isLimited)
        _InkLine(
          key: const Key('tv-guard-limited'),
          color: bt.sun,
          icon: Icons.gpp_maybe_rounded,
          text: s.limitedReasons.isEmpty
              ? 'It can\'t do everything yet. Repair may fix it.'
              : 'Not yet: ${s.limitedReasons.join(' · ')}',
        ),
      if (s != null && s.activeReasons.isNotEmpty)
        _InkLine(
          key: const Key('tv-guard-active'),
          color: _onInkOk,
          icon: Icons.bolt_rounded,
          text: 'Right now: ${s.activeReasons.join(' · ')}',
        ),
      if (s != null && s.clockSkewWarn)
        _InkLine(
          color: bt.sun,
          icon: Icons.schedule_rounded,
          text: 'The TV\'s clock is over 2 minutes off.',
        ),
      if (s != null && update != null && !down)
        _InkLine(
          key: const Key('tv-guard-update-note'),
          color: bt.mint,
          icon: Icons.new_releases_rounded,
          text: 'A newer Always On is ready (${update.versionName})',
          info: InfoButton(
            color: _onInkSoft,
            title: 'Update Always On',
            body: '${oldMedia ? 'The new one can pause after the video '
                    'that\'s on, and keep Shorts in check. ' : ''}'
                'It takes about a minute, and your routines keep running.',
          ),
          action: PrimaryButton(
            key: const Key('tv-guard-update'),
            label: 'Update Always On',
            icon: Icons.system_update_alt_rounded,
            kind: ButtonKind.mint,
            onPressed: busy || !ref.watch(activeHasAdbProvider)
                ? null
                : () => runAgentSetup(
                      context,
                      ref,
                      repair: true,
                      update: true,
                    ),
          ),
        ),
      if (s != null && s.buildChangedSinceApproval)
        _InkLine(
          key: const Key('tv-guard-approve-banner'),
          color: bt.sky,
          icon: Icons.system_update_tv_rounded,
          text: 'Your TV updated. Tidying up'
              '${s.watchdogPending > 0 ? ' (${s.watchdogPending} '
                  'change${s.watchdogPending == 1 ? '' : 's'})' : ''} '
              'waits for your OK.',
          action: PrimaryButton(
            key: const Key('tv-guard-approve'),
            label: 'Approve update',
            kind: ButtonKind.mint,
            onPressed: busy ? null : _approve,
          ),
        ),
    ];

    final buttons = <Widget>[
      if (mode == AgentMode.normal)
        _InkButton(
          key: const Key('tv-guard-pause'),
          label: 'Pause',
          busy: _busy == 'paused',
          onPressed: busy ? null : () => _mode(AgentMode.paused),
        )
      else if (mode != null)
        _InkButton(
          key: const Key('tv-guard-resume'),
          label: mode == AgentMode.safe ? 'Turn back on' : 'Resume',
          highlight: true,
          busy: _busy == 'normal',
          onPressed: busy ? null : () => _mode(AgentMode.normal),
        )
      else
        _InkButton(
          key: const Key('tv-guard-repair'),
          label: 'Repair',
          highlight: down,
          onPressed:
              busy ? null : () => runAgentSetup(context, ref, repair: true),
        ),
      if (s != null)
        _InkButton(
          key: const Key('tv-guard-checks'),
          label: 'Check now',
          busy: _busy == 'checks',
          onPressed: busy ? null : _runChecks,
        ),
      _InkButton(
        key: const Key('tv-guard-more'),
        label: 'More',
        icon: Icons.more_horiz_rounded,
        busy: _busy == 'uninstall' || _busy == 'safe',
        onPressed: busy ? null : () => _more(line),
      ),
    ];

    return _InkSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InkHeader(
            lead: AnimatedContainer(
              duration: Motion.of(context, Motion.flip),
              width: Sizes.avatar,
              height: Sizes.avatar,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: Radii.control,
              ),
              child: Icon(
                tileIcon,
                color: bt.screen,
                size: Sizes.iconControl,
              ),
            ),
            line: line,
            lineColor: state == GuardState.on ? _onInkOk : _onInkSoft,
          ),
          for (final n in notes) ...[
            const SizedBox(height: Gap.inside),
            n,
          ],
          const SizedBox(height: Gap.related),
          ChipRow(children: buttons),
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

/// A 44 secondary on the navy surface; the highlighted one is mint.
class _InkButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool busy;
  final bool highlight;
  final VoidCallback? onPressed;

  const _InkButton({
    super.key,
    required this.label,
    this.icon,
    this.busy = false,
    this.highlight = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final fg = highlight ? const Color(0xFF06392A) : _onInk;
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        enabled: onPressed != null,
        child: AnimatedOpacity(
          opacity: onPressed == null && !busy ? 0.5 : 1,
          duration: Motion.of(context, Motion.flip),
          child: Material(
            color: highlight ? bt.mint : _inkButton,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.control,
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
                constraints: const BoxConstraints(minHeight: Sizes.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.f4),
                  child: Center(
                    child: busy
                        ? SizedBox.square(
                            dimension: Sizes.iconSmall,
                            child: CircularProgressIndicator(
                              strokeWidth: Sizes.focus,
                              color: fg,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                              if (icon != null) ...[
                                const SizedBox(width: Gap.f4),
                                Icon(icon, size: Sizes.iconSmall, color: fg),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of state on the navy surface (an icon in its hue, white
/// text), with an optional ⓘ and at most one button under it.
class _InkLine extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Widget? info;
  final Widget? action;

  const _InkLine({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.info,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: Sizes.avatar,
              child: Icon(icon, size: Sizes.icon, color: color),
            ),
            const SizedBox(width: Gap.inside),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall!.copyWith(color: _onInk),
              ),
            ),
            if (info != null) info!,
          ],
        ),
        if (action != null) ...[
          const SizedBox(height: Gap.f8),
          action!,
        ],
      ],
    );
  }
}

// ── install / repair stepper ──

Future<void> showAgentSetupSheet(
  BuildContext context, {
  required String title,
  required Stream<InstallProgress> Function() start,
  String? doneLine,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: Motion.of(context, Motion.sheet),
        reverseDuration: Motion.of(context, Motion.flip),
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      ),
      builder: (_) =>
          AgentSetupSheet(title: title, start: start, doneLine: doneLine),
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

  /// What to say once it worked (defaults to the install line).
  final String? doneLine;

  const AgentSetupSheet({
    super.key,
    required this.title,
    required this.start,
    this.doneLine,
  });

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
        padding: const EdgeInsets.fromLTRB(
          Gap.gutter,
          Gap.related,
          Gap.gutter,
          Gap.related,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (finished) ...[
                  Tubby(
                    mood: ok ? TubbyMood.guard : TubbyMood.calm,
                    size: Sizes.avatar,
                    beaming: ok,
                    animate: false,
                  ),
                  const SizedBox(width: Gap.inside),
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
                      TypeSize.headline,
                      weight: FontWeight.w700,
                      color: bt.muted,
                      tabularFigures: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.inside),
            if (steps.isEmpty && !finished)
              ClipRRect(
                borderRadius: Radii.chip,
                child: LinearProgressIndicator(
                  minHeight: Sizes.bar,
                  color: bt.mint,
                  backgroundColor: bt.wash,
                ),
              )
            else
              ThinProgress(
                value: steps.isEmpty ? 0 : done / steps.length,
                color: finished && !ok ? bt.berry : bt.mint,
              ),
            AnimatedSize(
              duration: Motion.of(context, Motion.sheet),
              curve: Motion.enter,
              child: p != null && p.awaitingApproval
                  ? const Padding(
                      padding: EdgeInsets.only(top: Gap.related),
                      child: _LookAtTv(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: Gap.inside),
            RowList(
              children: [for (final s in steps) _StepRow(step: s)],
            ),
            if (finished) ...[
              const SizedBox(height: Gap.related),
              Text(
                ok
                    ? widget.doneLine ??
                        'Your routines now run on the TV, even when this '
                            'phone is away.'
                    : 'Nothing was left half-done. Try again, or use Repair '
                        'later.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Gap.related),
              if (ok)
                PrimaryButton(
                  key: const Key('setup-done'),
                  label: 'Done',
                  onPressed: () => Navigator.pop(context),
                )
              else ...[
                PrimaryButton(
                  key: const Key('setup-retry'),
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: _run,
                ),
                const SizedBox(height: Gap.f8),
                Center(
                  child: TextButton(
                    key: const Key('setup-done'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The TV is asking: a sunflower tint with the TV icon breathing.
class _LookAtTv extends StatelessWidget {
  const _LookAtTv();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    return Material(
      key: const Key('setup-look-at-tv'),
      color: bt.sunTint,
      borderRadius: Radii.control,
      child: Padding(
        padding: const EdgeInsets.all(Gap.inside),
        child: Semantics(
          liveRegion: true,
          child: Row(
            children: [
              PulsingIcon(
                icon: Icons.tv_rounded,
                size: Sizes.control,
                color: bt.sunInk,
              ),
              const SizedBox(width: Gap.inside),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Look at your TV', style: text.titleLarge),
                    const SizedBox(height: Gap.f4),
                    Text(
                      'Tick "Always allow", then choose Allow.',
                      style: text.bodySmall!.copyWith(color: bt.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final Widget lead = switch (step.state) {
      SetupStepState.running => SizedBox.square(
          dimension: Sizes.iconSmall,
          child: CircularProgressIndicator(
            strokeWidth: Sizes.focus,
            color: bt.sky,
          ),
        ),
      SetupStepState.pending => Icon(
          Icons.radio_button_unchecked_rounded,
          color: bt.faint,
          size: Sizes.icon,
        ),
      SetupStepState.waiting =>
        Icon(Icons.visibility_rounded, color: s.warn, size: Sizes.icon),
      SetupStepState.done =>
        Icon(Icons.check_circle_rounded, color: bt.mint, size: Sizes.icon),
      SetupStepState.warn =>
        Icon(Icons.error_rounded, color: bt.sun, size: Sizes.icon),
      SetupStepState.failed =>
        Icon(Icons.cancel_rounded, color: bt.berry, size: Sizes.icon),
      SetupStepState.skipped => Icon(
          Icons.remove_circle_outline_rounded,
          color: bt.faint,
          size: Sizes.icon,
        ),
    };
    final dim = step.state == SetupStepState.pending ||
        step.state == SetupStepState.skipped;
    return ListRow(
      key: Key('step-${step.id.name}'),
      leading: AnimatedSwitcher(
        duration: Motion.of(context, Motion.flip),
        child: KeyedSubtree(key: ValueKey(step.state), child: lead),
      ),
      title: setupStepTitle(step.id),
      subtitle: step.detail,
      dim: dim,
      chevron: false,
    );
  }
}
