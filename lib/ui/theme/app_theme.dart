import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // A vibrant "Google Blue" or "Snap Indigo" seed
  static const seedColor = Color(0xFF4285F4);

  // Cache TextThemes statically — GoogleFonts parses font data which is slow;
  // doing this once at app load prevents stutter during theme switches.
  static final _lightTextTheme = GoogleFonts.outfitTextTheme(
    ThemeData.light().textTheme,
  );
  static final _darkTextTheme = GoogleFonts.outfitTextTheme(
    ThemeData.dark().textTheme,
  );

  // Helper to build ThemeData dynamically
  static ThemeData buildTheme(
    ColorScheme colorScheme, {
    required bool isDark,
    bool useOled = false,
  }) {
    // If OLED is enabled and it's dark mode, force the surface and background to pure black
    if (isDark && useOled) {
      colorScheme = colorScheme.copyWith(
        surface: Colors.black,
        // In Material 3 `background` is deprecated in favor of `surface`, but we'll set both if needed
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      textTheme: isDark ? _darkTextTheme : _lightTextTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      cardTheme: isDark ? _cardThemeDark : _cardThemeLight,
      scaffoldBackgroundColor:
          Colors.transparent, // Allow transparency to flow through
      inputDecorationTheme: isDark
          ? _darkInputDecorationTheme
          : _lightInputDecorationTheme,
    );
  }

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
  );

  static final _cardThemeLight = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1),
    ),
    clipBehavior: Clip.antiAlias,
  );

  static final _cardThemeDark = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
    ),
    clipBehavior: Clip.antiAlias,
  );

  static final _lightInputDecorationTheme = InputDecorationTheme(
    filled: true,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: seedColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  );

  static final _darkInputDecorationTheme = InputDecorationTheme(
    filled: true,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: seedColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  );
}
