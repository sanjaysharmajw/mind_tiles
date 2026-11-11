import 'package:flutter/material.dart';

/// Game palette: a deep night-purple world that makes the yellow tiles pop.
class AppColors {
  const AppColors._();

  static const night = Color(0xFF1C1040);
  static const purple = Color(0xFF34196F);
  static const violet = Color(0xFF5530A8);
  static const lilac = Color(0xFFB9A6FF);

  static const yellow = Color(0xFFFFCD29);
  static const yellowLight = Color(0xFFFFE27A);
  static const yellowDark = Color(0xFFCF8E00);

  static const teal = Color(0xFF22C7A9);
  static const tealDark = Color(0xFF0F8A73);
  static const sky = Color(0xFF4CB8FF);
  static const skyDark = Color(0xFF1C78C2);
  static const coral = Color(0xFFFF5D73);
  static const coralDark = Color(0xFFC72D47);
  static const orange = Color(0xFFFF8A3D);
  static const orangeDark = Color(0xFFC85A12);
  static const grey = Color(0xFF8E88A8);
  static const greyDark = Color(0xFF5E5878);

  static const panel = Color(0xFFFFF8E6);
  static const panelBorder = Color(0xFFFFE3A3);
  static const ink = Color(0xFF2A1A4A);
  static const inkSoft = Color(0xFF6B5C8C);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
}

class AppTheme {
  const AppTheme._();

  static const String displayFont = 'LilitaOne';

  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double? height,
  }) => TextStyle(
    fontFamily: displayFont,
    // Glyphs Lilita One lacks (e.g. ∞) come from bundled Roboto, never from
    // a network font fallback (required for YouTube Playables).
    fontFamilyFallback: const ['Roboto'],
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: 0.5,
  );

  /// [bundledFontsOnly]: use the bundled Roboto for all UI text instead of
  /// the platform default (on Apple web browsers Flutter would otherwise ask
  /// for the system font and download fallbacks — blocked in Playables).
  static ThemeData build({bool bundledFontsOnly = false}) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: bundledFontsOnly ? 'Roboto' : null,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        brightness: Brightness.dark,
        primary: AppColors.yellow,
        secondary: AppColors.teal,
        surface: AppColors.purple,
      ),
      scaffoldBackgroundColor: AppColors.night,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : AppColors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.panelBorder,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
