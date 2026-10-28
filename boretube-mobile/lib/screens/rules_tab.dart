import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../agent/agent_client.dart';
import '../providers/agent_providers.dart';
import '../providers/tv_providers.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'rules/rules_editor.dart';
import 'tv/tv_guard_card.dart';

/// The rules document on the active TV's agent.
final rulesProvider = FutureProvider.autoDispose<AgentRules?>((ref) async {
  final c = ref.watch(agentClientProvider);
  if (c == null) return null;
  return c.rules();
});

/// Rules for TV Guard TVs; an explainer and Install button elsewhere.
class RulesTab extends ConsumerWidget {
  const RulesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasAgentProvider)) return const _RulesExplainer();
    final rules = ref.watch(rulesProvider);
    return rules.when(
      skipLoadingOnRefresh: true,
      loading: () => ListView(
        padding: rulesListPadding,
        children: const [
          SkeletonCard(rows: 1),
          SizedBox(height: Gap.md),
          SkeletonCard(rows: 3),
          SizedBox(height: Gap.md),
          SkeletonCard(rows: 3),
        ],
      ),
      error: (e, _) => ListView(
        padding: rulesListPadding,
        children: [
          InfoCard(
            child: EmptyState(
              icon: Icons.portable_wifi_off_rounded,
              tone: Tone.bad,
              title: 'Couldn\'t reach TV Guard',
              message: e is AgentAuthException
                  ? 'TV Guard doesn\'t recognise this phone. Use Repair on '
                      'the TV tab.'
                  : 'Rules keep running on the TV. Check it\'s on, then '
                      'try again. ($e)',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(rulesProvider),
            ),
          ),
        ],
      ),
      data: (r) => r == null
          ? const _RulesExplainer()
          : RulesEditor(key: ValueKey(r.version), initial: r),
    );
  }
}

const rulesListPadding = EdgeInsets.fromLTRB(
  Gap.page,
  Gap.sm,
  Gap.page,
  Gap.xxl,
);

class _RulesExplainer extends ConsumerWidget {
  const _RulesExplainer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasAdb = ref.watch(activeHasAdbProvider);
    const items = [
      (Icons.apps_rounded, 'Allowed apps', 'Only the apps you pick open.'),
      (Icons.volume_down_rounded, 'Volume limit', 'A cap kids can\'t beat.'),
      (Icons.schedule_rounded, 'TV time', 'Daily limits and quiet hours.'),
      (
        Icons.visibility_off_rounded,
        'Sneaky or explicit',
        'Quietly stop, '
            'or show a friendly "TV time is over" card.'
      ),
    ];
    return ListView(
      padding: rulesListPadding,
      children: [
        InfoCard(
          padding: const EdgeInsets.all(Gap.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                StatusColors.of(context).ok.withValues(alpha: 0.14),
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
                    icon: Icons.shield_moon_rounded,
                    color: StatusColors.of(context).ok,
                    size: 52,
                  ),
                  const Spacer(),
                  const TagChip('Optional add-on', tone: Tone.ok),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Text('Rules run on TV Guard', style: text.headlineSmall),
              const SizedBox(height: Gap.sm),
              Text(
                'TV Guard is a small helper on the TV. Rules live there and '
                'work 24/7 — even when your phone is away or off.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Gap.lg),
              FilledButton.icon(
                key: const Key('rules-install'),
                onPressed: hasAdb
                    ? () => runAgentSetup(context, ref, repair: false)
                    : () => context.push('/adb-guide'),
                icon: Icon(
                  hasAdb ? Icons.download_rounded : Icons.lock_open_rounded,
                ),
                label: Text(hasAdb ? 'Install TV Guard' : 'Unlock with ADB'),
              ),
              if (!hasAdb) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  'Installing needs developer access to the TV first.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SectionHeader('What you can set'),
        GroupCard(
          children: [
            for (final (icon, title, body) in items)
              StatusRow(
                tone: Tone.idle,
                icon: icon,
                title: title,
                detail: body,
                detailLines: 2,
              ),
          ],
        ),
        const SectionHeader('Without TV Guard'),
        InfoCard(
          child: Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: scheme.primary),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'Use the Classic lock on the Now tab. It runs from this '
                  'phone while it\'s on home Wi-Fi.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
