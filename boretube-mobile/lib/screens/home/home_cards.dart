import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/tokens.dart';
import 'home_logic.dart';
import 'plan.dart';

/// One line of Today: an icon, rich text with a bold part.
typedef TodayLine = ({
  IconData icon,
  Color color,
  String before,
  String bold,
  String after,
});

/// Today as plain lines on the canvas: next routine, TV time, what was
/// stopped, and a way into History. No card.
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
    Widget line(int i, TodayLine l, {VoidCallback? onTap}) {
      final row = ListRow(
        leading: Icon(l.icon, size: Sizes.icon, color: l.color),
        title: '${l.before}${l.bold}${l.after}',
        titleWidget: Text.rich(
          TextSpan(
            style: text.bodyMedium!.copyWith(color: bt.ink),
            children: [
              TextSpan(text: l.before),
              TextSpan(
                text: l.bold,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: Fonts.tabular,
                ),
              ),
              TextSpan(text: l.after),
            ],
          ),
        ),
        chevron: false,
        onTap: onTap,
        trailing: onTap == null
            ? null
            : Text(
                'History',
                style: text.labelLarge!.copyWith(color: bt.skyInk),
              ),
      );
      return StaggerIn(
        index: i,
        child: onTap == null
            ? row
            : Semantics(button: true, label: 'Open History', child: row),
      );
    }

    return Column(
      key: const Key('today-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupHeading('Today'),
        RowList(
          children: [
            for (var i = 0; i < shown.length; i++)
              line(
                i,
                shown[i],
                onTap: i == shown.length - 1 ? onHistory : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// The calm-TV plan as a slim card, until it is done: one thin bar,
/// "4 of 6", and the next step. The rest open in place.
class PlanCard extends StatefulWidget {
  final List<PlanItem> items;
  final void Function(PlanStep step) onStep;

  const PlanCard({super.key, required this.items, required this.onStep});

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final items = widget.items;
    final done = items.where((i) => i.done).length;
    final next = items.where((i) => !i.done).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.section),
      child: Surface(
        key: const Key('plan-card'),
        padding: const EdgeInsets.fromLTRB(
          Gap.related,
          Gap.related,
          Gap.related,
          Gap.f4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Your calm-TV plan',
                      style: text.titleMedium,
                    ),
                  ),
                ),
                Text(
                  '$done of ${items.length} done',
                  style: text.labelMedium!.copyWith(
                    fontFeatures: Fonts.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.f13),
            ThinProgress(value: done / items.length),
            const SizedBox(height: Gap.f4),
            AnimatedSize(
              duration: Motion.of(context, Motion.sheet),
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: RowList(
                children: [
                  for (final item in items)
                    if (_all || identical(item, next))
                      _PlanRow(
                        item: item,
                        isNext: identical(item, next),
                        onTap:
                            item.done ? null : () => widget.onStep(item.step),
                      ),
                ],
              ),
            ),
            if (items.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('plan-toggle'),
                  style: TextButton.styleFrom(
                    foregroundColor: bt.muted,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => setState(() => _all = !_all),
                  child: Text(_all ? 'Show less' : 'See all steps'),
                ),
              ),
          ],
        ),
      ),
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
    final s = item.step;
    return Semantics(
      button: onTap != null,
      label: '${s.title}${item.done ? ', done' : ''}',
      excludeSemantics: true,
      child: ListRow(
        key: Key('plan-${s.name}'),
        leading: AnimatedSwitcher(
          duration: Motion.of(context, Motion.flip),
          child: Icon(
            item.done ? Icons.check_circle_rounded : s.icon,
            key: ValueKey(item.done),
            size: Sizes.icon,
            color: item.done
                ? bt.mint
                : isNext
                    ? bt.coralInk
                    : bt.muted,
          ),
        ),
        title: s.title,
        titleWidget: Text(
          s.title,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                color: item.done ? bt.muted : bt.ink,
              ),
        ),
        subtitle: item.done
            ? null
            : isNext
                ? 'Next · ${s.hint}'
                : s.hint,
        onTap: onTap,
        chevron: false,
        trailing: item.done
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                size: Sizes.icon,
                color: bt.faint,
              ),
      ),
    );
  }
}

/// "During this break": what the TV stopped while paused, as plain lines.
class DuringBreakCard extends StatelessWidget {
  final List<String> lines;

  const DuringBreakCard({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      key: const Key('during-break'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupHeading('During this break'),
        if (lines.isEmpty)
          Text(
            'Nothing to stop so far. Anything the TV closes shows up here.',
            style: text.bodySmall,
          )
        else
          for (var i = 0; i < lines.length; i++)
            StaggerIn(index: i, child: CheckLine(lines[i], done: true)),
      ],
    );
  }
}

/// While something is broken: what still works, honestly, as plain lines.
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
    return Column(
      key: const Key('still-working'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupHeading(
          'Still working',
          first: true,
          // Grey, not mint: the level is what's broken right now.
          trailing: BtBadge(
            protection.label,
            tone: Tone.idle,
            icon: protection.icon,
            onTap: onBadge,
          ),
        ),
        for (final (l, ok) in lines) CheckLine(l, done: ok),
      ],
    );
  }
}
