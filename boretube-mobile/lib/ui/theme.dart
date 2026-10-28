import 'package:flutter/material.dart';

import 'tokens.dart';

/// boretube themes. Light (cream) is the default; "bedtime dark" is navy.
abstract final class AppTheme {
  static ThemeData light() => _build(BtColors.light, Brightness.light);

  static ThemeData dark() => _build(BtColors.dark, Brightness.dark);

  static TextTheme _text(BtColors c) {
    TextStyle ui(
      double size, {
      FontWeight weight = FontWeight.w400,
      double height = 1.45,
      Color? color,
      double letterSpacing = 0,
    }) =>
        TextStyle(
          fontFamily: Fonts.ui,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: letterSpacing,
          color: color ?? c.ink,
        );
    return TextTheme(
      // Countdown and the biggest numbers.
      displayMedium: Fonts.bricolage(
        56,
        height: 1,
        letterSpacing: -1,
        color: c.ink,
        tabularFigures: true,
      ),
      // Display 34.
      displaySmall: Fonts.bricolage(
        34,
        height: 1.12,
        letterSpacing: -0.5,
        color: c.ink,
      ),
      // Onboarding page titles.
      headlineLarge: Fonts.bricolage(
        30,
        letterSpacing: -0.4,
        color: c.ink,
      ),
      // Title 24.
      headlineMedium: Fonts.bricolage(24, height: 1.15, color: c.ink),
      // Headline 20.
      headlineSmall: Fonts.bricolage(
        20,
        weight: FontWeight.w700,
        height: 1.2,
        color: c.ink,
      ),
      titleLarge: Fonts.bricolage(
        20,
        weight: FontWeight.w700,
        height: 1.25,
        color: c.ink,
      ),
      titleMedium: ui(16, weight: FontWeight.w700, height: 1.35),
      titleSmall: ui(15, weight: FontWeight.w600, height: 1.35),
      bodyLarge: ui(16, height: 1.5, color: c.inkSoft),
      bodyMedium: ui(15, height: 1.5, color: c.inkSoft),
      // Caption 13.
      bodySmall: ui(13, height: 1.4, color: c.muted),
      labelLarge: ui(16, weight: FontWeight.w700, height: 1.2),
      labelMedium: ui(13, weight: FontWeight.w600, color: c.muted),
      labelSmall: ui(
        12,
        weight: FontWeight.w700,
        letterSpacing: 1.4,
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
    const buttonShape = RoundedRectangleBorder(borderRadius: Radii.buttons);
    const buttonSize = Size(64, 52);
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
          borderRadius: Radii.card,
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
              width: 2,
            ),
          ),
          overlayColor: overlay(c.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge!.copyWith(fontSize: 15),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.faint : c.skyInk,
          ),
          overlayColor: overlay(c.skyInk),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(c.ink),
          overlayColor: overlay(c.ink),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: c.surface,
          foregroundColor: c.ink,
          selectedBackgroundColor: c.coralWash,
          selectedForegroundColor: c.coralInk,
          side: BorderSide(color: c.borderStrong),
          textStyle: text.labelLarge!.copyWith(fontSize: 14),
          shape: buttonShape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.coralWash,
        side: BorderSide(color: c.borderStrong),
        labelStyle: text.labelLarge!.copyWith(fontSize: 14),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        labelStyle: text.bodyMedium!.copyWith(color: c.muted),
        hintStyle: text.bodyMedium!.copyWith(color: c.faint),
        border: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.skyInk, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.berryFill),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: c.sky,
        inactiveTrackColor: c.skyTint,
        thumbColor: c.surface,
        overlayColor: c.sky.withValues(alpha: 0.12),
        valueIndicatorColor: c.inkFill,
        valueIndicatorTextStyle: text.labelLarge!.copyWith(
          color: c.onInkFill,
        ),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 12,
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
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.sheetR)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.ink.withValues(alpha: 0.45),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(44, 5),
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inkFill,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.onInkFill),
        shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: c.coralTint,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        ),
        labelColor: c.coralInk,
        unselectedLabelColor: c.muted,
        labelStyle: text.labelLarge!.copyWith(fontSize: 14),
        unselectedLabelStyle: text.labelLarge!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: c.ink.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: c.border),
        ),
        textStyle: text.titleSmall,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        minVerticalPadding: Gap.md,
        iconColor: c.muted,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.sky,
        linearTrackColor: c.border,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
