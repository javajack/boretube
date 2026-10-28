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
import 'tv/clean_wizard.dart';
import 'tv/health_copy.dart';
import 'tv/health_section.dart';
import 'tv/tv_guard_card.dart';

/// Better TV is a status report: Tubby and a headline ("All good" or
/// "2 things to fix") with one Fix, the checks that need a look, three
/// destinations, the Always On card, and the way back.
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
      case 'cleanWizard' when adb:
        _open(const CleanWizardScreen());
      case 'health':
        _open(const HealthScreen());
      default:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final c = _alwaysOnKey.currentContext;
          if (c != null && c.mounted) {
            Scrollable.ensureVisible(
              c,
              duration: Motion.of(context, Motion.sheet),
              curve: Motion.enter,
              alignment: Phi.minor / 2,
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
    final bt = context.bt;
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
        padding: const EdgeInsets.only(bottom: Gap.section),
        children: [
          const TabHeader(title: 'Better TV'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (adb || agent)
                  _StatusReport(
                    onCheck: (id) => _open(HealthScreen(focus: id)),
                    onHealth: () => _open(const HealthScreen()),
                  )
                else
                  const _UnlockHero(),
                const SizedBox(height: Gap.section),
                RowList(
                  children: [
                    _YouTubeRow(
                      locked: !adb,
                      onTap: () => _open(const YouTubeScreen()),
                    ),
                    _CleanRow(
                      locked: !adb,
                      onTap: () => _open(const CleanTvScreen()),
                    ),
                    _AppsRow(
                      locked: !adb,
                      onTap: () => _open(const AppsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.section),
                TvGuardCard(key: _alwaysOnKey),
                const SizedBox(height: Gap.related),
                Center(
                  child: TextButton.icon(
                    key: const Key('better-tv-restore'),
                    style: TextButton.styleFrom(foregroundColor: bt.inkSoft),
                    onPressed: () => context.push('/restore'),
                    icon: const Icon(
                      Icons.settings_backup_restore_rounded,
                      size: Sizes.icon,
                    ),
                    label: const Text('Put the TV back the way it was'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isIssue(HealthCheck c) =>
    c.status == HealthStatus.warn || c.status == HealthStatus.fail;

/// Checks that have their own destination row below the checklist. They are
/// reported there (with their state), never twice.
const _destinationChecks = {'cleanup', 'stockYouTube'};

/// The health check behind a destination row, when the row's own read is
/// still loading.
HealthCheck? _check(WidgetRef ref, String id) =>
    mergedHealth(ref)?.where((c) => c.id == id).firstOrNull;

/// The hero (Tubby, headline, one line, one Fix) and the checklist of
/// what needs a look, ending in a row to every check.
class _StatusReport extends ConsumerWidget {
  final ValueChanged<String> onCheck;
  final VoidCallback onHealth;

  const _StatusReport({required this.onCheck, required this.onHealth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final checks = mergedHealth(ref);
    if (checks == null) {
      return const Padding(
        padding: EdgeInsets.only(top: Gap.related),
        child: SkeletonCard(rows: 2),
      );
    }
    final issues = checks.where(_isIssue).toList();
    final fixable = issues.where((c) => c.fix != null).toList();
    final good = issues.isEmpty;
    final passed = checks.length - issues.length;
    final headline = good
        ? 'All good'
        : fixable.isEmpty
            ? issues.length == 1
                ? '1 thing needs you'
                : '${issues.length} things need you'
            : issues.length == 1
                ? '1 thing to fix'
                : '${issues.length} things to fix';
    final line = good
        ? '${checks.length} check${checks.length == 1 ? '' : 's'} passed'
        : '$passed of ${checks.length} checks passed';
    final manualId = issues.where((c) => c.fix == null).firstOrNull?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: const Key('health-summary'),
          container: true,
          liveRegion: !good,
          child: Padding(
            padding: const EdgeInsets.only(top: Gap.related),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.sheet),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  child: Tubby(
                    key: ValueKey(good),
                    mood: good ? TubbyMood.calm : TubbyMood.cleaning,
                    size: Sizes.tubbyLarge,
                    beaming: good,
                    animate: false,
                  ),
                ),
                const SizedBox(width: Gap.related),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: Fonts.bricolage(TypeSize.title, color: bt.ink),
                      ),
                      const SizedBox(height: Gap.f4),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(color: bt.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (fixable.isNotEmpty) ...[
          const SizedBox(height: Gap.related),
          PrimaryButton(
            key: const Key('health-fix-all'),
            label: fixable.length == 1 && issues.length == 1
                ? 'Fix it'
                : 'Fix ${fixable.length} now',
            icon: Icons.auto_fix_high_rounded,
            onPressed: () => fixHealth(context, ref, fixable),
          ),
        ],
        const SizedBox(height: Gap.related),
        RowList(
          key: const Key('better-tv-checklist'),
          children: [
            for (final c in issues)
              if (!_destinationChecks.contains(c.id))
                StatusRow(
                  key: c.id == manualId
                      ? const Key('health-needs-you')
                      : Key('better-tv-check-${c.id}'),
                  tone: healthTone(c.status),
                  icon: healthIcon(c.id),
                  title: healthLook(c).title,
                  detail: c.fix == null
                      ? 'Needs you · ${healthLook(c).detail}'
                      : healthLook(c).detail,
                  onTap: () => onCheck(c.id),
                ),
            ListRow(
              key: const Key('better-tv-health'),
              icon: Icons.monitor_heart_rounded,
              iconColor: bt.muted,
              title: 'TV health',
              subtitle: good
                  ? 'Every check, in plain words'
                  : '$passed other check${passed == 1 ? '' : 's'} fine',
              onTap: onHealth,
            ),
          ],
        ),
      ],
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
    return Column(
      key: const Key('better-tv-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Gap.related),
          child: Row(
            children: [
              const Tubby(
                mood: TubbyMood.cleaning,
                size: Sizes.tubbyLarge,
                animate: false,
              ),
              const SizedBox(width: Gap.related),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make this TV calmer',
                      style: Fonts.bricolage(TypeSize.title, color: bt.ink),
                    ),
                    const SizedBox(height: Gap.f4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'One setup with the remote, about 3 min',
                            style: text.bodyMedium!.copyWith(color: bt.muted),
                          ),
                        ),
                        const InfoDot(LearnTerm.homeMode),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.related),
        PrimaryButton(
          key: const Key('better-tv-unlock'),
          label: 'Unlock Home mode',
          icon: Icons.lock_open_rounded,
          onPressed: () => context.push('/adb-guide'),
        ),
      ],
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
    final fromHealth = locked || s != null ? null : _check(ref, 'stockYouTube');
    final known = s != null || fromHealth != null;
    final on = s != null
        ? s == AppState.notInstalled || s == AppState.absent
        : fromHealth?.status == HealthStatus.ok;
    return NavRow(
      key: const Key('better-tv-noShorts'),
      icon: Icons.smart_display_rounded,
      tone: Tone.accent,
      title: 'YouTube without Shorts',
      detail: locked
          ? 'Keep YouTube, lose the Shorts'
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
      detail = 'Tidy away promo and ad apps';
    } else if (s == null) {
      final h = _check(ref, 'cleanup');
      if (h == null) {
        detail = ops == null ? 'Checking the TV…' : 'Reading the apps…';
      } else {
        detail = healthLook(h).detail;
        tone = _isIssue(h) ? Tone.warn : Tone.ok;
      }
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
    return NavRow(
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
    return NavRow(
      key: const Key('better-tv-apps'),
      icon: Icons.grid_view_rounded,
      tone: Tone.info,
      title: 'Apps on your TV',
      detail: locked
          ? 'Switch any app off'
          : n == null || n == 0
              ? 'Turn apps on or off'
              : '$n apps · turn any of them off',
      onTap: locked ? () => context.push('/adb-guide') : onTap,
      trailing: locked ? const _UnlockTag() : null,
    );
  }
}
