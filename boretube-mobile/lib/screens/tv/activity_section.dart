import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tv_providers.dart';
import '../../ui/components.dart';
import '../now/now_tab.dart';
import 'common.dart';

/// The TV journal, newest first.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(journalEntriesProvider.future),
      child: ListView(
        padding: tvListPadding,
        children: [
          ...entries.when(
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
            data: (list) => list.isEmpty
                ? const [
                    InfoCard(
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No activity yet',
                        message: 'Every change Boretube makes to the TV — '
                            'with before and after — is listed here.',
                      ),
                    ),
                  ]
                : [
                    SectionHeader('${list.length} changes'),
                    GroupCard(
                      children: [
                        for (final e in list)
                          JournalRow(entry: e, expanded: true),
                      ],
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
