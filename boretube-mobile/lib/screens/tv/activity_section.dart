import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/agent_models.dart';
import '../../providers/agent_providers.dart';
import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';
import '../../ops/journal.dart';
import 'common.dart';

/// Phone and Always On journals together, newest first. What TV Guard did
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
                      tubby: TubbyMood.calm,
                      title: 'Nothing has happened yet',
                      message: 'Every change boretube or Always On makes to '
                          'the TV shows up here, with what it was before. '
                          'So you can always see, and undo.',
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

/// Who made a change: "Phone", "Always On", "Tidy-up" or "Routine".
(String, Tone) sourceBadge(JournalSource s) => switch (s) {
      JournalSource.phone => ('Phone', Tone.idle),
      JournalSource.agent => ('Always On', Tone.ok),
      JournalSource.watchdog => ('Tidy-up', Tone.info),
      JournalSource.rule => ('Routine', Tone.warn),
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

/// One phone journal entry as a status row.
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
