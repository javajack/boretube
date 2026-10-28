import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/tv_ops.dart';
import '../../providers/agent_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tv_providers.dart';
import '../../providers/ui_providers.dart';
import '../../tv/tv.dart';
import '../rules_tab.dart';

/// The calm-TV plan, one step per protection the parent can add.
enum PlanStep { remote, unlockHome, noShorts, cleanTv, bedtime, alwaysOn }

extension PlanStepLook on PlanStep {
  String get title => switch (this) {
        PlanStep.remote => 'Control from your phone',
        PlanStep.unlockHome => 'Unlock Home mode',
        PlanStep.noShorts => 'YouTube without Shorts',
        PlanStep.cleanTv => 'Clean up your TV',
        PlanStep.bedtime => 'Set bedtime',
        PlanStep.alwaysOn => 'Turn on Always On',
      };

  String get hint => switch (this) {
        PlanStep.remote => 'Pause, Quiet and End app work now',
        PlanStep.unlockHome => 'One switch on the TV · about 3 minutes',
        PlanStep.noShorts => 'Keep YouTube, lose the endless scroll',
        PlanStep.cleanTv => 'Fewer promos, junk apps and slow menus',
        PlanStep.bedtime => 'The TV switches off on time, every night',
        PlanStep.alwaysOn => 'Rules keep running when you\'re out',
      };

  IconData get icon => switch (this) {
        PlanStep.remote => Icons.phone_android_rounded,
        PlanStep.unlockHome => Icons.home_rounded,
        PlanStep.noShorts => Icons.smart_display_rounded,
        PlanStep.cleanTv => Icons.cleaning_services_rounded,
        PlanStep.bedtime => Icons.bedtime_rounded,
        PlanStep.alwaysOn => Icons.shield_rounded,
      };

  /// Steps that must be done first.
  Set<PlanStep> get needs => switch (this) {
        PlanStep.remote => const {},
        PlanStep.unlockHome => const {PlanStep.remote},
        // Bedtime lives in the rules on the TV, so in practice setting it
        // also turns on Always On; the spec keeps it before Always On.
        PlanStep.noShorts ||
        PlanStep.cleanTv ||
        PlanStep.bedtime ||
        PlanStep.alwaysOn =>
          const {PlanStep.unlockHome},
      };
}

/// Which plan steps each worry pulls forward.
const goalSteps = <Goal, List<PlanStep>>{
  Goal.shorts: [PlanStep.noShorts],
  Goal.bedtime: [PlanStep.bedtime],
  Goal.loud: [PlanStep.alwaysOn],
  Goal.ads: [PlanStep.cleanTv],
  Goal.apps: [PlanStep.alwaysOn],
};

/// The default order from the spec, then pulled forward by [goals] (in the
/// order they were picked) without ever putting a step before what it
/// needs. Done steps don't move.
List<PlanStep> orderPlan(List<Goal> goals) {
  const base = PlanStep.values;
  final rank = <PlanStep, int>{};
  for (var i = 0; i < goals.length; i++) {
    for (final s in goalSteps[goals[i]] ?? const <PlanStep>[]) {
      rank.putIfAbsent(s, () => i);
    }
  }
  // A step is as urgent as the most urgent step that needs it.
  int urgency(PlanStep s) {
    var best = rank[s] ?? 1 << 20;
    for (final other in base) {
      if (other.needs.contains(s)) {
        final u = urgency(other);
        if (u < best) best = u;
      }
    }
    return best;
  }

  final out = <PlanStep>[];
  final left = [...base];
  while (left.isNotEmpty) {
    final ready = [
      for (final s in left)
        if (s.needs.every(out.contains)) s,
    ]..sort((a, b) {
        final u = urgency(a).compareTo(urgency(b));
        return u != 0 ? u : base.indexOf(a).compareTo(base.indexOf(b));
      });
    out.add(ready.first);
    left.remove(ready.first);
  }
  return out;
}

class PlanItem {
  final PlanStep step;
  final bool done;
  const PlanItem(this.step, this.done);
}

/// Whether each step is already done on the active TV.
Map<PlanStep, bool> planProgress({
  required Tv tv,
  required AgentLink link,
  AppState? stockYouTube,
  bool keepStockYouTube = false,
  bool cleanedUp = false,
  bool hasBedtime = false,
}) {
  final adb = tv.can(TvCapability.adb);
  return {
    PlanStep.remote: tv.capabilities.isNotEmpty,
    PlanStep.unlockHome: adb || link.installed,
    PlanStep.noShorts: keepStockYouTube ||
        stockYouTube == AppState.disabled ||
        stockYouTube == AppState.notInstalled ||
        stockYouTube == AppState.absent,
    PlanStep.cleanTv: cleanedUp,
    PlanStep.bedtime: hasBedtime,
    PlanStep.alwaysOn: link.installed,
  };
}

/// The plan for the active TV, ordered by the parent's goals.
final planProvider = Provider<List<PlanItem>>((ref) {
  final tv = ref.watch(activeTvProvider);
  if (tv == null) return const [];
  final link = ref.watch(agentStatusProvider);
  final yt = ref.watch(stockYouTubeStateProvider).valueOrNull;
  final keep = ref.watch(
    appSettingsProvider.select((s) => s.allowStockYouTube.contains(tv.id)),
  );
  final journal = ref.watch(journalEntriesProvider).valueOrNull ?? const [];
  final cleaned = journal.any((e) => e.op == 'applyCleanup' && e.ok);
  final rules = link.installed ? ref.watch(rulesProvider).valueOrNull : null;
  final progress = planProgress(
    tv: tv,
    link: link,
    stockYouTube: yt,
    keepStockYouTube: keep,
    cleanedUp: cleaned,
    hasBedtime: rules?.tvTime.schedule.isNotEmpty ?? false,
  );
  return [
    for (final s in orderPlan(ref.watch(goalsProvider)))
      PlanItem(s, progress[s] ?? false),
  ];
});
