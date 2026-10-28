import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_providers.dart';
import '../ui/learn.dart';
import '../ui/tokens.dart';
import 'now/classic_lock_card.dart';
import 'rules_tab.dart';
import 'tab_header.dart';

/// Routines: the Always On rules (a day ribbon and one row per rule), or
/// "Lock for a while" from this phone with Always On as one slim row.
class RoutinesTab extends ConsumerWidget {
  const RoutinesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hasAgentProvider)) return const RulesTab();
    return ListView(
      key: const Key('routines-list'),
      padding: const EdgeInsets.only(bottom: Gap.section),
      children: const [
        TabHeader(
          title: 'Routines',
          subtitle: 'This phone keeps watch.',
          trailing: InfoDot(LearnTerm.alwaysOn),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(Gap.gutter, Gap.related, Gap.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClassicLockCard(),
              SizedBox(height: Gap.section),
              AlwaysOnRow(),
            ],
          ),
        ),
      ],
    );
  }
}
