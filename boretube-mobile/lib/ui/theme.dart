import 'package:flutter/material.dart';

import 'tokens.dart';

/// boretube themes. Light (cream) is the default; "bedtime dark" is navy.
abstract final class AppTheme {
  static ThemeData light() => _build(BtColors.light, Brightness.light);

  static ThemeData dark() => _build(BtColors.dark, Brightness.dark);

  /// The √φ scale (13 · 16.5 · 21 · 26.5 · 34 · 43): Bricolage from 21 up,
  /// Figtree below; 1.3 leading on display sizes, 1.5 on body copy.
  static TextTheme _text(BtColors c) {
    TextStyle ui(
      double size, {
      FontWeight weight = FontWeight.w400,
      double height = TypeSize.bodyLeading,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: Fonts.ui,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? c.ink,
        );
    return TextTheme(
      // Hero numerals: countdown and clock.
      displayMedium: Fonts.bricolage(
        TypeSize.hero,
        height: TypeSize.tightLeading,
        color: c.ink,
        tabularFigures: true,
      ),
      // Display 34: page titles.
      displaySmall: Fonts.bricolage(TypeSize.display, color: c.ink),
      // Onboarding page titles (display 34).
      headlineLarge: Fonts.bricolage(TypeSize.display, color: c.ink),
      // Title 26.5: sheet titles, hero headlines.
      headlineMedium: Fonts.bricolage(TypeSize.title, color: c.ink),
      // Headline 21.
      headlineSmall: Fonts.bricolage(
        TypeSize.headline,
        weight: FontWeight.w700,
        color: c.ink,
      ),
      // Group headings: sentence case, Bricolage 21/700.
      titleLarge: Fonts.bricolage(
        TypeSize.headline,
        weight: FontWeight.w700,
        color: c.ink,
      ),
      titleMedium: ui(
        TypeSize.body,
        weight: FontWeight.w700,
        height: TypeSize.displayLeading,
      ),
      titleSmall: ui(
        TypeSize.body,
        weight: FontWeight.w600,
        height: TypeSize.displayLeading,
      ),
      bodyLarge: ui(TypeSize.body, color: c.inkSoft),
      bodyMedium: ui(TypeSize.body, color: c.inkSoft),
      // Caption 13.
      bodySmall: ui(TypeSize.caption, color: c.muted),
      labelLarge: ui(
        TypeSize.body,
        weight: FontWeight.w700,
        height: TypeSize.tightLeading,
      ),
      labelMedium: ui(
        TypeSize.caption,
        weight: FontWeight.w600,
        height: TypeSize.tightLeading,
        color: c.muted,
      ),
      // Kept for the TV-card preview only (no uppercase eyebrows).
      labelSmall: ui(
        TypeSize.caption,
        weight: FontWeight.w700,
        height: TypeSize.tightLeading,
        color: c.muted,
      ),
    );
  }

  static ThemeData _build(BtColors c, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.coralFill,
      onPrimary: Colors.white,
      primaryContainer: c.coralTint,
      onPrimaryContainer: c.coralInk,
      secondary: c.sky,
      onSecondary: Colors.white,
      secondaryContainer: c.skyTint,
      onSecondaryContainer: c.skyInk,
      tertiary: c.mint,
      onTertiary: dark ? c.canvas : const Color(0xFF06392A),
      tertiaryContainer: c.mintTint,
      onTertiaryContainer: c.mintInk,
      error: c.berryFill,
      onError: Colors.white,
      errorContainer: c.berryTint,
      onErrorContainer: c.berryInk,
      surface: c.canvas,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: dark ? const Color(0xFF222344) : c.coralWash,
      surfaceContainerHigh: dark ? const Color(0xFF2A2B4D) : c.hairline,
      surfaceContainerHighest: dark ? const Color(0xFF33345A) : c.border,
      outline: c.borderStrong,
      outlineVariant: c.border,
      inverseSurface: c.inkFill,
      onInverseSurface: c.onInkFill,
      inversePrimary: c.coralTint,
      shadow: Colors.black,
      scrim: Colors.black,
    );
    final text = _text(c);
    final status = dark ? StatusColors.dark : StatusColors.light;
    const buttonShape = RoundedRectangleBorder(borderRadius: Radii.control);
    const buttonSize = Size(Sizes.control, Sizes.control);
    WidgetStateProperty<Color?> overlay(Color base) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed)
              ? base.withValues(alpha: 0.12)
              : s.contains(WidgetState.hovered) ||
                      s.contains(WidgetState.focused)
                  ? base.withValues(alpha: 0.06)
                  : null,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Fonts.ui,
      textTheme: text,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      extensions: [c, status],
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.ink, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.control,
          side: BorderSide(color: c.border),
        ),
      ),
      // Ink is the default filled button; coral is reserved for the one
      // hero action per screen (PrimaryButton).
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.border : c.inkFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.muted : c.onInkFill,
          ),
          overlayColor: overlay(c.onInkFill),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.faint : c.ink,
          ),
          backgroundColor: WidgetStatePropertyAll(c.surface),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color:
                  s.contains(WidgetState.disabled) ? c.border : c.borderStrong,
            ),
          ),
          overlayColor: overlay(c.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size(Sizes.touch, Sizes.touch)),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.faint : c.skyInk,
          ),
          overlayColor: overlay(c.skyInk),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size(Sizes.touch, Sizes.touch)),
          foregroundColor: WidgetStatePropertyAll(c.ink),
          overlayColor: overlay(c.ink),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(Sizes.touch, Sizes.touch),
          backgroundColor: c.surface,
          foregroundColor: c.ink,
          selectedBackgroundColor: c.coralWash,
          selectedForegroundColor: c.coralInk,
          side: BorderSide(color: c.borderStrong),
          textStyle: text.labelMedium,
          shape: buttonShape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.coralWash,
        side: BorderSide(color: c.borderStrong),
        labelStyle: text.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.f13,
          vertical: Gap.f13,
        ),
        labelStyle: text.bodyMedium!.copyWith(color: c.muted),
        hintStyle: text.bodyMedium!.copyWith(color: c.faint),
        border: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.skyInk, width: Sizes.focus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: c.berryFill),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: Sizes.bar,
        activeTrackColor: c.sky,
        inactiveTrackColor: c.skyTint,
        thumbColor: c.surface,
        overlayColor: c.sky.withValues(alpha: 0.12),
        valueIndicatorColor: c.inkFill,
        valueIndicatorTextStyle: text.labelLarge!.copyWith(
          color: c.onInkFill,
        ),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: Gap.f13 - Sizes.hairline,
          elevation: 2,
          pressedElevation: 4,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.mintInk : c.border,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : c.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.mintInk : null,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.chipR / 2)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.hero),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.ink.withValues(alpha: 0.45),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(Gap.f34, Sizes.bar),
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inkFill,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.onInkFill),
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: c.coralTint,
          borderRadius: Radii.chip,
        ),
        labelColor: c.coralInk,
        unselectedLabelColor: c.muted,
        labelStyle: text.labelMedium,
        unselectedLabelStyle: text.labelMedium,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: c.ink.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.control,
          side: BorderSide(color: c.border),
        ),
        textStyle: text.titleSmall,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: Gap.f13,
        iconColor: c.muted,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: Sizes.hairline,
        space: Sizes.hairline,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.sky,
        linearTrackColor: c.border,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
