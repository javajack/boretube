import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_models.dart';
import '../../providers/agent_providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import 'common.dart';

/// Phone and TV Guard journals together, newest first. What TV Guard did
/// since the app was last opened is grouped as "While you were away".
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(activityProvider);
    final since = ref.watch(previousVisitProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(journalEntriesProvider);
        ref.invalidate(agentJournalProvider);
        await ref.read(activityProvider.future);
      },
      child: ListView(
        padding: tvListPadding,
        children: [
          ...items.when(
            loading: () => const [SkeletonCard(rows: 5)],
            error: (e, _) => [
              InfoCard(
                child: EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  tone: Tone.bad,
                  title: 'Couldn\'t load activity',
                  message: '$e',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(journalEntriesProvider),
                ),
              ),
            ],
            data: (list) {
              if (list.isEmpty) {
                return const [
                  InfoCard(
                    child: EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No activity yet',
                      message: 'Every change Boretube or TV Guard makes to '
                          'the TV — with before and after — is listed here.',
                    ),
                  ),
                ];
              }
              final away = [
                for (final i in list)
                  if (since != null &&
                      i.source != JournalSource.phone &&
                      i.entry.time.isAfter(since))
                    i,
              ];
              final rest = [
                for (final i in list)
                  if (!away.contains(i)) i,
              ];
              return [
                if (away.isNotEmpty) ...[
                  SectionHeader(
                    'While you were away · ${away.length}',
                    padding: const EdgeInsets.fromLTRB(
                      Gap.xs,
                      Gap.sm,
                      Gap.xs,
                      Gap.sm,
                    ),
                  ),
                  GroupCard(
                    key: const Key('activity-away'),
                    children: [
                      for (final i in away) ActivityRow(item: i),
                    ],
                  ),
                ],
                SectionHeader(
                  away.isEmpty
                      ? '${rest.length} changes'
                      : 'Earlier · ${rest.length}',
                ),
                GroupCard(
                  children: [
                    for (final i in rest) ActivityRow(item: i),
                  ],
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

/// "Phone" / "TV Guard" / "Watchdog" / "Rule".
(String, Tone) sourceBadge(JournalSource s) => switch (s) {
      JournalSource.phone => ('Phone', Tone.idle),
      JournalSource.agent => ('TV Guard', Tone.ok),
      JournalSource.watchdog => ('Watchdog', Tone.info),
      JournalSource.rule => ('Rule', Tone.warn),
    };

class ActivityRow extends StatelessWidget {
  final ActivityItem item;
  final bool expanded;

  const ActivityRow({super.key, required this.item, this.expanded = true});

  @override
  Widget build(BuildContext context) {
    final e = item.entry;
    final (label, tone) = sourceBadge(item.source);
    final change = e.before.isEmpty && e.after.isEmpty
        ? ''
        : ' · ${e.before} → ${e.after}';
    return StatusRow(
      tone: e.ok ? Tone.ok : Tone.bad,
      icon: journalIcon(e.op),
      title: journalTitle(e),
      detail:
          expanded ? '${relativeTime(e.time)}$change' : relativeTime(e.time),
      detailLines: expanded ? 3 : 1,
      trailing: TagChip(label, tone: tone),
    );
  }
}
