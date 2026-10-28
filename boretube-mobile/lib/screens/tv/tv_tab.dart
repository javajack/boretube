import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import 'activity_section.dart';
import 'apps_section.dart';
import 'health_section.dart';
import 'settings_section.dart';

/// Health · Apps · Activity · Settings.
class TvTab extends StatelessWidget {
  const TvTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
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
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
                tabs: [
                  Tab(height: 40, text: 'Health'),
                  Tab(height: 40, text: 'Apps'),
                  Tab(height: 40, text: 'Activity'),
                  Tab(height: 40, text: 'Settings'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                HealthSection(),
                AppsSection(),
                ActivitySection(),
                SettingsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
