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

  // Cache fully-built ThemeData objects so we never reconstruct them
  // during a theme toggle. Each unique combination gets its own cached entry.
  static ThemeData? _cachedLight;
  static ThemeData? _cachedDark;
  static ThemeData? _cachedDarkOled;
  static ColorScheme? _cachedLightScheme;
  static ColorScheme? _cachedDarkScheme;
  static bool _cachedOled = false;

  /// Returns a cached ThemeData, rebuilding only when the ColorScheme or
  /// OLED flag actually changes.
  static ThemeData buildTheme(
    ColorScheme colorScheme, {
    required bool isDark,
    bool useOled = false,
  }) {
    if (!isDark) {
      if (_cachedLight != null && _cachedLightScheme == colorScheme) {
        return _cachedLight!;
      }
      _cachedLightScheme = colorScheme;
      _cachedLight = _buildThemeData(colorScheme, isDark: false);
      return _cachedLight!;
    } else {
      if (useOled) {
        if (_cachedDarkOled != null &&
            _cachedDarkScheme == colorScheme &&
            _cachedOled == useOled) {
          return _cachedDarkOled!;
        }
      } else {
        if (_cachedDark != null &&
            _cachedDarkScheme == colorScheme &&
            _cachedOled == useOled) {
          return _cachedDark!;
        }
      }
      _cachedDarkScheme = colorScheme;
      _cachedOled = useOled;
      final scheme = useOled
          ? colorScheme.copyWith(surface: Colors.black)
          : colorScheme;
      if (useOled) {
        _cachedDarkOled = _buildThemeData(scheme, isDark: true);
        return _cachedDarkOled!;
      } else {
        _cachedDark = _buildThemeData(scheme, isDark: true);
        return _cachedDark!;
      }
    }
  }

  static ThemeData _buildThemeData(
    ColorScheme colorScheme, {
    required bool isDark,
  }) {
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
      scaffoldBackgroundColor: Colors.transparent,
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
