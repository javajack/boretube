import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tubby's moods. Calm (default), asleep (paused / bedtime), cleaning
/// (cheering, tidy-up) and guard (Always On).
enum TubbyMood { calm, asleep, cleaning, guard }

/// Tubby, the boretube TV. Drawn from the brand SVG (viewBox 120×110).
///
/// Shows up only in onboarding, empty states, celebrations, the paused
/// hero and on the TV card. Idles gently (blink, drifting z's, twinkle)
/// unless the system asks for reduced motion.
class Tubby extends StatefulWidget {
  final TubbyMood mood;
  final double size;

  /// Body colour; defaults per mood (sky, sunflower, lavender, mint).
  final Color? body;

  /// Inner screen colour; defaults to cream (navy when asleep).
  final Color? screen;
  final bool antennas;
  final bool legs;

  /// Rosy cheeks (the logo and the welcome screen).
  final bool cheeks;

  /// A bigger, open smile (celebrations).
  final bool beaming;
  final bool animate;
  final String? semanticLabel;

  const Tubby({
    super.key,
    this.mood = TubbyMood.calm,
    this.size = 120,
    this.body,
    this.screen,
    this.antennas = true,
    this.legs = true,
    this.cheeks = false,
    this.beaming = false,
    this.animate = true,
    this.semanticLabel,
  });

  static const aspect = 110 / 120;

  @override
  State<Tubby> createState() => _TubbyState();
}

class _TubbyState extends State<Tubby> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Tubby old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.animate && !Motion.reduced(context);
    if (run == _running) return;
    _running = run;
    if (run) {
      _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final body = widget.body ??
        switch (widget.mood) {
          TubbyMood.calm => bt.sky,
          TubbyMood.asleep => bt.sun,
          TubbyMood.cleaning => bt.lavender,
          TubbyMood.guard => bt.mint,
        };
    final label = widget.semanticLabel ??
        switch (widget.mood) {
          TubbyMood.calm => 'Tubby the TV, smiling',
          TubbyMood.asleep => 'Tubby the TV, asleep',
          TubbyMood.cleaning => 'Tubby the TV, cheering',
          TubbyMood.guard => 'Tubby the TV, on guard',
        };
    return Semantics(
      image: true,
      label: label,
      child: SizedBox(
        width: widget.size,
        height: widget.size * Tubby.aspect,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: TubbyPainter(
              mood: widget.mood,
              body: body,
              screen: widget.screen ??
                  (widget.mood == TubbyMood.asleep
                      ? const Color(0xFF2A2B4D)
                      : const Color(0xFFFFF8F1)),
              limbs: bt.ink,
              antennas: widget.antennas,
              legs: widget.legs,
              cheeks: widget.cheeks,
              beaming: widget.beaming,
              t: _c,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints Tubby in a 120×110 box scaled to fit. [t] (0–1, repeating)
/// drives the idle animation.
class TubbyPainter extends CustomPainter {
  final TubbyMood mood;
  final Color body;
  final Color screen;

  /// Antennas and legs: ink on cream, cream on navy.
  final Color limbs;
  final bool antennas;
  final bool legs;
  final bool cheeks;
  final bool beaming;
  final Animation<double> t;

  static const _face = Color(0xFF1C1D3A);
  static const _cream = Color(0xFFFFF8F1);
  static const _coral = Color(0xFFFF6B4A);
  static const _sun = Color(0xFFFFB020);

  TubbyPainter({
    required this.mood,
    required this.body,
    required this.screen,
    required this.limbs,
    required this.t,
    this.antennas = true,
    this.legs = true,
    this.cheeks = false,
    this.beaming = false,
  }) : super(repaint: t);

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 120, size.height / 110);
    canvas
      ..save()
      ..translate(
        (size.width - 120 * s) / 2,
        (size.height - 110 * s) / 2,
      )
      ..scale(s);
    final v = t.value;

    if (antennas) {
      final p = _stroke(limbs, 5);
      canvas
        ..drawLine(const Offset(44, 14), const Offset(34, 2), p)
        ..drawLine(const Offset(76, 14), const Offset(86, 2), p);
    }
    canvas
      ..drawRRect(
        RRect.fromLTRBR(6, 14, 114, 94, const Radius.circular(26)),
        _fill(body),
      )
      ..drawRRect(
        RRect.fromLTRBR(18, 25, 102, 83, const Radius.circular(18)),
        _fill(screen),
      );
    if (legs) {
      final p = _fill(limbs);
      canvas
        ..drawRRect(
          RRect.fromLTRBR(32, 94, 42, 106, const Radius.circular(4)),
          p,
        )
        ..drawRRect(
          RRect.fromLTRBR(78, 94, 88, 106, const Radius.circular(4)),
          p,
        );
    }

    switch (mood) {
      case TubbyMood.asleep:
        _asleep(canvas, v);
      case TubbyMood.calm:
        _eyes(canvas, v);
        _smile(canvas);
      case TubbyMood.cleaning:
        _eyes(canvas, v);
        _bigSmile(canvas);
        _sparkle(canvas, v);
      case TubbyMood.guard:
        _eyes(canvas, v);
        canvas.drawLine(
          const Offset(50, 65),
          const Offset(70, 65),
          _stroke(_face, 5),
        );
        _shield(canvas);
    }
    if (cheeks && mood != TubbyMood.asleep) {
      final p = _fill(_coral.withValues(alpha: 0.55));
      canvas
        ..drawCircle(const Offset(33, 64), 5, p)
        ..drawCircle(const Offset(87, 64), 5, p);
    }
    canvas.restore();
  }

  /// Open eyes with a quick blink near the end of each loop.
  void _eyes(Canvas canvas, double v) {
    final blink = v > 0.94 ? math.sin((v - 0.94) / 0.06 * math.pi) : 0.0;
    final ry = 6 * (1 - 0.85 * blink);
    final p = _fill(_face);
    for (final x in const [45.0, 75.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 50), width: 12, height: ry * 2),
        p,
      );
    }
  }

  void _smile(Canvas canvas) {
    if (beaming) return _bigSmile(canvas);
    canvas.drawPath(
      Path()
        ..moveTo(48, 64)
        ..quadraticBezierTo(60, 74, 72, 64),
      _stroke(_face, 5),
    );
  }

  void _bigSmile(Canvas canvas) => canvas.drawPath(
        Path()
          ..moveTo(46, 63)
          ..quadraticBezierTo(60, 77, 74, 63),
        _stroke(_face, 5),
      );

  void _asleep(Canvas canvas, double v) {
    final lid = _stroke(_cream, 4.5);
    canvas
      ..drawPath(
        Path()
          ..moveTo(38, 52)
          ..quadraticBezierTo(45, 58, 52, 52),
        lid,
      )
      ..drawPath(
        Path()
          ..moveTo(68, 52)
          ..quadraticBezierTo(75, 58, 82, 52),
        lid,
      )
      ..drawPath(
        Path()
          ..moveTo(54, 68)
          ..quadraticBezierTo(60, 71, 66, 68),
        _stroke(_cream, 4),
      );
    // Two z's drifting up and fading, offset in phase.
    for (final (phase, x, y, fs) in const [
      (0.0, 88.0, 42.0, 14.0),
      (0.5, 95.0, 33.0, 10.0),
    ]) {
      final p = (v + phase) % 1.0;
      final rise = -6 * p;
      final alpha = (p < 0.15 ? p / 0.15 : 1 - (p - 0.15) / 0.85) * 0.6 + 0.4;
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontFamily: Fonts.ui,
            fontWeight: FontWeight.w700,
            fontSize: fs,
            color: _cream.withValues(alpha: alpha.clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y + rise - tp.height * 0.8));
    }
  }

  void _sparkle(Canvas canvas, double v) {
    final k = 0.85 + 0.15 * math.sin(v * 2 * math.pi * 2);
    canvas
      ..save()
      ..translate(100, 16)
      ..scale(k)
      ..translate(-100, -16)
      ..drawPath(
        Path()
          ..moveTo(100, 6)
          ..relativeLineTo(3, 7)
          ..relativeLineTo(7, 3)
          ..relativeLineTo(-7, 3)
          ..relativeLineTo(-3, 7)
          ..relativeLineTo(-3, -7)
          ..relativeLineTo(-7, -3)
          ..relativeLineTo(7, -3)
          ..close(),
        _fill(_sun),
      )
      ..restore();
  }

  void _shield(Canvas canvas) {
    canvas
      ..drawPath(
        Path()
          ..moveTo(96, 60)
          ..relativeLineTo(14, 5)
          ..relativeLineTo(0, 10)
          ..relativeCubicTo(0, 8, -6, 13, -14, 15)
          ..relativeCubicTo(-8, -2, -14, -7, -14, -15)
          ..lineTo(82, 65)
          ..close(),
        _fill(_face),
      )
      ..drawPath(
        Path()
          ..moveTo(90, 76)
          ..relativeLineTo(4, 4)
          ..relativeLineTo(8, -8),
        _stroke(body, 3.5),
      );
  }

  @override
  bool shouldRepaint(TubbyPainter old) =>
      old.mood != mood ||
      old.body != body ||
      old.screen != screen ||
      old.limbs != limbs ||
      old.antennas != antennas ||
      old.legs != legs ||
      old.cheeks != cheeks ||
      old.beaming != beaming;
}
