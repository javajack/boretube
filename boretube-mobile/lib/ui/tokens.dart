import 'package:flutter/material.dart';

/// Spacing on an 8-point grid (4 is the half step).
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal screen gutter.
  static const double page = 20;
}

/// Corner radii. Deliberately tighter than the mockups so nothing feels
/// pillowy: pills are only for small chips and badges.
abstract final class Radii {
  static const double iconTile = 10;
  static const double input = 12;
  static const double button = 14;
  static const double tileR = 14;
  static const double cardR = 16;
  static const double heroR = 20;
  static const double sheetR = 24;
  static const double pill = 999;

  // Older names, kept so every screen speaks the same scale.
  static const double sm = input;
  static const double md = cardR;
  static const double lg = heroR;
  static const double xl = sheetR;

  static const card = BorderRadius.all(Radius.circular(cardR));
  static const hero = BorderRadius.all(Radius.circular(heroR));
  static const tile = BorderRadius.all(Radius.circular(tileR));
  static const buttons = BorderRadius.all(Radius.circular(button));
  static const icon = BorderRadius.all(Radius.circular(iconTile));
  static const field = BorderRadius.all(Radius.circular(input));
  static const sheet = BorderRadius.vertical(top: Radius.circular(sheetR));
}

/// Motion: short, springy, and skipped when the system asks for less.
abstract final class Motion {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 350);

  /// A gentle overshoot that settles quickly (spring-like).
  static const spring = Cubic(0.34, 1.36, 0.64, 1);
  static const settle = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when reduced motion is on.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Bundled typefaces (OFL, see assets/fonts). Both are variable fonts:
/// Flutter maps [FontWeight] onto the `wght` axis (verified in
/// test/ui/fonts_test.dart), and Bricolage also gets its `opsz` axis set
/// to the font size, the way browsers do with optical sizing.
abstract final class Fonts {
  static const display = 'BricolageGrotesque';
  static const ui = 'Figtree';

  static const tabular = [FontFeature.tabularFigures()];

  /// A Bricolage style with optical sizing matched to [size].
  static TextStyle bricolage(
    double size, {
    FontWeight weight = FontWeight.w800,
    double height = 1.15,
    double letterSpacing = 0,
    Color? color,
    bool tabularFigures = false,
  }) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        fontVariations: [FontVariation('opsz', size.clamp(12, 96))],
        fontFeatures: tabularFigures ? tabular : null,
      );
}

/// The brand palette for one brightness. Read it with `context.bt`.
@immutable
class BtColors extends ThemeExtension<BtColors> {
  final Color canvas;
  final Color surface;
  final Color border;

  /// Stronger outline for outlined buttons and unselected chips.
  final Color borderStrong;

  /// Dividers inside cards.
  final Color hairline;
  final Color ink;

  /// Body copy one step softer than [ink].
  final Color inkSoft;
  final Color muted;

  /// Disabled / "not yet" marks.
  final Color faint;

  final Color coral;

  /// Filled coral behind white text (meets AA for large bold labels).
  final Color coralFill;
  final Color coralPressed;
  final Color coralTint;
  final Color coralWash;
  final Color coralInk;

  final Color sky;
  final Color skyInk;
  final Color skyTint;

  final Color mint;
  final Color mintInk;
  final Color mintTint;

  final Color sun;
  final Color sunInk;
  final Color sunTint;

  final Color berry;
  final Color berryFill;
  final Color berryInk;
  final Color berryTint;
  final Color berryBorder;

  final Color lavender;
  final Color lavenderInk;
  final Color lavenderTint;

  /// The TV illustration: bezel and screen.
  final Color screen;
  final Color screenInner;

  /// Dark ink buttons (Continue, End break).
  final Color inkFill;
  final Color onInkFill;

  const BtColors({
    required this.canvas,
    required this.surface,
    required this.border,
    required this.borderStrong,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.faint,
    required this.coral,
    required this.coralFill,
    required this.coralPressed,
    required this.coralTint,
    required this.coralWash,
    required this.coralInk,
    required this.sky,
    required this.skyInk,
    required this.skyTint,
    required this.mint,
    required this.mintInk,
    required this.mintTint,
    required this.sun,
    required this.sunInk,
    required this.sunTint,
    required this.berry,
    required this.berryFill,
    required this.berryInk,
    required this.berryTint,
    required this.berryBorder,
    required this.lavender,
    required this.lavenderInk,
    required this.lavenderTint,
    required this.screen,
    required this.screenInner,
    required this.inkFill,
    required this.onInkFill,
  });

  static const light = BtColors(
    canvas: Color(0xFFFFF8F1),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFF0E6DA),
    borderStrong: Color(0xFFE0D3C3),
    hairline: Color(0xFFF4ECE2),
    ink: Color(0xFF1C1D3A),
    inkSoft: Color(0xFF3A3B57),
    muted: Color(0xFF5B5C78),
    faint: Color(0xFFB9B0A3),
    coral: Color(0xFFFF6B4A),
    coralFill: Color(0xFFF05A39),
    coralPressed: Color(0xFFD94A2B),
    coralTint: Color(0xFFFFE6DC),
    coralWash: Color(0xFFFFF0E9),
    coralInk: Color(0xFFB53A20),
    sky: Color(0xFF3A8DFF),
    skyInk: Color(0xFF1D5FC2),
    skyTint: Color(0xFFE6F0FF),
    mint: Color(0xFF1FBF8F),
    mintInk: Color(0xFF0E7C5B),
    mintTint: Color(0xFFDDF6EE),
    sun: Color(0xFFFFB020),
    sunInk: Color(0xFF8A5A00),
    sunTint: Color(0xFFFFF1D1),
    berry: Color(0xFFE5484D),
    berryFill: Color(0xFFC4313A),
    berryInk: Color(0xFF8E1F23),
    berryTint: Color(0xFFFDECEC),
    berryBorder: Color(0xFFF6C9CA),
    lavender: Color(0xFF8C7CFF),
    lavenderInk: Color(0xFF4B3FB0),
    lavenderTint: Color(0xFFEEEAFF),
    screen: Color(0xFF1C1D3A),
    screenInner: Color(0xFF2A2B4D),
    inkFill: Color(0xFF1C1D3A),
    onInkFill: Color(0xFFFFFFFF),
  );

  /// Bedtime dark: navy base, accents dimmed about 10%.
  static const dark = BtColors(
    canvas: Color(0xFF12132A),
    surface: Color(0xFF1C1D3A),
    border: Color(0xFF2B2C4C),
    borderStrong: Color(0xFF3B3C60),
    hairline: Color(0xFF26274A),
    ink: Color(0xFFF4EEE6),
    inkSoft: Color(0xFFD6D3E4),
    muted: Color(0xFFA9AACB),
    faint: Color(0xFF5D5E80),
    coral: Color(0xFFE8664A),
    coralFill: Color(0xFFD9573A),
    coralPressed: Color(0xFFC24A30),
    coralTint: Color(0xFF3A2532),
    coralWash: Color(0xFF2E2238),
    coralInk: Color(0xFFFFA48E),
    sky: Color(0xFF4B8FE8),
    skyInk: Color(0xFF9CC2FF),
    skyTint: Color(0xFF1F2E55),
    mint: Color(0xFF22AD83),
    mintInk: Color(0xFF7FDDBE),
    mintTint: Color(0xFF173A3C),
    sun: Color(0xFFE8A12A),
    sunInk: Color(0xFFFFD27A),
    sunTint: Color(0xFF3A3024),
    berry: Color(0xFFD24D52),
    berryFill: Color(0xFFC03A42),
    berryInk: Color(0xFFFFB3B5),
    berryTint: Color(0xFF3A1F2E),
    berryBorder: Color(0xFF5C2A38),
    lavender: Color(0xFF8577E6),
    lavenderInk: Color(0xFFC9C1FF),
    lavenderTint: Color(0xFF2A2752),
    screen: Color(0xFF0B0C1E),
    screenInner: Color(0xFF2A2B4D),
    inkFill: Color(0xFFF4EEE6),
    onInkFill: Color(0xFF1C1D3A),
  );

  @override
  BtColors copyWith() => this;

  @override
  BtColors lerp(BtColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BtColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      hairline: l(hairline, other.hairline),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      coral: l(coral, other.coral),
      coralFill: l(coralFill, other.coralFill),
      coralPressed: l(coralPressed, other.coralPressed),
      coralTint: l(coralTint, other.coralTint),
      coralWash: l(coralWash, other.coralWash),
      coralInk: l(coralInk, other.coralInk),
      sky: l(sky, other.sky),
      skyInk: l(skyInk, other.skyInk),
      skyTint: l(skyTint, other.skyTint),
      mint: l(mint, other.mint),
      mintInk: l(mintInk, other.mintInk),
      mintTint: l(mintTint, other.mintTint),
      sun: l(sun, other.sun),
      sunInk: l(sunInk, other.sunInk),
      sunTint: l(sunTint, other.sunTint),
      berry: l(berry, other.berry),
      berryFill: l(berryFill, other.berryFill),
      berryInk: l(berryInk, other.berryInk),
      berryTint: l(berryTint, other.berryTint),
      berryBorder: l(berryBorder, other.berryBorder),
      lavender: l(lavender, other.lavender),
      lavenderInk: l(lavenderInk, other.lavenderInk),
      lavenderTint: l(lavenderTint, other.lavenderTint),
      screen: l(screen, other.screen),
      screenInner: l(screenInner, other.screenInner),
      inkFill: l(inkFill, other.inkFill),
      onInkFill: l(onInkFill, other.onInkFill),
    );
  }
}

extension BtTheme on BuildContext {
  BtColors get bt => Theme.of(this).extension<BtColors>() ?? BtColors.light;
}

/// Semantic status colours (readable as text on cards), derived from the
/// brand palette.
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

  static final light = StatusColors(
    ok: BtColors.light.mintInk,
    warn: BtColors.light.sunInk,
    bad: BtColors.light.berryFill,
    info: BtColors.light.skyInk,
    idle: BtColors.light.muted,
  );

  static final dark = StatusColors(
    ok: BtColors.dark.mintInk,
    warn: BtColors.dark.sunInk,
    bad: BtColors.dark.berryInk,
    info: BtColors.dark.skyInk,
    idle: BtColors.dark.muted,
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

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
