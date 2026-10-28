import 'package:flutter/material.dart';

/// One ratio for everything: φ = 1.618 and its square root √φ ≈ 1.272.
/// Nothing is sized by eye; every value below is a named step, and screens
/// reference these tokens only (enforced by test/ui/token_lint_test.dart).
abstract final class Phi {
  static const double ratio = 1.618;

  /// The larger part of a golden split (61.8 %).
  static const double major = 0.618;

  /// The smaller part of a golden split (38.2 %).
  static const double minor = 0.382;

  /// Flex weights for a 61.8 / 38.2 row (Expanded(flex: ...)).
  static const int majorFlex = 618;
  static const int minorFlex = 382;
}

/// Fibonacci spacing: 4 · 8 · 13 · 21 · 34 · 55.
abstract final class Gap {
  static const double f4 = 4;
  static const double f8 = 8;
  static const double f13 = 13;
  static const double f21 = 21;
  static const double f34 = 34;
  static const double f55 = 55;

  /// The gap inside a component (icon to label, title to value).
  static const double inside = f13;

  /// Between related components (a control and its caption, rows' blocks).
  static const double related = f21;

  /// Between sections of a screen.
  static const double section = f34;

  /// Around the hero.
  static const double hero = f55;

  /// Horizontal screen gutter.
  static const double gutter = f21;
}

/// The √φ type scale from 13: caption · body · headline · title · display
/// · hero numerals · TV-card headline. Bricolage at 21 and up, Figtree
/// below.
abstract final class TypeSize {
  static const double caption = 13;
  static const double body = 16.5;
  static const double headline = 21;
  static const double title = 26.5;
  static const double display = 34;
  static const double hero = 43;
  static const double tv = 55;

  /// Line heights: 1.3 on display sizes, 1.5 on body copy.
  static const double displayLeading = 1.3;
  static const double bodyLeading = 1.5;

  /// One line of label text (chips, buttons): no extra leading.
  static const double tightLeading = 1.15;
}

/// Component heights on φ steps: a primary is φ× a secondary, and a
/// secondary is φ× a chip, so the hierarchy reads by size alone.
abstract final class Sizes {
  /// Small chip or badge.
  static const double chip = 34;

  /// Secondary control (buttons, steppers); padded to [touch].
  static const double control = 44;

  /// A list row or tile; also the primary button.
  static const double row = 55;

  /// The coral primary button (55–60 inside its [band]).
  static const double primary = 58;

  /// The hero action band around the primary.
  static const double band = 89;

  /// Minimum touch target.
  static const double touch = 48;

  /// Inline icon in a row.
  static const double icon = 20;

  /// Icon inside a 44 control, optically centred.
  static const double iconControl = 24;

  /// Icon inside a chip or badge.
  static const double iconSmall = 16;

  /// Small icon tile (Better TV destinations only).
  static const double tile = 34;

  /// Avatar / round control in the header.
  static const double avatar = 44;

  /// Lines and bars.
  static const double hairline = 1;
  static const double focus = 2;
  static const double bar = 4;
  static const double dot = 8;

  /// Tubby: small (rows, banners), medium (status hero), large (empty
  /// states, paused hero).
  static const double tubbySmall = 34;
  static const double tubby = 55;
  static const double tubbyLarge = 89;

  /// Readable column width on wide screens.
  static const double maxContent = 610;
}

/// Corner radii on φ steps, reduced so nothing feels pillowy.
abstract final class Radii {
  static const double chipR = 8;
  static const double controlR = 13;
  static const double heroR = 21;

  /// Only for true circles (avatar, dots).
  static const double round = 999;

  static const chip = BorderRadius.all(Radius.circular(chipR));
  static const control = BorderRadius.all(Radius.circular(controlR));
  static const hero = BorderRadius.all(Radius.circular(heroR));
  static const sheet = BorderRadius.vertical(top: Radius.circular(heroR));
}

/// Motion on φ steps. No bounce on UI, no animate-on-scroll; reduced
/// motion turns everything into a 120 ms crossfade.
abstract final class Motion {
  /// Press feedback (scale 0.97, opacity).
  static const press = Duration(milliseconds: 120);

  /// State flips (tile → muted, chip selection).
  static const flip = Duration(milliseconds: 200);

  /// Sheets and hero state changes (calm → paused); numbers tween.
  static const sheet = Duration(milliseconds: 320);

  /// Only the pause "dimming" and Tubby falling asleep.
  static const slow = Duration(milliseconds: 520);

  /// List entrance stagger, for at most [staggerMax] items.
  static const stagger = Duration(milliseconds: 34);
  static const staggerMax = 5;

  static const pressScale = 0.97;

  /// Ease in (entering) and out (leaving).
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or the 120 ms crossfade when reduced motion is on.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? press : d;
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
    double height = TypeSize.displayLeading,
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

  /// The 1 px warm hairline between rows.
  final Color hairline;

  /// Quiet fill: tracks, idle tints, skeletons.
  final Color wash;
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
    required this.wash,
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
    hairline: Color(0xFFEADFD1),
    wash: Color(0xFFF4ECE2),
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
    hairline: Color(0xFF2E2F52),
    wash: Color(0xFF26274A),
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
      wash: l(wash, other.wash),
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
