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
      Tone.idle => bt.hairline,
      Tone.accent => bt.coralTint,
    };
  }
}

/// Small uppercase label above a group of cards, with an optional action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      Gap.xs,
      Gap.xl,
      Gap.xs,
      Gap.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// The card: white on cream, a warm hairline border, no shadow.
class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final BorderRadius radius;

  const InfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
    this.radius = Radii.card,
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
          border: Border.all(color: borderColor ?? bt.border),
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

/// A tinted square icon tile (radius 10).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  /// Solid fill with a white glyph (problem banners).
  final bool solid;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = size >= 56 ? Radii.tileR : Radii.iconTile;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(r),
      ),
      child: Icon(
        icon,
        color: solid ? Colors.white : color,
        size: size * 0.55,
      ),
    );
  }
}

/// Press feedback for custom buttons: a small spring scale.
class _Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _Pressable({required this.child, required this.enabled});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _down = true) : null,
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.of(context, const Duration(milliseconds: 140)),
        curve: _down ? Curves.easeOut : Motion.spring,
        child: widget.child,
      ),
    );
  }
}

enum ButtonKind { coral, ink, berry, mint, outline, sun }

/// The app's custom button. [ButtonKind.coral] is the single hero action
/// on a screen and the only element with a (soft, coral) shadow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final double height;

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
    this.height = 56,
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
    final (bg, fg, pressed) = switch (kind) {
      ButtonKind.coral => (bt.coralFill, Colors.white, bt.coralPressed),
      ButtonKind.ink => (bt.inkFill, bt.onInkFill, bt.inkSoft),
      ButtonKind.berry => (bt.berryFill, Colors.white, bt.berryInk),
      ButtonKind.mint => (bt.mint, const Color(0xFF06392A), bt.mintInk),
      ButtonKind.sun => (bt.sun, const Color(0xFF3D2700), bt.sunInk),
      ButtonKind.outline => (bt.surface, bt.ink, bt.hairline),
    };
    final style = display
        ? Fonts.bricolage(24, color: fg, height: 1)
        : text.labelLarge!.copyWith(
            color: fg,
            fontSize: height >= 56 ? 17 : 16,
          );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: fg, size: display ? 30 : 22),
          SizedBox(width: display ? Gap.md : Gap.sm),
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
      child: _Pressable(
        enabled: enabled,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: Motion.of(context, Motion.fast),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Radii.buttons,
              boxShadow: shadow && enabled
                  ? [
                      // Two soft layers: a wide, low glow pulled in at the
                      // sides (negative spread, so no hard edge shows past
                      // the corners) and a faint contact shadow.
                      BoxShadow(
                        color: bt.coral.withValues(alpha: 0.24),
                        blurRadius: 28,
                        spreadRadius: -6,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: bt.coral.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: bg,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.buttons,
                side: kind == ButtonKind.outline
                    ? BorderSide(color: bt.borderStrong, width: 2)
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
                  constraints: BoxConstraints(minHeight: height),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg,
                      vertical: Gap.sm,
                    ),
                    child: Center(child: content),
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

/// A small selectable pill (duration chips, day chips, goal filters).
class PillChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final IconData? icon;

  /// Corner radius; null is a full pill (small chips). Bigger choices,
  /// like the Pause TV durations, use [Radii.input].
  final double? radius;

  const PillChoice({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.semanticLabel,
    this.icon,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final side = BorderSide(
      color: selected ? bt.coral : bt.coralTint,
      width: 2,
    );
    final r = radius;
    final OutlinedBorder shape = r == null
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r),
            side: side,
          );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.settle,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: ShapeDecoration(
          color: selected ? bt.coralWash : bt.surface,
          shape: shape,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape.copyWith(side: BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 16,
                        color: selected ? bt.coralInk : bt.ink,
                      ),
                      const SizedBox(width: Gap.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge!.copyWith(
                          fontSize: 14,
                          color: selected ? bt.coralInk : bt.ink,
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

/// Quick-action tile: icon over label, with an optional state line.
/// [active] tints it in its tone (e.g. "Unmute" while muted).
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? state;
  final bool active;

  /// Shows a small ring in the corner, but only once the action has run
  /// for 1.5 s: normal actions just flip.
  final bool busy;

  /// Flashes a small check in the corner after success.
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
    final hue = tone.hue(context);
    final enabled = onTap != null && !busy;
    final bg = active ? tone.tint(context) : bt.surface;
    final fg = active ? tone.color(context) : bt.ink;
    final iconColor = active ? tone.color(context) : bt.sky;
    final dim = !enabled && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: state == null ? label : '$label, $state',
      excludeSemantics: true,
      child: _Pressable(
        enabled: enabled,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          curve: Motion.settle,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Radii.tile,
            border: Border.all(
              color: active ? hue.withValues(alpha: 0.7) : bt.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: Radii.tile,
              onTap: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      onTap!();
                    }
                  : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.xs,
                        vertical: Gap.sm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: Motion.of(context, Motion.fast),
                            child: Icon(
                              icon,
                              key: ValueKey(icon),
                              size: 26,
                              color: dim ? bt.faint : iconColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.labelLarge!.copyWith(
                              fontSize: 14,
                              color: dim ? bt.muted : fg,
                            ),
                          ),
                          if (state != null)
                            AnimatedSwitcher(
                              duration: Motion.of(context, Motion.fast),
                              child: Text(
                                state!,
                                key: ValueKey(state),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: text.bodySmall!.copyWith(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: Gap.sm,
                    right: Gap.sm,
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.fast),
                      child: busy
                          ? DelayedSpinner(
                              key: const ValueKey('busy'),
                              color: fg,
                            )
                          : done
                              ? Icon(
                                  Icons.check_rounded,
                                  key: const ValueKey('done'),
                                  size: 16,
                                  color: StatusColors.of(context).ok,
                                )
                              : const SizedBox(
                                  key: ValueKey('idle'),
                                  width: 14,
                                  height: 14,
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted icon tile, title, detail and an optional trailing widget.
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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          child: Row(
            children: [
              IconBadge(icon: icon, color: tone.color(context), size: 36),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        maxLines: detailLines,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Gap.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A card holding rows separated by hairlines.
class GroupCard extends StatelessWidget {
  final List<Widget> children;

  const GroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: ClipRRect(
        borderRadius: Radii.card,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: Gap.lg, endIndent: Gap.lg),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A ✓ (works) or ○ (not yet) line, for "Still working" style lists.
class CheckLine extends StatelessWidget {
  final String label;
  final bool done;
  final double minHeight;

  const CheckLine(
    this.label, {
    super.key,
    required this.done,
    this.minHeight = 40,
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_rounded : Icons.radio_button_unchecked,
                size: done ? 20 : 18,
                color: done ? bt.mint : bt.faint,
                weight: 700,
              ),
              const SizedBox(width: Gap.md),
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
        horizontal: Gap.lg,
        vertical: Gap.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tubby != null)
            Tubby(mood: tubby!, size: 96)
          else
            IconBadge(icon: icon, color: tone.color(context), size: 56),
          const SizedBox(height: Gap.lg),
          Text(title, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Gap.xs),
          Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Gap.lg),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small tinted pill with an optional icon: mode badges, states.
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
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: large ? 13 : 12,
          color: c,
        );
    final body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: large ? Gap.md : 10,
        vertical: large ? Gap.sm : 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: large ? 15 : 13, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: large ? 16 : 14, color: c),
          ],
        ],
      ),
    );
    return Material(
      color: tone.tint(context),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                // A 48 dp touch target around a small badge.
                constraints: const BoxConstraints(minHeight: 32),
                child: body,
              ),
            ),
    );
  }
}

/// Pill with a status dot (kept for older screens).
class StatusPill extends StatelessWidget {
  final String label;
  final Tone tone;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: tone.tint(context),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tone.hue(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                label,
                style: text.labelLarge!.copyWith(
                  fontSize: 13,
                  color: tone.color(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum BannerKind { problem, info, digest, success, paused }

/// A full-width notice. Problems are Berry with `role=alert` semantics,
/// plain words and one fix; digests are lavender.
class NoticeBanner extends StatelessWidget {
  final BannerKind kind;
  final String title;
  final String? message;
  final IconData? icon;

  /// Replaces the icon tile (e.g. a small Tubby on the digest).
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
    final (bg, border, titleC, bodyC, solid, btn) = switch (kind) {
      BannerKind.problem => (
          bt.berryTint,
          bt.berryBorder,
          bt.berryInk,
          bt.berryInk,
          bt.berry,
          ButtonKind.berry,
        ),
      BannerKind.info => (
          bt.skyTint,
          bt.skyTint,
          bt.skyInk,
          bt.inkSoft,
          bt.sky,
          ButtonKind.ink,
        ),
      BannerKind.digest => (
          bt.lavenderTint,
          bt.lavenderTint,
          bt.ink,
          bt.inkSoft,
          bt.lavender,
          ButtonKind.ink,
        ),
      BannerKind.success => (
          bt.mintTint,
          bt.mintTint,
          bt.mintInk,
          bt.inkSoft,
          bt.mint,
          ButtonKind.mint,
        ),
      BannerKind.paused => (
          bt.sunTint,
          bt.sunTint,
          bt.sunInk,
          bt.inkSoft,
          bt.sun,
          ButtonKind.ink,
        ),
    };
    final card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.card,
        border: Border.all(color: border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading ??
                        IconBadge(
                          icon: icon ?? Icons.info_rounded,
                          color: solid,
                          solid: kind == BannerKind.problem,
                          size: 40,
                        ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text.titleMedium!.copyWith(
                              color: titleC,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              message!,
                              style: text.bodyMedium!.copyWith(
                                color: bodyC,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onTap != null && onAction == null)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.sm),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: bodyC,
                        ),
                      ),
                  ],
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: Gap.md),
                  PrimaryButton(
                    key: key == null ? null : ValueKey('$key-action'),
                    label: actionLabel!,
                    note: actionNote,
                    kind: btn,
                    height: 50,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (kind != BannerKind.problem) return card;
    return Semantics(liveRegion: true, container: true, child: card);
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
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final value = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    final color = muted ? bt.faint : bt.sky;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.settle,
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

/// A number that tweens to its new value ("Numbers tween").
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
      duration: Motion.of(context, Motion.slow),
      curve: Motion.settle,
      builder: (context, v, _) => Text(
        format(v.round()),
        style: style?.copyWith(fontFeatures: Fonts.tabular),
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
    this.height = 16,
    this.width,
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final base = bt.hairline;
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

/// A few skeleton rows inside a card while a list loads.
class SkeletonCard extends StatelessWidget {
  final int rows;

  const SkeletonCard({super.key, this.rows = 3});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: Gap.lg),
            Row(
              children: [
                const Skeleton(
                  height: 36,
                  width: 36,
                  radius: Radii.icon,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.5 + (i % 2) * 0.2,
                        child: const Skeleton(height: 12),
                      ),
                      const SizedBox(height: Gap.sm),
                      const Skeleton(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
    this.size = 96,
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
    duration: const Duration(milliseconds: 1600),
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
    final box = widget.size * 1.7;
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
                      width: widget.size * (1 + 0.65 * p),
                      height: widget.size * (1 + 0.65 * p),
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
              child: Icon(widget.icon, size: widget.size * 0.5, color: color),
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
              duration: Motion.of(context, Motion.medium),
              curve: Motion.settle,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 28,
              height: 6,
              decoration: BoxDecoration(
                color: i <= index ? bt.coral : bt.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bottom sheet in the house style: handle, Bricolage title, cream.
Future<T?> showBtSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
          Gap.xl,
          0,
          Gap.xl,
          Gap.xl,
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
              const SizedBox(height: Gap.xs + 2),
              DefaultTextStyle.merge(style: text.bodyMedium, child: lead!),
            ],
            const SizedBox(height: Gap.lg),
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
      icon: IconBadge(
        icon: icon,
        color: destructive ? bt.berryFill : bt.skyInk,
        size: 48,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        Gap.lg,
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
                  minimumSize: const Size(64, 48),
                )
              : FilledButton.styleFrom(minimumSize: const Size(64, 48)),
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
              size: 20,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(message, style: TextStyle(color: bt.onInkFill)),
            ),
          ],
        ),
      ),
    );
}

/// A small progress ring that only appears once an action has taken longer
/// than [delay] (a sign of trouble), so normal actions just flip.
class DelayedSpinner extends StatefulWidget {
  static const delay = Duration(milliseconds: 1500);

  final Color color;
  final double size;

  const DelayedSpinner({super.key, required this.color, this.size = 14});

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
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: _show
            ? CircularProgressIndicator(strokeWidth: 2, color: widget.color)
            : null,
      );
}
