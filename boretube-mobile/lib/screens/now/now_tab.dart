import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../actions/actions_service.dart';
import '../../ops/journal.dart';
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
  QuickAction? _busy;
  double? _dragVolume;

  Future<void> _run(
    QuickAction action,
    String done,
    Future<ActionResult?> Function() run,
  ) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    ActionResult? r;
    try {
      r = await run();
    } catch (e) {
      r = ActionResult(false, ActionTransport.none, detail: '$e');
    }
    if (!mounted) return;
    setState(() => _busy = null);
    if (r == null) {
      showStatusSnack(context, 'No TV selected', ok: false);
    } else if (r.ok) {
      showStatusSnack(context, '$done · via ${transportLabel(r.via)}');
    } else {
      showStatusSnack(
        context,
        'Didn\'t work: ${r.detail.isEmpty ? 'TV unreachable' : r.detail}',
        ok: false,
      );
    }
    ref.invalidate(journalEntriesProvider);
    await ref.read(nowPlayingProvider.notifier).refresh();
  }

  ActionsService? get _actions => ref.read(actionsServiceProvider);

  Future<void> _pause() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => const _PauseSheet(),
    );
    if (minutes == null) return;
    await _run(
      QuickAction.pause,
      'Paused for $minutes min',
      () => ref.read(pauseProvider.notifier).pause(minutes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supported = supportedActions(widget.tv);
    final now = ref.watch(nowPlayingProvider);
    final pause = ref.watch(pauseProvider);
    final muted = now.muted == true;
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

    final tiles = <Widget>[
      if (supported.contains(QuickAction.mute))
        ActionTile(
          key: const Key('action-mute'),
          icon: muted ? Icons.volume_off_rounded : Icons.volume_mute_rounded,
          label: muted ? 'Unmute' : 'Mute',
          state: muted ? 'Muted' : 'Sound on',
          active: muted,
          tone: Tone.bad,
          busy: _busy == QuickAction.mute,
          onTap: () => _run(
            QuickAction.mute,
            muted ? 'Unmuted' : 'Muted',
            () async => muted ? _actions?.unmute() : _actions?.mute(),
          ),
        ),
      if (supported.contains(QuickAction.stop))
        ActionTile(
          key: const Key('action-stop'),
          icon: Icons.stop_circle_rounded,
          label: 'Stop app',
          state: widget.tv.can(TvCapability.adb)
              ? 'Close what\'s on'
              : 'Cast apps only',
          busy: _busy == QuickAction.stop,
          onTap: () => _run(
            QuickAction.stop,
            'Stopped',
            () async => _actions?.stopCurrentApp(),
          ),
        ),
      if (supported.contains(QuickAction.bore))
        ActionTile(
          key: const Key('action-bore'),
          icon: Icons.bedtime_rounded,
          label: 'Bore',
          state: 'Stop + mute',
          busy: _busy == QuickAction.bore,
          onTap: () => _run(
            QuickAction.bore,
            'TV is boring now',
            () async => _actions?.bore(),
          ),
        ),
      if (supported.contains(QuickAction.pause))
        ActionTile(
          key: const Key('action-pause'),
          icon: pause.active
              ? Icons.timer_rounded
              : Icons.pause_circle_rounded,
          label: pause.active ? 'Paused' : 'Pause TV',
          state: pause.active
              ? 'Until ${clockTime(pause.until!)}'
              : '15 · 30 · 60 min',
          active: pause.active,
          tone: Tone.info,
          busy: _busy == QuickAction.pause,
          onTap: pause.active
              ? () => _run(
                    QuickAction.pause,
                    'Pause ended',
                    () => ref.read(pauseProvider.notifier).restore(),
                  )
              : _pause,
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
            onPressed: _busy != null
                ? null
                : () => _run(
                      QuickAction.restore,
                      'TV restored',
                      () => ref.read(pauseProvider.notifier).restore(),
                    ),
            icon: _busy == QuickAction.restore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restart_alt_rounded),
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
              if (_busy == QuickAction.volume)
                const SizedBox(
                  width: 16,
                  height: 16,
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
            onChanged: _busy != null
                ? null
                : (v) => setState(() => _dragVolume = v),
            onChangeEnd: (v) async {
              final target = v.round();
              await _run(
                QuickAction.volume,
                'Volume set to $target%',
                () async => _actions?.setVolume(target),
              );
              if (mounted) setState(() => _dragVolume = null);
            },
          ),
        ],
      ),
    );
  }
}

class _PauseSheet extends StatelessWidget {
  const _PauseSheet();

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
            Text('Pause the TV', style: text.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              'Stops the app and mutes. Sound comes back when the time is '
              'up, while Boretube is open.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                for (final m in const [15, 30, 60]) ...[
                  if (m != 15) const SizedBox(width: Gap.md),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context, m),
                      child: Text('$m min'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
