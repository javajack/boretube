import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/tokens.dart';
import 'home_logic.dart';
import 'plan.dart';

/// One row of the Today strip: an icon, rich text with a bold part.
typedef TodayLine = ({
  IconData icon,
  Color color,
  String before,
  String bold,
  String after,
});

/// Today: next routine, TV time, what was stopped, and History.
class TodayStrip extends StatelessWidget {
  final List<TodayLine> lines;
  final VoidCallback onHistory;

  const TodayStrip({super.key, required this.lines, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final shown = lines.isEmpty
        ? <TodayLine>[
            (
              icon: Icons.wb_sunny_rounded,
              color: bt.sunInk,
              before: 'A calm day so far',
              bold: '',
              after: '',
            ),
          ]
        : lines;
    Widget line(TodayLine l, {bool last = false, VoidCallback? onTap}) {
      final row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(l.icon, size: 20, color: l.color),
            const SizedBox(width: Gap.f13),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.f8),
                child: Text.rich(
                  TextSpan(
                    style: text.bodyMedium!.copyWith(color: bt.ink),
                    children: [
                      TextSpan(text: l.before),
                      TextSpan(
                        text: l.bold,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: l.after),
                    ],
                  ),
                ),
              ),
            ),
            if (onTap != null)
              Text(
                'History ›',
                style: text.labelLarge!.copyWith(
                  fontSize: 14,
                  color: bt.skyInk,
                ),
              ),
          ],
        ),
      );
      return onTap == null
          ? row
          : Semantics(
              button: true,
              label: 'Open History',
              child: InkWell(onTap: onTap, child: row),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupHeading(
          'Today',
        ),
        Surface(
          key: const Key('today-strip'),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.f13 + 2,
            vertical: Gap.f4,
          ),
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(),
                line(
                  shown[i],
                  onTap: i == shown.length - 1 ? onHistory : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The calm-TV plan, until it is done.
class PlanCard extends StatelessWidget {
  final List<PlanItem> items;
  final void Function(PlanStep step) onStep;

  const PlanCard({super.key, required this.items, required this.onStep});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final done = items.where((i) => i.done).length;
    final next = items.where((i) => !i.done).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeading(
          'Your calm-TV plan',
          trailing: Text(
            '$done of ${items.length} done',
            style: text.labelMedium,
          ),
        ),
        Surface(
          key: const Key('plan-card'),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.f13,
                  Gap.f13,
                  Gap.f13,
                  Gap.f8,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: Gap.f4),
                      Expanded(
                        child: AnimatedContainer(
                          duration: Motion.of(context, Motion.sheet),
                          height: 6,
                          decoration: BoxDecoration(
                            color: items[i].done ? bt.mint : bt.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (final item in items)
                _PlanRow(
                  item: item,
                  isNext: identical(item, next),
                  onTap: item.done ? null : () => onStep(item.step),
                ),
              const SizedBox(height: Gap.f4),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  final PlanItem item;
  final bool isNext;
  final VoidCallback? onTap;

  const _PlanRow({required this.item, required this.isNext, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final s = item.step;
    return Semantics(
      button: onTap != null,
      label: '${s.title}${item.done ? ', done' : ''}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('plan-${s.name}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.f13,
              vertical: Gap.f8,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.sheet),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.done ? bt.mint : Colors.transparent,
                    border: item.done
                        ? null
                        : Border.all(
                            color: isNext ? bt.coral : bt.borderStrong,
                            width: 2,
                          ),
                  ),
                  child: item.done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : Icon(
                          s.icon,
                          size: 14,
                          color: isNext ? bt.coralInk : bt.muted,
                        ),
                ),
                const SizedBox(width: Gap.f13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: text.titleSmall!.copyWith(
                          fontWeight:
                              isNext ? FontWeight.w700 : FontWeight.w600,
                          color: item.done ? bt.muted : bt.ink,
                        ),
                      ),
                      if (!item.done)
                        Text(
                          s.hint,
                          style: text.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isNext)
                  const Padding(
                    padding: EdgeInsets.only(left: Gap.f8),
                    child: BtBadge('Next', tone: Tone.accent),
                  )
                else if (!item.done)
                  Icon(Icons.chevron_right_rounded, color: bt.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "During this break": what the TV stopped while paused.
class DuringBreakCard extends StatelessWidget {
  final List<String> lines;

  const DuringBreakCard({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Surface(
      key: const Key('during-break'),
      padding: const EdgeInsets.fromLTRB(Gap.f13, Gap.f13 + 2, Gap.f13, Gap.f8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DURING THIS BREAK', style: text.labelSmall),
          const SizedBox(height: Gap.f4),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.f8),
              child: Text(
                'Nothing to stop so far. Anything the TV closes shows up '
                'here.',
                style: text.bodyMedium,
              ),
            )
          else
            for (final l in lines) CheckLine(l, done: true, minHeight: 36),
        ],
      ),
    );
  }
}

/// While something is broken: what still works, honestly.
class StillWorkingCard extends StatelessWidget {
  final List<(String, bool)> lines;
  final Protection protection;
  final VoidCallback onBadge;

  const StillWorkingCard({
    super.key,
    required this.lines,
    required this.protection,
    required this.onBadge,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Surface(
      key: const Key('still-working'),
      padding: const EdgeInsets.fromLTRB(Gap.f13, Gap.f13, Gap.f13, Gap.f8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Still working',
                  style: text.labelMedium!.copyWith(fontSize: 13),
                ),
              ),
              // Grey, not mint: the level is what's broken right now.
              BtBadge(
                protection.label,
                tone: Tone.idle,
                icon: protection.icon,
                onTap: onBadge,
              ),
            ],
          ),
          const SizedBox(height: Gap.f4),
          for (final (l, ok) in lines) CheckLine(l, done: ok, minHeight: 36),
        ],
      ),
    );
  }
}
