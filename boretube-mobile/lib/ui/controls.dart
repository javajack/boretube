import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'tokens.dart';

/// 2–4 short, mutually exclusive choices as an equal-width [ChipRow].
/// Longer or more choices belong in a [RadioList]; never a 2×2 grid.
class SegmentChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final String? keyPrefix;

  const SegmentChoice({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return ChipRow(
      children: [
        for (final (v, label) in options)
          BtChip(
            key: keyPrefix == null
                ? null
                : Key('$keyPrefix-${v is Enum ? v.name : v}'),
            label: label,
            selected: v == value,
            onTap: onChanged == null || v == value ? null : () => onChanged!(v),
          ),
      ],
    );
  }
}

/// One option of a [RadioList].
class RadioOption<T> {
  final T value;
  final String label;

  /// One line at most.
  final String? detail;
  final IconData? icon;

  const RadioOption(this.value, this.label, {this.detail, this.icon});
}

/// A multi-choice as a list: one line per option, a radio mark on the
/// right, hairlines between. Keys are `$keyPrefix-<value name>`.
class RadioList<T> extends StatelessWidget {
  final List<RadioOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final String? keyPrefix;

  const RadioList({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.keyPrefix,
  });

  static String _id(Object? v) => v is Enum ? v.name : '$v';

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return RowList(
      children: [
        for (final o in options)
          Semantics(
            selected: o.value == value,
            inMutuallyExclusiveGroup: true,
            child: ListRow(
              key: keyPrefix == null ? null : Key('$keyPrefix-${_id(o.value)}'),
              icon: o.icon,
              iconColor: o.value == value ? bt.ink : bt.muted,
              title: o.label,
              subtitle: o.detail,
              chevron: false,
              onTap: onChanged == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onChanged!(o.value);
                    },
              trailing: AnimatedSwitcher(
                duration: Motion.of(context, Motion.flip),
                child: Icon(
                  o.value == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(o.value == value),
                  size: Sizes.iconControl,
                  color: o.value == value ? bt.coralInk : bt.faint,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// − N + at text size, inline at the end of a row ("5 per day").
class CountStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int>? onChanged;
  final String? keyPrefix;

  const CountStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.step = 1,
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
        child: InkResponse(
          key: keyPrefix == null ? null : Key('$keyPrefix-$id'),
          radius: Sizes.touch / 2,
          onTap: on
              ? () {
                  HapticFeedback.selectionClick();
                  onChanged!(to);
                }
              : null,
          child: SizedBox(
            width: Sizes.control,
            height: Sizes.control,
            child: Icon(
              icon,
              size: Sizes.icon,
              color: on ? bt.ink : bt.faint,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      value: '$value $unit',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Fewer', value - step, 'minus'),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: Gap.f34),
            child: Text(
              unit.isEmpty ? '$value' : '$value $unit',
              textAlign: TextAlign.center,
              style: text.titleSmall!.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: Fonts.tabular,
              ),
            ),
          ),
          button(Icons.add_rounded, 'More', value + step, 'plus'),
        ],
      ),
    );
  }
}

/// A row with a title, a value on the right, and whatever controls go
/// underneath. No card: it sits on the canvas.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.f13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.control),
            child: Row(
              children: [
                SizedBox(
                  width: Sizes.iconControl,
                  child: Icon(
                    icon,
                    size: Sizes.icon,
                    color: dim ? bt.faint : tone.color(context),
                  ),
                ),
                const SizedBox(width: Gap.f13),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: text.titleMedium!.copyWith(
                      color: dim ? bt.muted : null,
                    ),
                    child: title,
                  ),
                ),
                if (value != null)
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.flip),
                    child: Text(
                      value!,
                      key: ValueKey(value),
                      style: text.bodyMedium!.copyWith(
                        color: dim ? bt.faint : bt.muted,
                        fontWeight: FontWeight.w600,
                        fontFeatures: Fonts.tabular,
                      ),
                    ),
                  ),
                if (trailing != null) ...[
                  const SizedBox(width: Gap.f8),
                  trailing!,
                ],
              ],
            ),
          ),
          if (children.isNotEmpty) const SizedBox(height: Gap.f13),
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
    return MergeSemantics(
      child: ListRow(
        title: title,
        subtitle: subtitle,
        leading: leading,
        chevron: false,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// "+ Add" with a 1 px dashed outline: something you can add more of.
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
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CustomPaint(
        painter: _DashPainter(bt.borderStrong, Radii.chipR),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: Radii.chip,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: expand ? Sizes.control : Sizes.chip,
                minWidth: expand ? double.infinity : 0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.f13),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: Sizes.iconSmall,
                      color: bt.skyInk,
                    ),
                    const SizedBox(width: Gap.f4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium!.copyWith(
                          color: bt.skyInk,
                          fontWeight: FontWeight.w700,
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
      (Offset.zero & size).deflate(Sizes.hairline / 2),
      Radius.circular(radius.clamp(0, size.height / 2)),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = Sizes.hairline;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + Gap.f4), paint);
        d += Gap.f8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.radius != radius;
}

/// One choice of a few, as a radio row (icon, title, one line, radio).
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
    return Semantics(
      selected: selected,
      button: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListRow(
            icon: icon,
            iconColor: selected ? tone.color(context) : bt.muted,
            title: title,
            subtitle: body,
            chevron: false,
            onTap: onTap,
            trailing: AnimatedSwitcher(
              duration: Motion.of(context, Motion.flip),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(selected),
                size: Sizes.iconControl,
                color: selected ? tone.color(context) : bt.faint,
              ),
            ),
          ),
          if (footer != null) ...[
            footer!,
            const SizedBox(height: Gap.f13),
          ],
        ],
      ),
    );
  }
}

/// A top-level destination row: a small icon tile, title, live state and
/// a chevron, on the canvas.
class NavRow extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String detail;
  final Tone? detailTone;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? titleWidget;

  const NavRow({
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
    return Semantics(
      button: onTap != null,
      label: '$title, $detail',
      excludeSemantics: titleWidget == null,
      child: ListRow(
        leading: IconTile(icon: icon, color: tone.color(context)),
        title: title,
        titleWidget: titleWidget,
        subtitle: detail,
        subtitleColor: detailTone?.color(context) ?? bt.muted,
        onTap: onTap,
        trailing: trailing,
        chevron: trailing == null,
      ),
    );
  }
}

/// The page frame for a detail page: back, a Bricolage title and one line
/// under it, then the content.
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
        Gap.gutter,
        0,
        Gap.gutter,
        Gap.section,
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
                    child: Text(title, style: text.displaySmall),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Gap.f4),
                    Text(subtitle!, style: text.bodyMedium),
                  ],
                ],
              ),
            ),
            if (titleTrailing != null) titleTrailing!,
          ],
        ),
        const SizedBox(height: Gap.related),
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
