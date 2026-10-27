import 'package:flutter/material.dart';

import 'tokens.dart';

/// Musir brand colors, taken from the logo.
const Color musirGreen = Color(0xFF0F6630);
const Color musirRed = Color(0xFFA50F0F);

abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: musirGreen,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD3EBDA),
    onPrimaryContainer: Color(0xFF05260F),
    secondary: Color(0xFF5B5550),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE9E4E1),
    onSecondaryContainer: Color(0xFF2A2623),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFBF9F8),
    onSurface: Color(0xFF1C1A19),
    onSurfaceVariant: Color(0xFF68615C),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F2F0),
    surfaceContainer: Color(0xFFEFEBE8),
    surfaceContainerHigh: Color(0xFFE9E4E1),
    surfaceContainerHighest: Color(0xFFE2DCD8),
    outline: Color(0xFF8F8780),
    outlineVariant: Color(0xFFDDD6D1),
    inverseSurface: Color(0xFF322F2D),
    onInverseSurface: Color(0xFFF6F1EE),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6FCB8D),
    onPrimary: Color(0xFF03210E),
    primaryContainer: Color(0xFF0C4F26),
    onPrimaryContainer: Color(0xFFD3EBDA),
    secondary: Color(0xFFC9C1BB),
    onSecondary: Color(0xFF2A2623),
    secondaryContainer: Color(0xFF3A3633),
    onSecondaryContainer: Color(0xFFEDE8E5),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    surface: Color(0xFF121110),
    onSurface: Color(0xFFEDE8E5),
    onSurfaceVariant: Color(0xFFABA39D),
    surfaceContainerLowest: Color(0xFF0C0B0A),
    surfaceContainerLow: Color(0xFF1A1817),
    surfaceContainer: Color(0xFF211F1D),
    surfaceContainerHigh: Color(0xFF292624),
    surfaceContainerHighest: Color(0xFF332F2C),
    outline: Color(0xFF7D766F),
    outlineVariant: Color(0xFF3A3633),
    inverseSurface: Color(0xFFEDE8E5),
    onInverseSurface: Color(0xFF322F2D),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final text = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: scheme.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Corners.mdAll),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.lg)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: scheme.outlineVariant,
        indicatorColor: scheme.primary,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.labelLarge,
      ),
    );
  }
}
