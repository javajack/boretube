import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../agent/agent_client.dart';
import '../providers/agent_providers.dart';
import '../providers/tv_providers.dart';
import '../ui/components.dart';
import '../ui/learn.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'rules/rules_editor.dart';
import 'tv/tv_guard_card.dart';

/// The rules document on the active TV's agent.
final rulesProvider = FutureProvider.autoDispose<AgentRules?>((ref) async {
  final c = ref.watch(agentClientProvider);
  if (c == null) return null;
  return c.rules();
});

/// Routines on Always On TVs; a preview and the way there elsewhere.
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
          SizedBox(height: Gap.f13),
          SkeletonCard(rows: 3),
          SizedBox(height: Gap.f13),
          SkeletonCard(rows: 3),
        ],
      ),
      error: (e, _) => ListView(
        padding: rulesListPadding,
        children: [
          Surface(
            child: EmptyState(
              icon: Icons.portable_wifi_off_rounded,
              tone: Tone.bad,
              title: 'Couldn\'t reach Always On',
              message: e is AgentAuthException
                  ? 'Always On doesn\'t recognise this phone. Use Repair '
                      'in Better TV.'
                  : 'Routines keep running on the TV. Check it\'s on, then '
                      'try again.',
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
  Gap.gutter,
  Gap.f8,
  Gap.gutter,
  Gap.f34,
);

class _RulesExplainer extends StatelessWidget {
  const _RulesExplainer();

  @override
  Widget build(BuildContext context) => ListView(
        padding: rulesListPadding,
        children: const [AlwaysOnPreview()],
      );
}

/// What Always On adds, with the one button that gets there.
class AlwaysOnPreview extends ConsumerWidget {
  const AlwaysOnPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final bt = context.bt;
    final hasAdb = ref.watch(activeHasAdbProvider);
    const items = [
      (
        Icons.bedtime_rounded,
        'Bedtime and quiet hours',
        'The TV switches '
            'off on time, every night.'
      ),
      (
        Icons.timer_rounded,
        'Daily TV time',
        'A limit per day that the TV '
            'keeps by itself.'
      ),
      (Icons.apps_rounded, 'Allowed apps', 'Only the apps you pick open.'),
      (
        Icons.swipe_vertical_rounded,
        'Shorts',
        'Stop them, allow a few a day, or just count them.',
      ),
      (
        Icons.volume_down_rounded,
        'Volume limit',
        'A cap the remote can\'t '
            'beat.'
      ),
      (
        Icons.chat_bubble_rounded,
        'How the TV says no',
        'Quietly, or with a friendly "TV time is over" card.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          key: const Key('always-on-preview'),
          padding: const EdgeInsets.all(Gap.f21),
          radius: Radii.hero,
          gradient: LinearGradient(
            begin: const Alignment(-0.6, -1),
            end: const Alignment(0.6, 1),
            stops: const [0, 0.75],
            colors: [bt.mintTint, bt.surface],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Tubby(mood: TubbyMood.guard, size: 64),
                  const Spacer(),
                  BtBadge(
                    hasAdb ? 'One step away' : 'Two steps away',
                    tone: Tone.ok,
                    icon: Icons.shield_rounded,
                  ),
                ],
              ),
              const SizedBox(height: Gap.f13),
              Text('Bedtimes that stick', style: text.headlineMedium),
              const SizedBox(height: Gap.f4),
              const TermTitle('With Always On', LearnTerm.alwaysOn),
              const SizedBox(height: Gap.f8),
              Text(
                'Always On is a tiny helper on the TV. Routines live there '
                'and keep working when your phone is away or switched off.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Gap.f13),
              PrimaryButton(
                key: const Key('rules-install'),
                label: hasAdb ? 'Make it Always On' : 'Unlock Home mode first',
                icon: hasAdb ? Icons.shield_rounded : Icons.home_rounded,
                kind: hasAdb ? ButtonKind.mint : ButtonKind.ink,
                onPressed: hasAdb
                    ? () => runAgentSetup(context, ref, repair: false)
                    : () => context.push('/adb-guide'),
              ),
              const SizedBox(height: Gap.f8),
              Text(
                hasAdb
                    ? 'One tap here, one OK on the TV. Remove it any time.'
                    : 'Always On needs Home mode on the TV first. About 3 '
                        'minutes.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const GroupHeading('What you can set'),
        RowList(
          children: [
            for (final (icon, title, body) in items)
              StatusRow(
                tone: Tone.ok,
                icon: icon,
                title: title,
                detail: body,
                detailLines: 2,
              ),
          ],
        ),
      ],
    );
  }
}
