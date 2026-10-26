import 'package:flutter/material.dart';

/// Semantic colors used for live recitation feedback.
class AppColors {
  AppColors._();

  static const Color correct = Color(0xFF2E7D32);
  static const Color correctSoft = Color(0x332E7D32);
  static const Color warning = Color(0xFFE08A00);
  static const Color warningSoft = Color(0x33E08A00);
  static const Color error = Color(0xFFC62828);
  static const Color errorSoft = Color(0x33C62828);
}

/// Calm Islamic theme: emerald green + soft gold on warm cream (light)
/// or deep green-black (dark).
class AppTheme {
  AppTheme._();

  static const Color _emerald = Color(0xFF1F6F5C);
  static const Color _gold = Color(0xFFC9A24D);
  static const Color _lightBackground = Color(0xFFF7F3E8);
  static const Color _darkBackground = Color(0xFF0F1A17);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme baseScheme = ColorScheme.fromSeed(
      seedColor: _emerald,
      brightness: brightness,
      secondary: _gold,
    );

    final ColorScheme scheme = baseScheme.copyWith(
      surface: isDark ? _darkBackground : _lightBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
