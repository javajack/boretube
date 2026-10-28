import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ops/health.dart';
import '../ops/tv_ops.dart';
import '../providers/agent_providers.dart';
import '../providers/tv_providers.dart';
import '../providers/ui_providers.dart';
import '../ui/components.dart';
import '../ui/controls.dart';
import '../ui/learn.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'tab_header.dart';
import 'tv/apps_section.dart';
import 'tv/clean_tv.dart';
import 'tv/health_copy.dart';
import 'tv/health_section.dart';
import 'tv/tv_guard_card.dart';

/// Better TV: a summary, then YouTube without Shorts, Clean TV, Apps, TV
/// health, Always On, and the way back.
class BetterTvTab extends ConsumerStatefulWidget {
  const BetterTvTab({super.key});

  @override
  ConsumerState<BetterTvTab> createState() => _BetterTvTabState();
}

class _BetterTvTabState extends ConsumerState<BetterTvTab> {
  final _alwaysOnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = ref.read(betterTvFocusProvider);
      if (f != null) _focus(f);
    });
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Honours a deep link or a nudge: opens that section, or scrolls to
  /// Always On.
  void _focus(String id) {
    ref.read(betterTvFocusProvider.notifier).state = null;
    final adb = ref.read(activeHasAdbProvider);
    switch (id) {
      case 'noShorts' when adb:
        _open(const YouTubeScreen());
      case 'cleanTv' when adb:
        _open(const CleanTvScreen());
      case 'health':
        _open(const HealthScreen());
      default:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final c = _alwaysOnKey.currentContext;
          if (c != null && c.mounted) {
            Scrollable.ensureVisible(
              c,
              duration: Motion.of(context, Motion.slow),
              curve: Motion.settle,
              alignment: 0.1,
            );
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(betterTvFocusProvider, (_, next) {
      if (next != null) _focus(next);
    });
    final adb = ref.watch(activeHasAdbProvider);
    final agent = ref.watch(hasAgentProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(healthProvider)
          ..invalidate(stockYouTubeStateProvider)
          ..invalidate(cleanStatusProvider)
          ..invalidate(appsProvider);
        await ref.read(agentStatusProvider.notifier).refresh();
      },
      child: ListView(
        key: const Key('better-tv-list'),
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        children: [
          const TabHeader(
            title: 'Better TV',
            subtitle: 'A calmer, cleaner TV. Undo anything.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Gap.xs),
                if (adb || agent)
                  _Summary(onOpen: () => _open(const HealthScreen()))
                else
                  const _UnlockHero(),
                const SizedBox(height: Gap.md),
                _YouTubeRow(
                  locked: !adb,
                  onTap: () => _open(const YouTubeScreen()),
                ),
                const SizedBox(height: Gap.sm),
                _CleanRow(
                  locked: !adb,
                  onTap: () => _open(const CleanTvScreen()),
                ),
                const SizedBox(height: Gap.sm),
                _AppsRow(locked: !adb, onTap: () => _open(const AppsScreen())),
                if (adb || agent) ...[
                  const SizedBox(height: Gap.sm),
                  _HealthRow(onTap: () => _open(const HealthScreen())),
                ],
                SectionHeader('Always On', key: _alwaysOnKey),
                const TvGuardCard(),
                const SizedBox(height: Gap.xl),
                PrimaryButton(
                  key: const Key('better-tv-restore'),
                  label: 'Put the TV back the way it was',
                  icon: Icons.settings_backup_restore_rounded,
                  kind: ButtonKind.outline,
                  height: 52,
                  onPressed: () => context.push('/restore'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "All good · N checks", or "N things need attention" with Fix all.
class _Summary extends ConsumerWidget {
  final VoidCallback onOpen;
  const _Summary({required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final checks = mergedHealth(ref);
    if (checks == null) {
      return const SkeletonCard(rows: 1);
    }
    final issues = checks
        .where(
          (c) => c.status == HealthStatus.warn || c.status == HealthStatus.fail,
        )
        .toList();
    final fixable = checks.where((c) => c.fix != null).toList();
    final good = issues.isEmpty;
    final bad = issues.any((c) => c.status == HealthStatus.fail);
    final (bg, ink, sub) = good
        ? (bt.mintTint, bt.mintInk, bt.inkSoft)
        : bad
            ? (bt.berryTint, bt.berryInk, bt.inkSoft)
            : (bt.sunTint, bt.sunInk, bt.inkSoft);
    return Semantics(
      container: true,
      liveRegion: !good,
      child: InfoCard(
        key: const Key('health-summary'),
        radius: Radii.hero,
        color: bg,
        borderColor: bg,
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Tubby(
                  mood: good ? TubbyMood.cleaning : TubbyMood.calm,
                  size: 58,
                  body: good ? bt.mint : (bad ? bt.berry : bt.sun),
                  antennas: false,
                  legs: false,
                  beaming: good,
                  animate: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        good
                            ? 'All good'
                            : issues.length == 1
                                ? '1 thing needs attention'
                                : '${issues.length} things need attention',
                        style: Fonts.bricolage(20, color: ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        good
                            ? '${checks.length} check${checks.length == 1 ? '' : 's'} passed'
                            : issues.take(2).map((c) {
                                  return healthLook(c).title;
                                }).join(' · ') +
                                (issues.length > 2 ? ' · …' : ''),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          color: sub,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: ink),
              ],
            ),
            if (fixable.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              PrimaryButton(
                key: const Key('health-fix-all'),
                label: fixable.length == 1
                    ? 'Fix it'
                    : 'Fix all (${fixable.length})',
                icon: Icons.auto_fix_high_rounded,
                height: 52,
                onPressed: () => fixHealth(context, ref, fixable),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Without Home mode: what Better TV would do, and the one way there.
class _UnlockHero extends StatelessWidget {
  const _UnlockHero();

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return InfoCard(
      key: const Key('better-tv-preview'),
      radius: Radii.hero,
      color: bt.lavenderTint,
      borderColor: bt.lavenderTint,
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Tubby(mood: TubbyMood.cleaning, size: 60, animate: false),
              const Spacer(),
              const Flexible(
                child: BtBadge(
                  'About 3 minutes',
                  tone: Tone.info,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text('Make this TV calmer', style: text.headlineMedium),
          const SizedBox(height: Gap.xs),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Unlock Home mode once, with the remote. Then hide '
                  'Shorts, tidy away promo apps and keep an eye on the TV.',
                  style: text.bodyMedium,
                ),
              ),
              const InfoDot(LearnTerm.homeMode),
            ],
          ),
          const SizedBox(height: Gap.lg),
          PrimaryButton(
            key: const Key('better-tv-unlock'),
            label: 'Unlock Home mode',
            icon: Icons.lock_open_rounded,
            kind: ButtonKind.ink,
            onPressed: () => context.push('/adb-guide'),
          ),
        ],
      ),
    );
  }
}

/// The small "Unlock" tag on a preview row.
class _UnlockTag extends StatelessWidget {
  const _UnlockTag();

  @override
  Widget build(BuildContext context) =>
      const BtBadge('Unlock', tone: Tone.info, icon: Icons.lock_rounded);
}

class _YouTubeRow extends ConsumerWidget {
  final bool locked;
  final VoidCallback onTap;
  const _YouTubeRow({required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = locked ? null : ref.watch(stockYouTubeStateProvider).valueOrNull;
    final on = s == AppState.notInstalled || s == AppState.absent;
    final known = s != null;
    return NavCard(
      key: const Key('better-tv-noShorts'),
      icon: Icons.smart_display_rounded,
      tone: Tone.accent,
      title: 'YouTube without Shorts',
      detail: locked
          ? 'Keep YouTube, lose the endless Shorts'
          : !known
              ? 'Checking the TV…'
              : on
                  ? 'On · the TV\'s own YouTube is hidden'
                  : 'Off · Shorts are still on the TV',
      detailTone: locked || !known ? null : (on ? Tone.ok : Tone.warn),
      onTap: locked ? () => context.push('/adb-guide') : onTap,
      trailing: locked ? const _UnlockTag() : null,
    );
  }
}

class _CleanRow extends ConsumerWidget {
  final bool locked;
  final VoidCallback onTap;
  const _CleanRow({required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = locked ? null : ref.watch(tvOpsProvider).valueOrNull;
    final s = locked ? null : ref.watch(cleanStatusProvider).valueOrNull;
    final counts =
        ops == null || s == null ? null : cleanCounts(ops.profile, s);
    final String detail;
    Tone? tone;
    if (locked) {
      detail = 'Tidy away promo, ad and leftover apps';
    } else if (s == null) {
      detail = ops == null ? 'Checking the TV…' : 'Reading the apps…';
    } else if (counts == null) {
      detail = 'Nothing to tidy on this TV';
    } else if (counts.tidied == counts.present) {
      detail = '${counts.tidied} promo and ad apps tidied away';
      tone = Tone.ok;
    } else {
      final left = counts.present - counts.tidied;
      detail = '$left app${left == 1 ? '' : 's'} to tidy';
      tone = Tone.warn;
    }
    return NavCard(
      key: const Key('better-tv-cleanTv'),
      icon: Icons.auto_awesome_rounded,
      tone: Tone.info,
      title: 'Clean TV',
      detail: detail,
      detailTone: tone,
      onTap: locked ? () => context.push('/adb-guide') : onTap,
      trailing: locked ? const _UnlockTag() : null,
    );
  }
}

class _AppsRow extends ConsumerWidget {
  final bool locked;
  final VoidCallback onTap;
  const _AppsRow({required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = locked ? null : ref.watch(appsProvider).valueOrNull;
    final n = apps?.where((a) => a.launchable).length;
    return NavCard(
      key: const Key('better-tv-apps'),
      icon: Icons.grid_view_rounded,
      tone: Tone.info,
      title: 'Apps on your TV',
      detail: locked
          ? 'See every app and switch any of them off'
          : n == null || n == 0
              ? 'Turn apps on or off'
              : '$n apps · turn any of them off',
      onTap: locked ? () => context.push('/adb-guide') : onTap,
      trailing: locked ? const _UnlockTag() : null,
    );
  }
}

class _HealthRow extends ConsumerWidget {
  final VoidCallback onTap;
  const _HealthRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = mergedHealth(ref);
    final issues = checks
        ?.where((c) =>
            c.status == HealthStatus.warn || c.status == HealthStatus.fail)
        .length;
    return NavCard(
      key: const Key('better-tv-health'),
      icon: Icons.monitor_heart_rounded,
      tone: issues == null || issues == 0 ? Tone.ok : Tone.warn,
      title: 'TV health',
      detail: checks == null
          ? 'Checking the TV…'
          : issues == 0
              ? 'All ${checks.length} checks fine'
              : '$issues of ${checks.length} need a look',
      onTap: onTap,
    );
  }
}
