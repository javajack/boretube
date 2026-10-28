import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'tubby.dart';

/// Semantic tone for rows, badges and tiles. Colour never carries meaning
/// alone: every use pairs it with an icon and a word.
enum Tone { ok, warn, bad, info, idle, accent }

extension ToneColor on Tone {
  /// Text-safe colour on a card.
  Color color(BuildContext context) {
    final s = StatusColors.of(context);
    return switch (this) {
      Tone.ok => s.ok,
      Tone.warn => s.warn,
      Tone.bad => s.bad,
      Tone.info => s.info,
      Tone.idle => s.idle,
      Tone.accent => context.bt.coralInk,
    };
  }

  /// The bright brand hue (icons, dots, borders).
  Color hue(BuildContext context) {
    final bt = context.bt;
    return switch (this) {
      Tone.ok => bt.mint,
      Tone.warn => bt.sun,
      Tone.bad => bt.berry,
      Tone.info => bt.sky,
      Tone.idle => bt.faint,
      Tone.accent => bt.coral,
    };
  }

  /// Pale wash behind badges and tiles.
  Color tint(BuildContext context) {
    final bt = context.bt;
    return switch (this) {
      Tone.ok => bt.mintTint,
      Tone.warn => bt.sunTint,
      Tone.bad => bt.berryTint,
      Tone.info => bt.skyTint,
      Tone.idle => bt.wash,
      Tone.accent => bt.coralTint,
    };
  }
}

/// A group name: sentence case, Bricolage 21/700, with a section gap
/// above it. Use only where a group genuinely needs a name; never an
/// uppercase "eyebrow".
class GroupHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;

  /// The first heading on a screen sits closer to what is above it.
  final bool first;

  const GroupHeading(
    this.title, {
    super.key,
    this.trailing,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? Gap.related : Gap.section,
        bottom: Gap.f8,
      ),
      child: Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// The one raised container: white on cream, a 1 px warm border, no
/// shadow. At most two per screen (test/widget/structure_test.dart): the
/// hero, and one more if it earns it. Lists go on the canvas instead.
class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final BorderRadius radius;

  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.related),
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
    this.radius = Radii.control,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? color ?? bt.surface : null,
          gradient: gradient,
          borderRadius: radius,
          border: Border.all(
            color: borderColor ?? bt.border,
            width: Sizes.hairline,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A small tinted icon tile. Only for top-level navigation entries (Better
/// TV's destinations) and the hero; rows use a plain 20 px icon.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  /// Solid fill with a white glyph.
  final bool solid;

  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = Sizes.tile,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.13),
        borderRadius: size >= Sizes.row ? Radii.control : Radii.chip,
      ),
      child: Icon(
        icon,
        color: solid ? Colors.white : color,
        size: size * Phi.major,
      ),
    );
  }
}

/// Press feedback: 120 ms, scale 0.97 (none with reduced motion).
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const Pressable({super.key, required this.child, this.enabled = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _down = true) : null,
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down && !still ? Motion.pressScale : 1,
        duration: Motion.press,
        curve: _down ? Motion.enter : Motion.exit,
        child: widget.child,
      ),
    );
  }
}

enum ButtonKind { coral, ink, berry, mint, outline, sun }

/// The app's button. [ButtonKind.coral] is the single primary on a screen
/// (58 tall, the only element with a soft coral shadow); every other kind
/// is a 44 secondary unless told otherwise.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final double? height;

  /// Bricolage label (the Pause TV button).
  final bool display;
  final bool shadow;
  final String? semanticLabel;

  /// A trailing note, e.g. "about 1 minute".
  final String? note;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = ButtonKind.coral,
    this.height,
    this.display = false,
    this.shadow = false,
    this.semanticLabel,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final enabled = onPressed != null;
    final h =
        height ?? (kind == ButtonKind.coral ? Sizes.primary : Sizes.control);
    final big = h >= Sizes.row;
    final (bg, fg, pressed) = switch (kind) {
      ButtonKind.coral => (bt.coralFill, Colors.white, bt.coralPressed),
      ButtonKind.ink => (bt.inkFill, bt.onInkFill, bt.inkSoft),
      ButtonKind.berry => (bt.berryFill, Colors.white, bt.berryInk),
      ButtonKind.mint => (bt.mint, const Color(0xFF06392A), bt.mintInk),
      ButtonKind.sun => (bt.sun, const Color(0xFF3D2700), bt.sunInk),
      ButtonKind.outline => (Colors.transparent, bt.ink, bt.wash),
    };
    final style = display
        ? Fonts.bricolage(
            TypeSize.headline,
            color: fg,
            height: TypeSize.tightLeading,
          )
        : text.labelLarge!.copyWith(color: fg);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: fg,
            size: big ? Sizes.iconControl : Sizes.icon,
          ),
          SizedBox(width: big ? Gap.f13 : Gap.f8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (note != null)
          Flexible(
            child: Text(
              ' · $note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                fontWeight: FontWeight.w600,
                color: fg.withValues(alpha: 0.85),
              ),
            ),
          ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Pressable(
        enabled: enabled,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: Motion.of(context, Motion.flip),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Radii.control,
              boxShadow: shadow && enabled
                  ? [
                      BoxShadow(
                        color: bt.coral.withValues(alpha: 0.2),
                        blurRadius: Gap.f34,
                        spreadRadius: -Gap.f13,
                        offset: const Offset(0, Gap.f13),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: bg,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.control,
                side: kind == ButtonKind.outline
                    ? BorderSide(color: bt.borderStrong)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onPressed!();
                      },
                highlightColor: pressed.withValues(alpha: 0.35),
                splashColor: Colors.white.withValues(alpha: 0.12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.related,
                      vertical: Gap.f4,
                    ),
                    child: Center(heightFactor: 1, child: content),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact chip: 34 tall, radius 8, a 1 px line. Selection is a tint
/// with ink text, never a thick border. Put several in a [ChipRow] so
/// siblings are equal width.
class BtChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final IconData? icon;
  final Tone tone;

  const BtChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.semanticLabel,
    this.icon,
    this.tone = Tone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final fg = selected ? bt.ink : bt.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Pressable(
        enabled: onTap != null,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.flip),
          curve: Motion.enter,
          constraints: const BoxConstraints(minHeight: Sizes.chip),
          decoration: BoxDecoration(
            color: selected ? tone.tint(context) : Colors.transparent,
            borderRadius: Radii.chip,
            border: Border.all(
              color: selected
                  ? tone.hue(context).withValues(alpha: 0.6)
                  : bt.borderStrong,
              width: Sizes.hairline,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: Radii.chip,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onTap!();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.f8),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: Sizes.iconSmall, color: fg),
                        if (label.isNotEmpty) const SizedBox(width: Gap.f4),
                      ],
                      if (label.isNotEmpty)
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium!.copyWith(
                              color: fg,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
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
      ),
    );
  }
}

/// Equal-width siblings with an 8 gap: chips, quick actions. With
/// [equal] false the children keep their own width and wrap.
class ChipRow extends StatelessWidget {
  final List<Widget> children;
  final bool equal;

  const ChipRow({super.key, required this.children, this.equal = true});

  @override
  Widget build(BuildContext context) {
    if (!equal) {
      return Wrap(
        spacing: Gap.f8,
        runSpacing: Gap.f8,
        children: children,
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: Gap.f8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// One quick-action cell: a 24 icon over a 13 label, 55 tall, no card.
/// [active] tints it (e.g. "Unmute" while muted).
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? state;
  final bool active;

  /// Shows a small ring, but only once the action has run for 1.5 s:
  /// normal actions just flip.
  final bool busy;

  /// Flashes a small check after success.
  final bool done;
  final VoidCallback? onTap;
  final Tone tone;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.state,
    this.active = false,
    this.busy = false,
    this.done = false,
    this.onTap,
    this.tone = Tone.info,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null && !busy;
    final fg = active ? tone.color(context) : bt.ink;
    final dim = !enabled && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: state == null ? label : '$label, $state',
      excludeSemantics: true,
      child: Pressable(
        enabled: enabled,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.flip),
          curve: Motion.enter,
          constraints: const BoxConstraints(minHeight: Sizes.row),
          decoration: BoxDecoration(
            color: active ? tone.tint(context) : Colors.transparent,
            borderRadius: Radii.control,
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: Radii.control,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      onTap!();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.f4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: Sizes.iconControl,
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.flip),
                        child: busy
                            ? DelayedSpinner(
                                key: const ValueKey('busy'),
                                color: fg,
                                size: Sizes.icon,
                                fallback: Icon(
                                  icon,
                                  size: Sizes.iconControl,
                                  color: fg,
                                ),
                              )
                            : Icon(
                                done ? Icons.check_rounded : icon,
                                key: ValueKey(done ? 'done' : icon),
                                size: Sizes.iconControl,
                                color: dim
                                    ? bt.faint
                                    : done
                                        ? StatusColors.of(context).ok
                                        : fg,
                              ),
                      ),
                    ),
                    const SizedBox(height: Gap.f4),
                    Text(
                      state ?? label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: text.labelMedium!.copyWith(
                        color: dim ? bt.muted : fg,
                        fontWeight: FontWeight.w700,
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

/// The plain list row: on the canvas, 55 tall, a 20 px inline icon, a
/// title with at most one line under it, and a right-aligned value or
/// control. Rows in a [RowList] share one trailing edge.
class ListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final Color? subtitleColor;

  /// Right-aligned value text ("9:00 pm", "On").
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Shows a chevron after the value; defaults to true when tappable.
  final bool? chevron;
  final bool dim;
  final int subtitleLines;

  const ListRow({
    super.key,
    this.icon,
    this.leading,
    this.iconColor,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleColor,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.chevron,
    this.dim = false,
    this.subtitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final showChevron = chevron ?? onTap != null;
    final lead = leading ??
        (icon == null
            ? null
            : Icon(
                icon,
                size: Sizes.icon,
                color: dim ? bt.faint : iconColor ?? bt.inkSoft,
              ));
    final valueMax =
        (MediaQuery.sizeOf(context).width - Gap.gutter * 2) * Phi.minor;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.f8),
          child: Row(
            children: [
              if (lead != null) ...[
                // Icons sit in a 24 column so titles align down a list;
                // a larger leading (an icon tile) keeps its own width.
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: Sizes.iconControl,
                  ),
                  child: Center(widthFactor: 1, child: lead),
                ),
                const SizedBox(width: Gap.f13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget ??
                        Text(
                          title,
                          style: text.titleSmall!.copyWith(
                            color: dim ? bt.muted : null,
                          ),
                        ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: subtitleLines,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(color: subtitleColor),
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: Gap.f13),
                // The value keeps its own width, up to the 38.2 % side of
                // the row, so values share one right edge down a list.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: valueMax),
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.flip),
                    child: Text(
                      value!,
                      key: ValueKey(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: text.bodyMedium!.copyWith(
                        color: valueColor ?? (dim ? bt.faint : bt.muted),
                        fontWeight: FontWeight.w600,
                        fontFeatures: Fonts.tabular,
                      ),
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: Gap.f13),
                trailing!,
              ],
              if (showChevron) ...[
                const SizedBox(width: Gap.f4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: Sizes.icon,
                  color: bt.faint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row whose icon carries a tone (ok / warn / bad), for checklists and
/// status lists. Plain, on the canvas, like every row.
class StatusRow extends StatelessWidget {
  final Tone tone;
  final IconData icon;
  final String title;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int detailLines;

  const StatusRow({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.detail,
    this.trailing,
    this.onTap,
    this.detailLines = 1,
  });

  @override
  Widget build(BuildContext context) => ListRow(
        icon: icon,
        iconColor: tone.color(context),
        title: title,
        subtitle: detail,
        subtitleLines: detailLines,
        trailing: trailing,
        onTap: onTap,
        chevron: onTap != null && trailing == null,
      );
}

/// Rows separated by 1 px warm hairlines, straight on the canvas (no
/// card). [edges] adds a hairline above the first and below the last.
class RowList extends StatelessWidget {
  final List<Widget> children;
  final bool edges;

  /// Indent the dividers past a leading icon column.
  final bool indent;

  const RowList({
    super.key,
    required this.children,
    this.edges = false,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    final line = Divider(
      height: Sizes.hairline,
      thickness: Sizes.hairline,
      indent: indent ? Sizes.iconControl + Gap.f13 : 0,
      color: context.bt.hairline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (edges) line,
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) line,
          children[i],
        ],
        if (edges) line,
      ],
    );
  }
}

/// A single thin progress bar ("4 of 6").
class ThinProgress extends StatelessWidget {
  final double value;
  final Color? color;

  const ThinProgress({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return ClipRRect(
      borderRadius: Radii.chip,
      child: SizedBox(
        height: Sizes.bar,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          builder: (context, v, _) => Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: bt.wash)),
              FractionallySizedBox(
                widthFactor: v,
                child: ColoredBox(
                  color: color ?? bt.mint,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades a list item in, 34 ms after the one before it (first five only).
/// No movement with reduced motion; nothing on scroll.
class StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggerIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (index >= Motion.staggerMax || Motion.reduced(context)) return child;
    final lead = Motion.stagger * index;
    final total = Motion.sheet + lead;
    final start = lead.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, child) {
        final v = Motion.enter.transform(
          ((t - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, Gap.f8 * (1 - v)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A small ⓘ that opens a sheet with the longer explanation, so helper
/// copy under a control stays to one line.
class InfoButton extends StatelessWidget {
  final String title;
  final String body;
  final Color? color;

  const InfoButton({
    super.key,
    required this.title,
    required this.body,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'About $title',
      excludeSemantics: true,
      child: InkResponse(
        radius: Sizes.touch / 2,
        onTap: () {
          HapticFeedback.selectionClick();
          showInfoSheet(context, title: title, body: body);
        },
        child: SizedBox(
          width: Sizes.control,
          height: Sizes.control,
          child: Icon(
            Icons.info_outline_rounded,
            size: Sizes.icon,
            color: color ?? context.bt.muted,
          ),
        ),
      ),
    );
  }
}

Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String body,
}) =>
    showBtSheet<void>(
      context,
      builder: (context) => SheetScaffold(
        title: title,
        lead: Text(body),
        children: [
          PrimaryButton(
            label: 'Got it',
            kind: ButtonKind.ink,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

/// A ✓ (works) or ○ (not yet) line, for "Still working" style lists.
class CheckLine extends StatelessWidget {
  final String label;
  final bool done;
  final double minHeight;

  const CheckLine(
    this.label, {
    super.key,
    required this.done,
    this.minHeight = Sizes.chip,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '${done ? 'Works' : 'Not yet'}: $label',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.f4),
          child: Row(
            children: [
              SizedBox(
                width: Sizes.iconControl,
                child: Icon(
                  done ? Icons.check_rounded : Icons.radio_button_unchecked,
                  size: Sizes.icon,
                  color: done ? bt.mint : bt.faint,
                  weight: 700,
                ),
              ),
              const SizedBox(width: Gap.f13),
              Expanded(
                child: Text(
                  label,
                  style: text.bodyMedium!.copyWith(
                    color: done ? bt.ink : bt.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly empty or error state. With [tubby], Tubby stands in for the
/// icon (empty states teach; Tubby makes them warm).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Tone tone;
  final TubbyMood? tubby;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = Tone.idle,
    this.tubby,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.f13,
        vertical: Gap.section,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tubby != null)
            Tubby(mood: tubby!, size: Sizes.tubbyLarge)
          else
            IconTile(
              icon: icon,
              color: tone.color(context),
              size: Sizes.row,
            ),
          const SizedBox(height: Gap.related),
          Text(title, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Gap.f4),
          Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Gap.related),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: Sizes.icon),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small tinted badge with an optional icon: mode badges, states.
/// Tappable badges are a 34 chip; static ones are a compact tag.
class BtBadge extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool large;

  const BtBadge(
    this.label, {
    super.key,
    this.tone = Tone.idle,
    this.icon,
    this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = tone.color(context);
    final chip = large || onTap != null;
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
        );
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.f8,
        vertical: Gap.f4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: Sizes.iconSmall, color: c),
            const SizedBox(width: Gap.f4),
          ],
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return Material(
      color: tone.tint(context),
      borderRadius: Radii.chip,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: chip ? Sizes.chip : 0),
          child: Center(widthFactor: 1, heightFactor: 1, child: body),
        ),
      ),
    );
  }
}

enum BannerKind { problem, info, digest, success, paused }

/// A slim inline banner: a tint, a 20 px icon, one bold line and at most
/// one line under it. Problems are Berry with `role=alert` semantics and
/// one 44 fix button; other kinds take a quiet text action.
class NoticeBanner extends StatelessWidget {
  final BannerKind kind;
  final String title;
  final String? message;
  final IconData? icon;

  /// Replaces the icon (e.g. a small Tubby on the digest).
  final Widget? leading;
  final String? actionLabel;
  final String? actionNote;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const NoticeBanner({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.icon,
    this.leading,
    this.actionLabel,
    this.actionNote,
    this.onAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final (bg, titleC, bodyC, hue, btn) = switch (kind) {
      BannerKind.problem => (
          bt.berryTint,
          bt.berryInk,
          bt.berryInk,
          bt.berry,
          ButtonKind.berry,
        ),
      BannerKind.info => (
          bt.skyTint,
          bt.skyInk,
          bt.inkSoft,
          bt.skyInk,
          ButtonKind.ink,
        ),
      BannerKind.digest => (
          bt.lavenderTint,
          bt.ink,
          bt.inkSoft,
          bt.lavenderInk,
          ButtonKind.ink,
        ),
      BannerKind.success => (
          bt.mintTint,
          bt.mintInk,
          bt.inkSoft,
          bt.mintInk,
          ButtonKind.mint,
        ),
      BannerKind.paused => (
          bt.sunTint,
          bt.sunInk,
          bt.inkSoft,
          bt.sunInk,
          ButtonKind.ink,
        ),
    };
    final problem = kind == BannerKind.problem;
    final inlineAction = actionLabel != null && !problem;
    final banner = Material(
      color: bg,
      borderRadius: Radii.control,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.f13,
            Gap.f13,
            Gap.f8,
            Gap.f13,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: Sizes.iconControl,
                    child: Center(
                      child: leading ??
                          Icon(
                            icon ?? Icons.info_rounded,
                            size: Sizes.icon,
                            color: hue,
                          ),
                    ),
                  ),
                  const SizedBox(width: Gap.f13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.titleSmall!.copyWith(
                            color: titleC,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (message != null)
                          Text(
                            message!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(color: bodyC),
                          ),
                      ],
                    ),
                  ),
                  if (inlineAction)
                    TextButton(
                      key: key == null ? null : ValueKey('$key-action'),
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: titleC,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.f13,
                        ),
                      ),
                      child: Text(actionLabel!),
                    )
                  else if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: Sizes.icon,
                      color: bodyC,
                    ),
                ],
              ),
              if (actionLabel != null && problem) ...[
                const SizedBox(height: Gap.f13),
                Padding(
                  padding: const EdgeInsets.only(right: Gap.f4),
                  child: PrimaryButton(
                    key: key == null ? null : ValueKey('$key-action'),
                    label: actionLabel!,
                    note: actionNote,
                    kind: btn,
                    onPressed: onAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!problem) return banner;
    return Semantics(liveRegion: true, container: true, child: banner);
  }
}

/// Small rounded label, e.g. "Protected" or "Off".
class TagChip extends StatelessWidget {
  final String label;
  final Tone tone;

  const TagChip(this.label, {super.key, this.tone = Tone.idle});

  @override
  Widget build(BuildContext context) => BtBadge(label, tone: tone);
}

/// Animated volume bar.
class VolumeMeter extends StatelessWidget {
  final int? percent;
  final bool muted;
  final double height;

  const VolumeMeter({
    super.key,
    required this.percent,
    this.muted = false,
    this.height = Sizes.bar,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final value = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    final color = muted ? bt.faint : bt.sky;
    return ClipRRect(
      borderRadius: Radii.chip,
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: Motion.of(context, Motion.sheet),
          curve: Motion.enter,
          builder: (context, v, _) => Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: bt.skyTint)),
              FractionallySizedBox(
                widthFactor: v,
                child: ColoredBox(color: color, child: const SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A number that tweens to its new value over 320 ms, tabular figures.
class TweenNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String Function(int v) format;

  const TweenNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: Motion.of(context, Motion.sheet),
      curve: Motion.enter,
      builder: (context, v, _) => Text(
        format(v.round()),
        style: (style ?? const TextStyle()).copyWith(
          fontFeatures: Fonts.tabular,
        ),
      ),
    );
  }
}

/// Simple shimmer placeholder (no extra packages).
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius radius;

  const Skeleton({
    super.key,
    this.height = Gap.f13,
    this.width,
    this.radius = Radii.chip,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow * 3,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final base = bt.wash;
    final glow = bt.border;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 3 - 1;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, glow, base],
            ),
          ),
        );
      },
    );
  }
}

/// A few skeleton rows on the canvas while a list loads.
class SkeletonCard extends StatelessWidget {
  final int rows;

  const SkeletonCard({super.key, this.rows = 3});

  @override
  Widget build(BuildContext context) {
    return RowList(
      children: [
        for (var i = 0; i < rows; i++)
          SizedBox(
            height: Sizes.row,
            child: Row(
              children: [
                const Skeleton(
                  height: Sizes.icon,
                  width: Sizes.iconControl,
                ),
                const SizedBox(width: Gap.f13),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: Phi.major - (i % 2) * Phi.minor / 2,
                      child: const Skeleton(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A soft halo that breathes around [child] (or an icon); for "look at
/// the TV" moments and the remote key to press.
class PulsingIcon extends StatefulWidget {
  final IconData? icon;
  final double size;
  final Color? color;
  final Widget? child;

  const PulsingIcon({
    super.key,
    this.icon,
    this.size = Sizes.tubbyLarge,
    this.color,
    this.child,
  });

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow * 3,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.bt.coral;
    final box = widget.size * Phi.ratio;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final phase in const [0.0, 0.5])
                Builder(
                  builder: (context) {
                    final p = (t + phase) % 1.0;
                    return Container(
                      width: widget.size * (1 + Phi.major * p),
                      height: widget.size * (1 + Phi.major * p),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.20 * (1 - p)),
                      ),
                    );
                  },
                ),
              Transform.scale(
                scale: 1 + 0.03 * math.sin(_c.value * 2 * math.pi),
                child: child,
              ),
            ],
          );
        },
        child: widget.child ??
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(widget.icon, size: widget.size / 2, color: color),
            ),
      ),
    );
  }
}

/// Segments showing progress through onboarding.
class StepIndicator extends StatelessWidget {
  final int count;
  final int index;

  const StepIndicator({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.of(context, Motion.flip),
              curve: Motion.enter,
              margin: const EdgeInsets.symmetric(horizontal: Gap.f4 / 2),
              width: Gap.f21,
              height: Sizes.bar,
              decoration: BoxDecoration(
                color: i <= index ? bt.coral : bt.border,
                borderRadius: Radii.chip,
              ),
            ),
        ],
      ),
    );
  }
}

/// A bottom sheet in the house style: handle, Bricolage title, cream;
/// slides in over 320 ms (easeOutCubic), out with easeInCubic.
Future<T?> showBtSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: Motion.reduced(context)
          ? const AnimationStyle(
              duration: Motion.press,
              reverseDuration: Motion.press,
            )
          : const AnimationStyle(
              duration: Motion.sheet,
              reverseDuration: Motion.flip,
              curve: Motion.enter,
              reverseCurve: Motion.exit,
            ),
      builder: builder,
    );

/// The body of a sheet: title, optional lead text, then [children].
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget? lead;
  final List<Widget> children;

  const SheetScaffold({
    super.key,
    required this.title,
    this.lead,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Gap.gutter,
          0,
          Gap.gutter,
          Gap.related,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: text.headlineMedium),
            ),
            if (lead != null) ...[
              const SizedBox(height: Gap.f8),
              DefaultTextStyle.merge(style: text.bodyMedium, child: lead!),
            ],
            const SizedBox(height: Gap.related),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Asks before anything that changes the TV. Returns true on confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continue',
  bool destructive = false,
  IconData icon = Icons.build_circle_outlined,
}) async {
  final bt = context.bt;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        icon,
        size: Sizes.iconControl,
        color: destructive ? bt.berryFill : bt.skyInk,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        Gap.related,
        0,
        Gap.related,
        Gap.related,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: bt.berryFill,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Floating snackbar with a leading status icon.
void showStatusSnack(
  BuildContext context,
  String message, {
  bool ok = true,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final bt = context.bt;
  if (!ok) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? bt.mint : bt.berry,
              size: Sizes.icon,
            ),
            const SizedBox(width: Gap.f13),
            Expanded(
              child: Text(message, style: TextStyle(color: bt.onInkFill)),
            ),
          ],
        ),
      ),
    );
}

/// A small progress ring that only appears once an action has taken longer
/// than [delay] (a sign of trouble), so normal actions just flip. Until
/// then it shows [fallback].
class DelayedSpinner extends StatefulWidget {
  // tokens:off: a behaviour threshold (spinner only after 1.5 s).
  static const delay = Duration(milliseconds: 1500);
  // tokens:on

  final Color color;
  final double size;
  final Widget? fallback;

  const DelayedSpinner({
    super.key,
    required this.color,
    this.size = Gap.f13,
    this.fallback,
  });

  @override
  State<DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<DelayedSpinner> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DelayedSpinner.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show && widget.fallback != null) return widget.fallback!;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _show
          ? CircularProgressIndicator(
              strokeWidth: Sizes.focus,
              color: widget.color,
            )
          : null,
    );
  }
}
