import 'package:flutter/material.dart';

import '../../providers/nudges.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import '../../ui/tubby.dart';

/// Tubby's mood for a nudge.
TubbyMood nudgeMood(NudgeId id) => switch (id) {
      NudgeId.bedtime || NudgeId.weekendPreset => TubbyMood.asleep,
      NudgeId.cleanTv || NudgeId.noShorts => TubbyMood.cleaning,
      NudgeId.alwaysOn || NudgeId.reviewUpdate => TubbyMood.guard,
      _ => TubbyMood.calm,
    };

/// One gentle suggestion at the top of Home: a small Tubby, a line, the
/// one thing to do, and "Not now". Swiping it away also means "Not now".
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
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: Radii.control,
        border: Border.all(color: bt.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.7],
          colors: [bt.coralWash, bt.surface],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(Gap.f13, Gap.f13, Gap.f8, Gap.f13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tubby(
                mood: nudgeMood(nudge.id),
                size: 44,
                antennas: false,
                legs: false,
                animate: false,
              ),
              const SizedBox(width: Gap.f13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nudge.title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      nudge.message,
                      style: text.bodyMedium!.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.f13),
          Padding(
            padding: const EdgeInsets.only(left: 44 + Gap.f13),
            child: Wrap(
              spacing: Gap.f4,
              runSpacing: Gap.f4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IntrinsicWidth(
                  child: PrimaryButton(
                    key: const Key('nudge-act'),
                    label: nudge.action,
                    kind: ButtonKind.ink,
                    height: 48,
                    onPressed: onAct,
                  ),
                ),
                TextButton(
                  key: const Key('nudge-not-now'),
                  style: TextButton.styleFrom(foregroundColor: bt.muted),
                  onPressed: onNotNow,
                  child: const Text('Not now'),
                ),
              ],
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
        child: card,
      ),
    );
  }
}
