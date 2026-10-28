import 'package:flutter/material.dart';

import 'tokens.dart';

/// Boretube themes. Dark is the default; light mirrors it.
abstract final class AppTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Palette.amber,
          onPrimary: Color(0xFF2A1604),
          primaryContainer: Color(0xFF4A2F14),
          onPrimaryContainer: Color(0xFFFFDDBC),
          secondary: Palette.ok,
          onSecondary: Color(0xFF00382B),
          secondaryContainer: Color(0xFF1D3A33),
          onSecondaryContainer: Color(0xFFBFEDDD),
          tertiary: Palette.info,
          onTertiary: Color(0xFF07223A),
          error: Palette.bad,
          onError: Color(0xFF3A0E05),
          errorContainer: Color(0xFF4D2219),
          onErrorContainer: Color(0xFFFFDAD2),
          surface: Palette.ink,
          onSurface: Palette.mist,
          onSurfaceVariant: Palette.fog,
          surfaceContainerLowest: Color(0xFF0A0E11),
          surfaceContainerLow: Palette.slate1,
          surfaceContainer: Palette.slate2,
          surfaceContainerHigh: Palette.slate3,
          surfaceContainerHighest: Color(0xFF2C3943),
          outline: Color(0xFF3A4852),
          outlineVariant: Color(0xFF29343C),
          inverseSurface: Palette.mist,
          onInverseSurface: Palette.ink,
          shadow: Colors.black,
        ),
        status: StatusColors.dark,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Palette.amberDeep,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFFFE2C6),
          onPrimaryContainer: Color(0xFF3A1F05),
          secondary: Color(0xFF1F8A6D),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFCFEFE4),
          onSecondaryContainer: Color(0xFF00382B),
          tertiary: Color(0xFF2E6DA4),
          onTertiary: Colors.white,
          error: Color(0xFFC0482F),
          onError: Colors.white,
          errorContainer: Color(0xFFFFDAD2),
          onErrorContainer: Color(0xFF3A0E05),
          surface: Palette.paper,
          onSurface: Palette.graphite,
          onSurfaceVariant: Palette.stone,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Palette.card,
          surfaceContainer: Color(0xFFF9F7F3),
          surfaceContainerHigh: Palette.sand,
          surfaceContainerHighest: Color(0xFFE3DDD4),
          outline: Color(0xFFC9C2B8),
          outlineVariant: Color(0xFFE2DCD3),
          inverseSurface: Palette.graphite,
          onInverseSurface: Palette.paper,
          shadow: Colors.black,
        ),
        status: StatusColors.light,
      );

  static TextTheme _text(Color on, Color muted) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: on,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: on,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: on,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: on,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: on,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: on,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: on),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: on),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: on,
        ),
        labelMedium: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: muted,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: muted,
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required StatusColors status,
  }) {
    // Merge over Material typography so every style (incl. button and
    // app bar overrides) keeps the platform font family.
    final typography = Typography.material2021();
    final base = brightness == Brightness.dark
        ? typography.white
        : typography.black;
    final text = base.merge(_text(scheme.onSurface, scheme.onSurfaceVariant));
    const tileShape = RoundedRectangleBorder(borderRadius: Radii.tile);
    const buttonSize = Size(64, 52);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      typography: typography,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [status],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium!.copyWith(
            color: s.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: tileShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: tileShape,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: tileShape,
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.tile,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.tile,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.tile,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.xl)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.all(
            Radius.circular(Radii.pill),
          ),
        ),
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        minVerticalPadding: Gap.md,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
