import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Semantic tone for status rows, pills and tiles.
enum Tone { ok, warn, bad, info, idle, accent }

extension ToneColor on Tone {
  Color color(BuildContext context) {
    final s = StatusColors.of(context);
    return switch (this) {
      Tone.ok => s.ok,
      Tone.warn => s.warn,
      Tone.bad => s.bad,
      Tone.info => s.info,
      Tone.idle => s.idle,
      Tone.accent => Theme.of(context).colorScheme.primary,
    };
  }
}

/// Uppercase label above a group of cards, with an optional action.
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
    );
  }
}

/// Rounded surface used for every grouped block in the app.
class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  const InfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null
              ? color ?? scheme.surfaceContainerLow
              : null,
          gradient: gradient,
          borderRadius: Radii.card,
          border: Border.all(color: borderColor ?? scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: Radii.card,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A round tinted icon badge.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Large rounded quick-action tile: icon, label and a state line.
/// [active] gives it a filled accent look (e.g. "Muted").
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? state;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;
  final Tone tone;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.state,
    this.active = false,
    this.busy = false,
    this.onTap,
    this.tone = Tone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = tone.color(context);
    final enabled = onTap != null && !busy;
    final bg = active
        ? accent.withValues(alpha: 0.18)
        : scheme.surfaceContainer;
    final fg = active ? accent : scheme.onSurface;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.card,
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.55)
                : scheme.outlineVariant,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: Radii.card,
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: busy
                        ? SizedBox(
                            key: const ValueKey('busy'),
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: fg,
                            ),
                          )
                        : Icon(
                            icon,
                            key: ValueKey(icon),
                            size: 26,
                            color: enabled || busy
                                ? fg
                                : scheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      color: enabled || busy ? fg : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (state != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        state!,
                        key: ValueKey(state),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
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

/// Coloured leading icon, title, one-line detail and a trailing widget.
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
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: Gap.lg, endIndent: Gap.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Friendly empty / error state: icon, title, sentence, optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Tone tone;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = Tone.idle,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xl,
        vertical: Gap.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, color: tone.color(context), size: 64),
          const SizedBox(height: Gap.lg),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Gap.xs),
          Text(message, style: text.bodySmall, textAlign: TextAlign.center),
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

/// Pill-shaped status chip with a glowing dot.
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
    final c = tone.color(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
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
                  color: c,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated horizontal volume meter.
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
    final scheme = Theme.of(context).colorScheme;
    final value = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    final color = muted ? StatusColors.of(context).idle : scheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: scheme.surfaceContainerHighest),
              ),
              FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.7), color],
                    ),
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHigh;
    final glow = scheme.surfaceContainerHighest;
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
                  radius: BorderRadius.all(Radius.circular(12)),
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

/// Icon that breathes in a soft halo; for "look at the TV" moments.
class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const PulsingIcon({
    super.key,
    required this.icon,
    this.size = 96,
    this.color,
  });

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final box = widget.size * 1.9;
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
                      width: widget.size * (1 + 0.85 * p),
                      height: widget.size * (1 + 0.85 * p),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.18 * (1 - p)),
                      ),
                    );
                  },
                ),
              Transform.scale(
                scale: 1 + 0.04 * math.sin(_c.value * 2 * math.pi),
                child: child,
              ),
            ],
          );
        },
        child: Container(
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

/// Row of dots/bars showing progress through onboarding.
class StepIndicator extends StatelessWidget {
  final int count;
  final int index;

  const StepIndicator({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= index
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "Protected" or "Disabled".
class TagChip extends StatelessWidget {
  final String label;
  final Tone tone;

  const TagChip(this.label, {super.key, this.tone = Tone.idle});

  @override
  Widget build(BuildContext context) {
    final c = tone.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c),
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
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        icon,
        size: 32,
        color: destructive ? scheme.error : scheme.primary,
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
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(64, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(64, 44)),
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
  final scheme = Theme.of(context).colorScheme;
  final s = StatusColors.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? s.ok : s.bad,
              size: 20,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onInverseSurface),
              ),
            ),
          ],
        ),
      ),
    );
}
