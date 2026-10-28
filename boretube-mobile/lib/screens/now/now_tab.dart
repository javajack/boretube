import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../actions/actions_service.dart';
import '../../ops/journal.dart';
import '../../providers/break_provider.dart';
import '../../providers/now_playing.dart';
import '../../providers/tv_providers.dart';
import '../../tv/tv.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import 'classic_lock_card.dart';
import 'quick_actions.dart';

class NowTab extends ConsumerWidget {
  const NowTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = ref.watch(activeTvProvider);
    if (tv == null) {
      return EmptyState(
        icon: Icons.tv_off_rounded,
        title: 'No TV yet',
        message: 'Find your TV on this Wi-Fi to get started.',
        actionLabel: 'Find TVs',
        onAction: () => context.push('/onboarding?add=1'),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(nowPlayingProvider.notifier).refresh();
        ref.invalidate(journalEntriesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.sm,
          Gap.page,
          Gap.xxl,
        ),
        children: [
          // Always one slot, so the tiles below keep their state when a
          // break starts.
          const _BreakSlot(),
          const NowOnTvCard(),
          const SectionHeader('Quick actions'),
          QuickActionsPanel(tv: tv),
          if (!tv.can(TvCapability.agent)) ...[
            const SectionHeader('Classic lock'),
            const ClassicLockCard(),
          ],
          const SectionHeader('Recent events'),
          const RecentEvents(),
        ],
      ),
    );
  }
}

/// Hero card: what's on, volume, mute, or when the TV was last seen.
class NowOnTvCard extends ConsumerWidget {
  const NowOnTvCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    return InfoCard(
      padding: const EdgeInsets.all(Gap.xl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            scheme.primary.withValues(alpha: now.online ? 0.16 : 0.04),
            scheme.surfaceContainerLow,
          ),
          scheme.surfaceContainerLow,
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: now.loading
            ? const _NowSkeleton(key: ValueKey('loading'))
            : Column(
                key: ValueKey('${now.online}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('NOW ON TV', style: text.labelSmall),
                      const Spacer(),
                      if (now.online && now.source != null)
                        TagChip(
                          'via ${now.source == 'adb' ? 'ADB' : 'Cast'}',
                          tone: Tone.idle,
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  if (!now.online) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          color: status.idle,
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            'TV is off or out of reach',
                            style: text.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      now.lastSeen == null
                          ? 'Not seen yet. Is it on and on this Wi-Fi?'
                          : 'Last seen ${relativeTime(now.lastSeen!)}',
                      style: text.bodySmall,
                    ),
                  ] else ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        now.appName.isEmpty ? 'Unknown app' : now.appName,
                        key: ValueKey(now.appName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineMedium,
                      ),
                    ),
                    if (now.id != null && !now.isHome) ...[
                      const SizedBox(height: 2),
                      Text(
                        now.id!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: Gap.xl),
                    Row(
                      children: [
                        Icon(
                          now.muted == true
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 20,
                          color: now.muted == true
                              ? status.bad
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: VolumeMeter(
                            percent: now.volume,
                            muted: now.muted == true,
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        SizedBox(
                          width: 44,
                          child: Text(
                            now.volume == null ? '—' : '${now.volume}%',
                            textAlign: TextAlign.right,
                            style: text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    if (now.muted == true) ...[
                      const SizedBox(height: Gap.md),
                      const TagChip('Muted', tone: Tone.bad),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _NowSkeleton extends StatelessWidget {
  const _NowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 10, width: 80),
        SizedBox(height: Gap.lg),
        Skeleton(height: 28, width: 180),
        SizedBox(height: Gap.sm),
        Skeleton(height: 12, width: 140),
        SizedBox(height: Gap.xl),
        Skeleton(height: 8),
      ],
    );
  }
}

String transportLabel(ActionTransport t) => switch (t) {
      ActionTransport.sonyRest => 'Sony IP control',
      ActionTransport.adb => 'ADB',
      ActionTransport.cast => 'Cast',
      ActionTransport.dial => 'DIAL',
      ActionTransport.none => 'no transport',
    };

/// Grid of large action tiles plus the volume slider. Only actions the
/// TV supports are shown; the rest become an "Unlock with ADB" tip.
class QuickActionsPanel extends ConsumerStatefulWidget {
  final Tv tv;

  const QuickActionsPanel({super.key, required this.tv});

  @override
  ConsumerState<QuickActionsPanel> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<QuickActionsPanel> {
  final _inflight = <QuickAction>{};
  double? _dragVolume;


  /// Can [a] start while the actions in flight run? Mute, volume and
  /// stop each touch one thing; Bore and Break touch both.
  bool _blocked(QuickAction a) =>
      _inflight.any((b) => _touches(a).intersection(_touches(b)).isNotEmpty);

  static Set<String> _touches(QuickAction a) => switch (a) {
        QuickAction.mute || QuickAction.restore => const {'sound'},
        QuickAction.volume => const {'sound'},
        QuickAction.stop => const {'app'},
        QuickAction.bore || QuickAction.takeBreak => const {'sound', 'app'},
      };

  /// Shows [optimistic] at once, runs [run], and only speaks up if it
  /// failed (rolling the change back). Success gets a brief check.
  Future<void> _run(
    QuickAction action,
    Future<ActionResult?> Function() run, {
    NowPlaying Function(NowPlaying s)? optimistic,
  }) async {
    if (_blocked(action)) return;
    unawaited(HapticFeedback.lightImpact());
    final now = ref.read(nowPlayingProvider.notifier);
    setState(() => _inflight.add(action));
    final undo = optimistic == null ? null : now.patch(optimistic);
    now.hold();
    ActionResult? r;
    final sw = Stopwatch()..start();
    try {
      r = await run();
    } catch (e) {
      r = ActionResult(false, ActionTransport.none, detail: '$e');
    } finally {
      now.release();
    }
    final ok = r != null && r.ok;
    if (kDebugMode) {
      debugPrint('BTIME action ${action.name} ${sw.elapsedMilliseconds}ms '
          'ok=$ok via=${r?.via.name} ${r?.detail ?? ''}');
    }
    if (!ok && undo != null) now.revert(undo);
    if (!mounted) return;
    ref.invalidate(journalEntriesProvider);
    // Success needs no feedback: the tile already flipped on tap.
    setState(() => _inflight.remove(action));
    if (ok) return;
    showStatusSnack(
      context,
      r == null
          ? 'Didn\'t work: no TV selected'
          : 'Didn\'t work: ${r.detail.isEmpty ? 'TV unreachable' : r.detail}',
      ok: false,
    );
  }

  ActionsService? get _actions => ref.read(actionsServiceProvider);

  BreakController get _break => ref.read(breakProvider.notifier);

  Future<void> _startBreak() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => const BreakSheet(),
    );
    if (minutes == null || !mounted) return;
    await _run(QuickAction.takeBreak, () => _break.start(minutes));
  }

  Future<void> _endBreak(QuickAction via) => _run(via, () => _break.end());

  VoidCallback? _tap(QuickAction a, VoidCallback f) => _blocked(a) ? null : f;

  @override
  Widget build(BuildContext context) {
    final supported = supportedActions(widget.tv);
    final now = ref.watch(nowPlayingProvider);
    final brk = ref.watch(breakProvider);
    final muted = now.muted == true || brk.active;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    if (supported.isEmpty) {
      return InfoCard(
        child: EmptyState(
          icon: Icons.settings_remote_outlined,
          title: 'No remote controls yet',
          message: 'We couldn\'t reach Cast, Sony IP control or ADB on '
              'this TV. Check it\'s on, then try again.',
          actionLabel: 'Check again',
          onAction: () => ref.read(capabilityProvider.notifier).probe(),
        ),
      );
    }

    ActionTile tile(
      QuickAction a, {
      required String key,
      required IconData icon,
      required String label,
      String? state,
      bool active = false,
      Tone tone = Tone.accent,
      required VoidCallback onTap,
    }) =>
        ActionTile(
          key: Key(key),
          icon: icon,
          label: label,
          state: state,
          active: active,
          tone: tone,
          busy: _inflight.contains(a),
          onTap: _tap(a, onTap),
        );

    final tiles = <Widget>[
      if (supported.contains(QuickAction.mute))
        tile(
          QuickAction.mute,
          key: 'action-mute',
          icon: muted ? Icons.volume_off_rounded : Icons.volume_mute_rounded,
          label: muted ? 'Unmute' : 'Mute',
          state: brk.active ? 'On break' : (muted ? 'Muted' : 'Sound on'),
          active: muted,
          tone: Tone.bad,
          onTap: brk.active
              ? () => _endBreak(QuickAction.mute)
              : () => _run(
                    QuickAction.mute,
                    () async => muted ? _actions?.unmute() : _actions?.mute(),
                    optimistic: (s) => s.copyWith(muted: !muted),
                  ),
        ),
      if (supported.contains(QuickAction.stop))
        tile(
          QuickAction.stop,
          key: 'action-stop',
          icon: Icons.stop_circle_rounded,
          label: 'Stop app',
          state: widget.tv.can(TvCapability.adb)
              ? 'Close what\'s on'
              : 'Cast apps only',
          onTap: () => _run(
            QuickAction.stop,
            () async => _actions?.stopCurrentApp(),
            optimistic: (s) => s.atHome(),
          ),
        ),
      if (supported.contains(QuickAction.bore))
        tile(
          QuickAction.bore,
          key: 'action-bore',
          icon: Icons.bedtime_rounded,
          label: 'Bore',
          state: 'Stop + mute',
          onTap: () => _run(
            QuickAction.bore,
            () async => _actions?.bore(),
            optimistic: (s) => s.atHome().copyWith(muted: true),
          ),
        ),
      if (supported.contains(QuickAction.takeBreak))
        tile(
          QuickAction.takeBreak,
          key: 'action-break',
          icon: brk.active ? Icons.timer_rounded : Icons.coffee_rounded,
          label: brk.active ? 'End break' : 'Break',
          state: brk.active
              ? 'Until ${clockTime(brk.until!)}'
              : '15 · 30 · 60 min',
          active: brk.active,
          tone: Tone.warn,
          onTap:
              brk.active ? () => _endBreak(QuickAction.takeBreak) : _startBreak,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Gap.md,
          crossAxisSpacing: Gap.md,
          childAspectRatio: 1.45 / scale.clamp(1.0, 1.6),
          children: tiles,
        ),
        if (supported.contains(QuickAction.volume)) ...[
          const SizedBox(height: Gap.md),
          _volumeCard(context, now),
        ],
        if (supported.contains(QuickAction.restore)) ...[
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            key: const Key('action-restore'),
            onPressed: _tap(
              QuickAction.restore,
              brk.active
                  ? () => _endBreak(QuickAction.restore)
                  : () => _run(
                        QuickAction.restore,
                        () async => _actions?.restore(),
                        optimistic: (s) => s.copyWith(muted: false),
                      ),
            ),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Restore TV (unmute)'),
          ),
        ],
        if (!widget.tv.can(TvCapability.adb)) ...[
          const SizedBox(height: Gap.md),
          _AdbTip(missingVolume: !supported.contains(QuickAction.volume)),
        ],
      ],
    );
  }

  Widget _volumeCard(BuildContext context, NowPlaying now) {
    final text = Theme.of(context).textTheme;
    final current = (now.volume ?? 0).toDouble().clamp(0.0, 100.0);
    final shown = _dragVolume ?? current;
    final blocked = _blocked(QuickAction.volume);
    return InfoCard(
      key: const Key('action-volume'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, size: 20),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text('Volume', style: text.titleSmall)),
              if (_inflight.contains(QuickAction.volume))
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: Gap.sm),
              Text('${shown.round()}%', style: text.titleSmall),
            ],
          ),
          Slider(
            value: shown,
            max: 100,
            divisions: 100,
            label: '${shown.round()}%',
            onChanged: blocked ? null : (v) => setState(() => _dragVolume = v),
            onChangeEnd: blocked
                ? null
                : (v) {
                    final target = v.round();
                    setState(() => _dragVolume = null);
                    _run(
                      QuickAction.volume,
                      () async => _actions?.setVolume(target),
                      optimistic: (s) => s.copyWith(volume: target),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

/// Picks 15, 30 or 60 minutes for a break.
class BreakSheet extends StatelessWidget {
  const BreakSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Take a break', style: text.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              'Closes the app and mutes now. Sound comes back '
              'automatically.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                for (final m in const [15, 30, 60]) ...[
                  if (m != 15) const SizedBox(width: Gap.md),
                  Expanded(
                    child: FilledButton.tonal(
                      key: Key('break-$m'),
                      onPressed: () => Navigator.pop(context, m),
                      child: Text('$m min'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'Keeps working while Boretube is open. TV Guard (coming '
              'soon) will enforce it even when your phone is away.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakSlot extends ConsumerWidget {
  const _BreakSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(breakProvider).active) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: Gap.md),
      child: BreakBanner(),
    );
  }
}

/// "Break · 12:40 left" with a live countdown and End now.
class BreakBanner extends ConsumerStatefulWidget {
  const BreakBanner({super.key});

  @override
  ConsumerState<BreakBanner> createState() => _BreakBannerState();
}

class _BreakBannerState extends ConsumerState<BreakBanner> {
  Timer? _tick;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _end() async {
    if (_ending) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _ending = true);
    final r = await ref.read(breakProvider.notifier).end();
    if (!mounted) return;
    ref.invalidate(journalEntriesProvider);
    setState(() => _ending = false);
    if (r == null || !r.ok) {
      showStatusSnack(
        context,
        'Didn\'t work: '
        '${r == null || r.detail.isEmpty ? 'TV unreachable' : r.detail}',
        ok: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(breakProvider);
    final left = ref.read(breakProvider.notifier).remaining();
    final text = Theme.of(context).textTheme;
    final warn = Tone.warn.color(context);
    final scheme = Theme.of(context).colorScheme;
    return InfoCard(
      key: const Key('break-banner'),
      color: Color.alphaBlend(
        warn.withValues(alpha: 0.16),
        scheme.surfaceContainerLow,
      ),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
      child: Row(
        children: [
          Icon(Icons.coffee_rounded, color: warn),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              'Break · ${countdown(left)} left',
              style: text.titleMedium,
            ),
          ),
          FilledButton.tonal(
            key: const Key('break-end'),
            onPressed: _ending ? null : _end,
            child: const Text('End now'),
          ),
        ],
      ),
    );
  }
}

class _AdbTip extends StatelessWidget {
  final bool missingVolume;
  const _AdbTip({required this.missingVolume});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InfoCard(
      key: const Key('adb-tip'),
      color: scheme.surface,
      padding: const EdgeInsets.all(Gap.md),
      onTap: () => context.push('/adb-guide'),
      child: Row(
        children: [
          Icon(Icons.lock_open_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              missingVolume
                  ? 'Unlock with ADB for volume control, strong stop and '
                      'TV health.'
                  : 'Unlock with ADB for strong stop and TV health.',
              style: text.bodySmall,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Last five journal entries.
class RecentEvents extends ConsumerWidget {
  const RecentEvents({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider);
    return entries.when(
      loading: () => const SkeletonCard(rows: 2),
      error: (e, _) => InfoCard(
        child: EmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: 'Couldn\'t load events',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(journalEntriesProvider),
        ),
      ),
      data: (list) => list.isEmpty
          ? const InfoCard(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Nothing yet',
                message: 'Changes made to the TV show up here.',
              ),
            )
          : GroupCard(
              children: [
                for (final e in list.take(5)) JournalRow(entry: e),
              ],
            ),
    );
  }
}

/// One journal entry as a status row.
class JournalRow extends StatelessWidget {
  final JournalEntry entry;
  final bool expanded;

  const JournalRow({super.key, required this.entry, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return StatusRow(
      tone: entry.ok ? Tone.ok : Tone.bad,
      icon: journalIcon(entry.op),
      title: journalTitle(entry),
      detail: expanded
          ? '${relativeTime(entry.time)} · ${entry.before} → ${entry.after}'
          : relativeTime(entry.time),
      detailLines: expanded ? 3 : 1,
    );
  }
}
