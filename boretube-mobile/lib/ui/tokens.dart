import 'package:flutter/material.dart';

/// Spacing scale (4/8 grid).
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double page = 16;
}

/// Corner radii.
abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const tile = BorderRadius.all(Radius.circular(md));
}

/// Brand palette: calm slate surfaces, one warm amber accent, muted
/// status colours that stay readable on dark and light.
abstract final class Palette {
  static const amber = Color(0xFFF2A65A);
  static const amberDeep = Color(0xFFB8641F);

  // Dark surfaces.
  static const ink = Color(0xFF0E1317);
  static const slate1 = Color(0xFF151B20);
  static const slate2 = Color(0xFF1B2329);
  static const slate3 = Color(0xFF243039);
  static const mist = Color(0xFFE6EBEF);
  static const fog = Color(0xFF9AA7B1);

  // Light surfaces.
  static const paper = Color(0xFFF6F4F0);
  static const card = Color(0xFFFFFFFF);
  static const sand = Color(0xFFEDE8E1);
  static const graphite = Color(0xFF1E262C);
  static const stone = Color(0xFF5F6B74);

  // Status.
  static const ok = Color(0xFF5CC2A5);
  static const warn = Color(0xFFE8C468);
  static const bad = Color(0xFFE5735A);
  static const info = Color(0xFF6FA8DC);
  static const idle = Color(0xFF9AA7B1);
}

/// Semantic colours that follow the theme brightness.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color ok;
  final Color warn;
  final Color bad;
  final Color info;
  final Color idle;

  const StatusColors({
    required this.ok,
    required this.warn,
    required this.bad,
    required this.info,
    required this.idle,
  });

  static const dark = StatusColors(
    ok: Palette.ok,
    warn: Palette.warn,
    bad: Palette.bad,
    info: Palette.info,
    idle: Palette.idle,
  );

  static const light = StatusColors(
    ok: Color(0xFF1F8A6D),
    warn: Color(0xFFA77A12),
    bad: Color(0xFFC0482F),
    info: Color(0xFF2E6DA4),
    idle: Color(0xFF6B7780),
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? dark;

  @override
  StatusColors copyWith({
    Color? ok,
    Color? warn,
    Color? bad,
    Color? info,
    Color? idle,
  }) =>
      StatusColors(
        ok: ok ?? this.ok,
        warn: warn ?? this.warn,
        bad: bad ?? this.bad,
        info: info ?? this.info,
        idle: idle ?? this.idle,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      info: Color.lerp(info, other.info, t)!,
      idle: Color.lerp(idle, other.idle, t)!,
    );
  }
}
