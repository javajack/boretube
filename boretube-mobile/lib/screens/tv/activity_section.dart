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

/// Phone and Always On journals together, newest first. What Always On
/// did since the app was last opened is grouped as "While you were away".
/// Plain rows on the canvas; the page around it scrolls.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  /// Reloads both journals (for the page's pull to refresh).
  static Future<void> refresh(WidgetRef ref) async {
    ref.invalidate(journalEntriesProvider);
    ref.invalidate(agentJournalProvider);
    await ref.read(activityProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(activityProvider);
    final since = ref.watch(previousVisitProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.when(
          loading: () => const [SkeletonCard(rows: 5)],
          error: (e, _) => [
            EmptyState(
              icon: Icons.history_toggle_off_rounded,
              tone: Tone.bad,
              title: 'Couldn\'t load activity',
              message: '$e',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(journalEntriesProvider),
            ),
          ],
          data: (list) {
            if (list.isEmpty) {
              return const [HistoryExplainer()];
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
                GroupHeading(
                  'While you were away · ${away.length}',
                  first: true,
                ),
                RowList(
                  key: const Key('activity-away'),
                  children: [
                    for (final i in away) ActivityRow(item: i),
                  ],
                ),
              ],
              GroupHeading(
                away.isEmpty
                    ? '${rest.length} changes'
                    : 'Earlier · ${rest.length}',
                first: away.isEmpty,
              ),
              RowList(
                children: [
                  for (final i in rest) ActivityRow(item: i),
                ],
              ),
            ];
          },
        ),
      ],
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

/// History before anything happened: what will show up here, with a
/// faded example of each kind, and the promise behind it.
class HistoryExplainer extends StatelessWidget {
  const HistoryExplainer({super.key});

  static const _examples = [
    (
      Icons.close_rounded,
      'SmartTube closed at bedtime',
      'Routine',
      Tone.warn,
    ),
    (
      Icons.volume_down_rounded,
      'Volume brought back to 30%',
      'Always On',
      Tone.ok,
    ),
    (
      Icons.auto_awesome_rounded,
      'Sony promo banners switched off',
      'Phone',
      Tone.idle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('history-explainer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EmptyState(
          icon: Icons.history_rounded,
          tubby: TubbyMood.calm,
          title: 'Nothing has happened yet',
          message: 'Every change to the TV lands here, with what it was '
              'before.',
        ),
        const GroupHeading('What you\'ll see here', first: true),
        ExcludeSemantics(
          child: Opacity(
            opacity: Phi.major,
            child: RowList(
              children: [
                for (final (icon, title, who, tone) in _examples)
                  StatusRow(
                    tone: tone == Tone.idle ? Tone.info : tone,
                    icon: icon,
                    title: title,
                    detail: 'Example · before → after',
                    trailing: TagChip(who, tone: tone),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.related),
        Row(
          children: [
            Icon(Icons.undo_rounded, size: Sizes.iconSmall, color: bt.muted),
            const SizedBox(width: Gap.f8),
            Expanded(
              child: Text(
                'Undo it all from Better TV › Put the TV back.',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
