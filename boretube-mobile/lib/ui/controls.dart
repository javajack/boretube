import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'tokens.dart';

/// A segmented control in the house style: a warm track with a white
/// thumb that slides to the choice. Each segment is a 48 dp target.
class SegmentChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final String? keyPrefix;

  /// Segments per row; more options wrap onto a second row (four longer
  /// labels as a 2×2 at phone width). Null keeps them all on one row.
  final int? columns;

  const SegmentChoice({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.keyPrefix,
    this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final i = options.indexWhere((o) => o.$1 == value).clamp(0, 99);
    final n = options.length;
    final cols = (columns ?? n).clamp(1, n);
    final rows = (n / cols).ceil();
    final col = i % cols;
    final row = i ~/ cols;

    Widget segment((T, String) o) {
      final (v, label) = o;
      return Expanded(
        child: Semantics(
          button: true,
          selected: v == value,
          child: InkWell(
            key: keyPrefix == null
                ? null
                : Key('$keyPrefix-${v is Enum ? v.name : v}'),
            borderRadius: BorderRadius.circular(Radii.button - 3),
            onTap: onChanged == null || v == value
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged!(v);
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.xs,
                    vertical: Gap.sm,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.fast),
                    style: text.labelLarge!.copyWith(
                      fontSize: 14,
                      color: v == value ? bt.ink : bt.muted,
                      fontWeight:
                          v == value ? FontWeight.w700 : FontWeight.w600,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bt.hairline,
        borderRadius: Radii.buttons,
        border: Border.all(color: bt.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.spring,
              alignment: Alignment(
                cols == 1 ? 0 : -1 + 2 * col / (cols - 1),
                rows == 1 ? 0 : -1 + 2 * row / (rows - 1),
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / cols,
                heightFactor: 1 / rows,
                child: Container(
                  decoration: BoxDecoration(
                    color: bt.surface,
                    borderRadius: BorderRadius.circular(Radii.button - 3),
                    border: Border.all(color: bt.borderStrong),
                  ),
                ),
              ),
            ),
          ),
          if (rows == 1)
            Row(children: [for (final o in options) segment(o)])
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < rows; r++)
                  Row(
                    children: [
                      for (var c = 0; c < cols; c++)
                        if (r * cols + c < n)
                          segment(options[r * cols + c])
                        else
                          const Spacer(),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// − N + : a small whole-number stepper with a unit ("5 per day").
class CountStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int>? onChanged;
  final String? keyPrefix;

  const CountStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.onChanged,
    this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    Widget button(IconData icon, String label, int to, String id) {
      final on = onChanged != null && to >= min && to <= max && to != value;
      return Semantics(
        button: true,
        enabled: on,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: on ? bt.surface : bt.hairline,
          shape: CircleBorder(
            side: BorderSide(color: on ? bt.borderStrong : bt.border, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: keyPrefix == null ? null : Key('$keyPrefix-$id'),
            onTap: on
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged!(to);
                  }
                : null,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, size: 22, color: on ? bt.ink : bt.faint),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      value: '$value $unit',
      child: Row(
        children: [
          button(Icons.remove_rounded, 'Fewer', value - 1, 'minus'),
          Expanded(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(a),
                      child: c,
                    ),
                  ),
                  child: Text(
                    '$value',
                    key: ValueKey(value),
                    style: Fonts.bricolage(
                      28,
                      color: bt.ink,
                      height: 1,
                      tabularFigures: true,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(unit, style: text.bodySmall),
              ],
            ),
          ),
          button(Icons.add_rounded, 'More', value + 1, 'plus'),
        ],
      ),
    );
  }
}

/// A small pill that is either "the one picked" (ink fill) or an option
/// (outlined). For presets and filters.
class InkPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const InkPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final fg = selected ? bt.onInkFill : bt.ink;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.settle,
        decoration: ShapeDecoration(
          color: selected ? bt.inkFill : bt.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? bt.inkFill : bt.borderStrong,
              width: 2,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      style: text.labelLarge!.copyWith(
                        fontSize: 14,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings card: tinted icon tile, title, a big value on the right, and
/// whatever controls go underneath.
class SettingCard extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final Widget title;
  final String? value;
  final Widget? trailing;
  final List<Widget> children;
  final bool dim;

  const SettingCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    this.value,
    this.trailing,
    this.children = const [],
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: icon,
                color: dim ? bt.muted : tone.color(context),
                size: 40,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: text.titleMedium!.copyWith(fontSize: 17),
                  child: title,
                ),
              ),
              if (value != null)
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: Text(
                    value!,
                    key: ValueKey(value),
                    style: Fonts.bricolage(
                      20,
                      color: dim ? bt.muted : bt.ink,
                      tabularFigures: true,
                    ),
                  ),
                ),
              if (trailing != null) ...[
                const SizedBox(width: Gap.sm),
                trailing!,
              ],
            ],
          ),
          if (children.isNotEmpty) const SizedBox(height: Gap.md),
          ...children,
        ],
      ),
    );
  }
}

/// A title, a line under it, and a switch; the whole row toggles.
class SwitchLine extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;

  const SwitchLine({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        borderRadius: Radii.tile,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Gap.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.titleSmall),
                      if (subtitle != null)
                        AnimatedSwitcher(
                          duration: Motion.of(context, Motion.fast),
                          layoutBuilder: (c, prev) => Stack(
                            alignment: Alignment.topLeft,
                            children: [...prev, if (c != null) c],
                          ),
                          child: Text(
                            subtitle!,
                            key: ValueKey(subtitle),
                            style: text.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "+ Add" with a dashed outline: something you can add more of.
class DashedAdd extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool expand;

  const DashedAdd({
    super.key,
    required this.label,
    this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final radius = expand ? Radii.tileR : 22.0;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CustomPaint(
        painter: _DashPainter(bt.borderStrong, radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: expand ? 52 : 44,
                minWidth: expand ? double.infinity : 0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: bt.skyInk),
                    const SizedBox(width: Gap.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge!.copyWith(
                          fontSize: 14,
                          color: bt.skyInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(radius.clamp(0, size.height / 2)),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.radius != radius;
}

/// A selectable card with a radio mark (two or three big choices).
class ChoiceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Widget? footer;
  final Tone tone;

  const ChoiceCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.footer,
    this.tone = Tone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final hue = tone.hue(context);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.settle,
        decoration: BoxDecoration(
          color: selected ? tone.tint(context) : bt.surface,
          borderRadius: Radii.card,
          border: Border.all(
            color: selected ? hue : bt.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: Radii.card,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        icon: icon,
                        color: selected ? tone.color(context) : bt.muted,
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.titleMedium),
                            const SizedBox(height: 2),
                            Text(body, style: text.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      AnimatedSwitcher(
                        duration: Motion.of(context, Motion.fast),
                        child: Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(selected),
                          color: selected ? tone.color(context) : bt.faint,
                        ),
                      ),
                    ],
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: Gap.sm),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that opens a detail page: icon tile, title, live state, chevron.
class NavCard extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String detail;
  final Tone? detailTone;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? titleWidget;

  const NavCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.detail,
    this.detailTone,
    this.onTap,
    this.trailing,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$title, $detail',
      excludeSemantics: titleWidget == null,
      child: InfoCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(Gap.lg, 14, Gap.md, 14),
        child: Row(
          children: [
            IconBadge(icon: icon, color: tone.color(context), size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget ??
                      Text(
                        title,
                        style: text.titleMedium!.copyWith(fontSize: 17),
                      ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14,
                      height: 1.35,
                      color: detailTone?.color(context) ?? bt.muted,
                      fontWeight: detailTone == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: bt.muted, size: 24),
          ],
        ),
      ),
    );
  }
}

/// The page frame for a Better TV detail: back, a Bricolage title and a
/// line under it, then the content.
class DetailPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? titleTrailing;
  final Future<void> Function()? onRefresh;

  const DetailPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.titleTrailing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        Gap.page,
        0,
        Gap.page,
        Gap.xxl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: text.headlineLarge),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: text.bodyMedium),
                  ],
                ],
              ),
            ),
            if (titleTrailing != null) titleTrailing!,
          ],
        ),
        const SizedBox(height: Gap.lg),
        ...children,
      ],
    );
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}
