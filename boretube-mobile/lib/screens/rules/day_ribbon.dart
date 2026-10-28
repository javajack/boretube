import 'package:flutter/material.dart';

import '../../agent/agent_models.dart';
import '../../ui/tokens.dart';

/// Today's quiet windows as fractions of the day (0 = midnight, 1 = the
/// next midnight): a window that started yesterday and crosses midnight
/// shows from 0, one that starts today and crosses midnight runs to 1.
List<(double, double)> quietWindowsToday(
  List<ScheduleRow> schedule,
  DateTime now,
) {
  const day = Duration.minutesPerDay;
  double at(String hhmm) {
    final p = hhmm.split(':');
    final h = (int.tryParse(p.first) ?? 0).clamp(0, 23);
    final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0).clamp(0, 59) : 0;
    return (h * Duration.minutesPerHour + m) / day;
  }

  final today = now.weekday;
  final yesterday = today == DateTime.monday ? DateTime.sunday : today - 1;
  final out = <(double, double)>[];
  for (final r in schedule) {
    final from = at(r.from);
    final to = at(r.to);
    if (r.days.contains(today)) {
      out.add(r.crossesMidnight ? (from, 1) : (from, to));
    }
    if (r.crossesMidnight && to > 0 && r.days.contains(yesterday)) {
      out.add((0, to));
    }
  }
  return out;
}

/// A 24-hour ribbon for today: quiet windows as sunflower bands on a
/// quiet track, a "now" marker and four hour ticks. One [Sizes.band] tall.
class DayRibbon extends StatelessWidget {
  final List<ScheduleRow> schedule;
  final DateTime now;
  final String semanticLabel;

  const DayRibbon({
    super.key,
    required this.schedule,
    required this.now,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final text = Theme.of(context).textTheme;
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final labels = h24
        ? const ['00', '06', '12', '18', '24']
        : const ['12a', '6a', '12p', '6p', '12a'];
    final t = (now.hour * Duration.minutesPerHour + now.minute) /
        Duration.minutesPerDay;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: Sizes.band,
        width: double.infinity,
        child: CustomPaint(
          painter: _RibbonPainter(
            windows: quietWindowsToday(schedule, now),
            now: t,
            track: bt.wash,
            band: bt.sun,
            tick: bt.borderStrong,
            marker: bt.ink,
            labels: labels,
            labelStyle: text.bodySmall!.copyWith(
              color: bt.muted,
              fontFeatures: Fonts.tabular,
              height: TypeSize.tightLeading,
            ),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final List<(double, double)> windows;
  final double now;
  final Color track;
  final Color band;
  final Color tick;
  final Color marker;
  final List<String> labels;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;

  _RibbonPainter({
    required this.windows,
    required this.now,
    required this.track,
    required this.band,
    required this.tick,
    required this.marker,
    required this.labels,
    required this.labelStyle,
    required this.textScaler,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The marker dot rides above the track; tick labels sit below it.
    const top = Gap.f8;
    const trackH = Sizes.control;
    final w = size.width;
    final rect = Rect.fromLTWH(0, top, w, trackH);
    final rr =
        RRect.fromRectAndRadius(rect, const Radius.circular(Radii.chipR));
    canvas.drawRRect(rr, Paint()..color = track);

    canvas.save();
    canvas.clipRRect(rr);
    final fill = Paint()..color = band;
    for (final (a, b) in windows) {
      canvas.drawRect(Rect.fromLTRB(w * a, top, w * b, top + trackH), fill);
    }
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = Sizes.hairline;
    for (var i = 1; i < labels.length - 1; i++) {
      final x = w * i / (labels.length - 1);
      canvas.drawLine(
        Offset(x, top + trackH - Gap.f8),
        Offset(x, top + trackH),
        tickPaint,
      );
    }
    canvas.restore();

    // Hour labels: the ends hug the edges, the rest are centred.
    final labelTop = top + trackH + Gap.f8;
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      final x = w * i / (labels.length - 1);
      final dx = i == 0
          ? 0.0
          : i == labels.length - 1
              ? w - tp.width
              : x - tp.width / 2;
      tp.paint(canvas, Offset(dx, labelTop));
    }

    // Now: a 2 px ink line through the track with a dot on top.
    final nx = (w * now).clamp(Sizes.dot / 2, w - Sizes.dot / 2);
    final m = Paint()
      ..color = marker
      ..strokeWidth = Sizes.focus
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(nx, top),
      Offset(nx, top + trackH + Gap.f4),
      m,
    );
    canvas.drawCircle(Offset(nx, top), Sizes.dot / 2, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.now != now ||
      old.track != track ||
      old.band != band ||
      old.marker != marker ||
      old.labelStyle != labelStyle ||
      old.windows.length != windows.length ||
      [
        for (var i = 0; i < windows.length; i++) windows[i] != old.windows[i],
      ].any((x) => x);
}
