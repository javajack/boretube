import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_providers.dart';
import '../ui/components.dart';
import '../ui/learn.dart';
import '../ui/tokens.dart';
import 'now/classic_lock_card.dart';
import 'rules_tab.dart';
import 'tab_header.dart';

/// Routines: the Always On rules, or "Lock for a while" from this phone.
///
class RoutinesTab extends ConsumerWidget {
  const RoutinesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alwaysOn = ref.watch(hasAgentProvider);
    if (alwaysOn) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(
            title: 'Routines',
            subtitle: 'Bedtime, TV time and apps, kept by the TV.',
          ),
          Expanded(child: RulesTab()),
        ],
      );
    }
    return ListView(
      key: const Key('routines-list'),
      padding: const EdgeInsets.only(bottom: Gap.xxl),
      children: const [
        TabHeader(
          title: 'Routines',
          subtitle: 'Lock the TV for a while from this phone.',
          trailing: InfoDot(LearnTerm.alwaysOn),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Gap.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                'Lock for a while',
                padding: EdgeInsets.fromLTRB(Gap.xs, Gap.sm, Gap.xs, Gap.sm),
              ),
              ClassicLockCard(),
              SectionHeader('Routines that run by themselves'),
              AlwaysOnPreview(),
            ],
          ),
        ),
      ],
    );
  }
}
