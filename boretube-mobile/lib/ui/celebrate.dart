import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// A light confetti burst over the whole screen, for the few moments
/// that earn one (first win, first pause, first bedtime, a calm week).
///
/// No packages: one controller, one painter, ~70 paper bits that fall
/// with drag and flutter, then the overlay removes itself. With reduced
/// motion it is just a medium haptic.
Future<void> celebrate(BuildContext context, {Offset? from}) async {
  unawaited(HapticFeedback.mediumImpact());
  if (Motion.reduced(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final box = context.findRenderObject() as RenderBox?;
  final origin = from ??
      (box != null && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : null);
  final bt = context.bt;
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: ConfettiBurst(
        origin: origin,
        colors: [bt.coral, bt.sky, bt.mint, bt.sun, bt.lavender, bt.berry],
        onDone: () {
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class ConfettiBurst extends StatefulWidget {
  /// Where the burst starts (global); top-centre when null.
  final Offset? origin;
  final List<Color> colors;
  final VoidCallback? onDone;
  final int count;
  final Duration duration;

  const ConfettiBurst({
    super.key,
    required this.colors,
    this.origin,
    this.onDone,
    this.count = 70,
    this.duration = const Duration(milliseconds: 1900),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Bit {
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final double flutter;
  final Color color;
  final bool round;

  _Bit(math.Random r, List<Color> colors)
      : angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.95,
        speed = 520 + r.nextDouble() * 520,
        spin = (r.nextDouble() - 0.5) * 14,
        size = 6 + r.nextDouble() * 6,
        flutter = r.nextDouble() * math.pi * 2,
        color = colors[r.nextInt(colors.length)],
        round = r.nextDouble() < 0.25;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone?.call();
        })
        ..forward();
  late final List<_Bit> _bits = [
    // Seeded so the burst looks the same every time (and in tests).
    for (final r in [math.Random(7)])
      for (var i = 0; i < widget.count; i++) _Bit(r, widget.colors),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_c, _bits, widget.origin),
      );
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  final List<_Bit> bits;
  final Offset? origin;

  _ConfettiPainter(this.t, this.bits, this.origin) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final o = origin ?? Offset(size.width / 2, size.height * 0.35);
    final secs = t.value * 1.9;
    const gravity = 1300.0;
    const drag = 2.6;
    final fade = t.value < 0.75 ? 1.0 : 1 - (t.value - 0.75) / 0.25;
    final paint = Paint()..isAntiAlias = true;
    for (final b in bits) {
      // Velocity decays with drag; gravity pulls it down to a flutter.
      final k = (1 - math.exp(-drag * secs)) / drag;
      final dx =
          math.cos(b.angle) * b.speed * k + math.sin(secs * 6 + b.flutter) * 14;
      final dy =
          math.sin(b.angle) * b.speed * k + gravity * (secs / drag - k / drag);
      final p = o + Offset(dx, dy);
      if (p.dy > size.height + 20) continue;
      paint.color = b.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(b.spin * secs);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2.4, paint);
      } else {
        // Scale X by a cosine to fake the paper turning over.
        canvas
          ..scale(math.cos(secs * 9 + b.flutter).abs() * 0.8 + 0.2, 1)
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: b.size,
                height: b.size * 0.55,
              ),
              const Radius.circular(1.5),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
