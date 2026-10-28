import 'package:flutter/material.dart';

import '../../providers/nudges.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';

/// Tubby's mood for a nudge.
TubbyMood nudgeMood(NudgeId id) => switch (id) {
      NudgeId.bedtime || NudgeId.weekendPreset => TubbyMood.asleep,
      NudgeId.cleanTv || NudgeId.noShorts => TubbyMood.cleaning,
      NudgeId.alwaysOn || NudgeId.reviewUpdate => TubbyMood.guard,
      _ => TubbyMood.calm,
    };

/// One gentle suggestion at the top of Home, as a slim inline banner: a
/// small Tubby, one line, the one thing to do, and a quiet close ("Not
/// now"). Swiping it away also means "Not now".
class NudgeCard extends StatelessWidget {
  final Nudge nudge;
  final VoidCallback onAct;
  final VoidCallback onNotNow;

  const NudgeCard({
    super.key,
    required this.nudge,
    required this.onAct,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final banner = Container(
      decoration: BoxDecoration(
        color: bt.coralWash,
        borderRadius: Radii.control,
      ),
      padding: const EdgeInsets.fromLTRB(Gap.f13, Gap.f8, Gap.f4, Gap.f8),
      child: Row(
        children: [
          Tubby(
            mood: nudgeMood(nudge.id),
            size: Sizes.tubbySmall,
            antennas: false,
            legs: false,
            animate: false,
          ),
          const SizedBox(width: Gap.f13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nudge.title,
                  style: text.titleSmall!.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  nudge.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                const SizedBox(height: Gap.f4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('nudge-act'),
                    style: TextButton.styleFrom(
                      foregroundColor: bt.coralInk,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(Sizes.touch, Sizes.chip),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed: onAct,
                    child: Text(nudge.action),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Not now',
            excludeSemantics: true,
            child: IconButton(
              key: const Key('nudge-not-now'),
              onPressed: onNotNow,
              icon:
                  Icon(Icons.close_rounded, size: Sizes.icon, color: bt.muted),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: 'Suggestion',
      child: Dismissible(
        key: ValueKey('nudge-${nudge.id.name}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => onNotNow(),
        child: banner,
      ),
    );
  }
}
