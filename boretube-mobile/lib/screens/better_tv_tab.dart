import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/tokens.dart';
import 'tab_header.dart';
import 'tv/apps_section.dart';
import 'tv/health_section.dart';

/// Better TV: TV health (with Always On on top) and the apps, including
/// YouTube without Shorts. "Put the TV back" is one tap away.
///
/// PART A hosts the existing sections restyled; PART B redesigns them.
class BetterTvTab extends StatelessWidget {
  const BetterTvTab({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(
            title: 'Better TV',
            subtitle: 'A calmer, cleaner TV. Undo anything.',
            trailing: IconButton(
              key: const Key('better-tv-restore'),
              tooltip: 'Put the TV back the way it was',
              onPressed: () => context.push('/restore'),
              icon: const Icon(Icons.settings_backup_restore_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.xs,
              Gap.page,
              Gap.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(Gap.xs),
              decoration: BoxDecoration(
                color: bt.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: bt.border),
              ),
              child: const TabBar(
                labelPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
                tabs: [
                  Tab(height: 40, text: 'TV health'),
                  Tab(height: 40, text: 'Apps'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(children: [HealthSection(), AppsSection()]),
          ),
        ],
      ),
    );
  }
}
