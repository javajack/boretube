import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../agent/agent_client.dart';
import '../providers/agent_providers.dart';
import '../providers/tv_providers.dart';
import '../ui/components.dart';
import '../ui/controls.dart';
import '../ui/learn.dart';
import '../ui/tokens.dart';
import '../ui/tubby.dart';
import 'rules/rules_editor.dart';
import 'tab_header.dart';
import 'tv/tv_guard_card.dart';

/// The rules document on the active TV's agent.
final rulesProvider = FutureProvider.autoDispose<AgentRules?>((ref) async {
  final c = ref.watch(agentClientProvider);
  if (c == null) return null;
  return c.rules();
});

const _subtitle = 'Bedtime, TV time and apps, kept by the TV.';

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
        padding: const EdgeInsets.only(bottom: Gap.section),
        children: const [
          TabHeader(title: 'Routines', subtitle: _subtitle),
          Padding(
            padding: rulesListPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Skeleton(height: Sizes.band + Gap.hero, radius: Radii.hero),
                SizedBox(height: Gap.related),
                Skeleton(height: Sizes.chip),
                SizedBox(height: Gap.related),
                Skeleton(height: Sizes.row),
                SizedBox(height: Gap.f8),
                Skeleton(height: Sizes.row),
                SizedBox(height: Gap.f8),
                Skeleton(height: Sizes.row),
              ],
            ),
          ),
        ],
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.only(bottom: Gap.section),
        children: [
          const TabHeader(title: 'Routines', subtitle: _subtitle),
          Padding(
            padding: rulesListPadding,
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
  Gap.related,
  Gap.gutter,
  0,
);

class _RulesExplainer extends StatelessWidget {
  const _RulesExplainer();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: Gap.section),
        children: const [
          TabHeader(title: 'Routines', subtitle: _subtitle),
          Padding(padding: rulesListPadding, child: AlwaysOnPitch()),
        ],
      );
}

/// What Always On adds, as a plain list:
/// `(icon, title, one line)`.
const _whatYouCanSet = [
  (
    Icons.bedtime_rounded,
    'Bedtime and quiet hours',
    'The TV switches off on time, every night.',
  ),
  (
    Icons.timer_rounded,
    'Daily TV time',
    'A limit per day that the TV keeps by itself.',
  ),
  (Icons.apps_rounded, 'Allowed apps', 'Only the apps you pick open.'),
  (
    Icons.swipe_vertical_rounded,
    'Video hopping',
    'A gentle stop to endless quick videos.',
  ),
  (Icons.volume_down_rounded, 'Volume limit', 'A cap the remote can\'t beat.'),
  (
    Icons.chat_bubble_rounded,
    'How the TV says no',
    'Quietly, or with a friendly card.',
  ),
];

/// The Always On pitch: Tubby, one line, the button that gets there, and
/// what you can set. Plain on the canvas (or inside a sheet).
class AlwaysOnPitch extends ConsumerWidget {
  /// Runs before the install or guide opens (e.g. closing a sheet).
  final VoidCallback? onLeave;

  /// The context to start setup from, when this sits in a sheet.
  final BuildContext? host;

  const AlwaysOnPitch({super.key, this.onLeave, this.host});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final hasAdb = ref.watch(activeHasAdbProvider);
    void go() {
      final c = host ?? context;
      onLeave?.call();
      if (hasAdb) {
        runAgentSetup(c, ref, repair: false);
      } else {
        c.push('/adb-guide');
      }
    }

    return Column(
      key: const Key('always-on-pitch'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Tubby(mood: TubbyMood.guard, size: Sizes.tubby),
            const SizedBox(width: Gap.inside),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bedtimes that stick', style: text.headlineMedium),
                  const TermTitle('With Always On', LearnTerm.alwaysOn),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.inside),
        Text(
          'A tiny helper on the TV keeps routines running, even when your '
          'phone is away.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: Gap.related),
        PrimaryButton(
          key: const Key('rules-install'),
          label: hasAdb ? 'Make it Always On' : 'Unlock Home mode first',
          icon: hasAdb ? Icons.shield_rounded : Icons.home_rounded,
          kind: hasAdb ? ButtonKind.mint : ButtonKind.ink,
          onPressed: go,
        ),
        const SizedBox(height: Gap.f8),
        Text(
          hasAdb
              ? 'One tap here, one OK on the TV. Remove it any time.'
              : 'Always On needs Home mode on the TV first. About 3 min.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        const GroupHeading('What you can set'),
        RowList(
          children: [
            for (final (icon, title, body) in _whatYouCanSet)
              StatusRow(tone: Tone.ok, icon: icon, title: title, detail: body),
          ],
        ),
      ],
    );
  }
}

/// Always On as one slim row; the pitch opens in a sheet.
class AlwaysOnRow extends ConsumerWidget {
  const AlwaysOnRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAdb = ref.watch(activeHasAdbProvider);
    return RowList(
      edges: true,
      children: [
        NavRow(
          key: const Key('always-on-preview'),
          icon: Icons.shield_rounded,
          tone: Tone.ok,
          title: 'Routines that run by themselves',
          detail: 'Bedtimes that stick · '
              '${hasAdb ? 'one step away' : 'two steps away'}',
          onTap: () => showBtSheet<void>(
            context,
            builder: (sheet) => SheetScaffold(
              key: const Key('always-on-sheet'),
              title: 'Always On',
              children: [
                AlwaysOnPitch(
                  host: context,
                  onLeave: () => Navigator.pop(sheet),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
