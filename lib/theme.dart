import 'package:flutter/material.dart';

/// Represents a color pair with light and dark theme variants
class HabitColorPair {
  final Color light;
  final Color dark;
  
  const HabitColorPair({
    required this.light,
    required this.dark,
  });
  
  /// Get the appropriate color based on brightness
  Color getColor(Brightness brightness) {
    return brightness == Brightness.light ? light : dark;
  }
}

/// Comprehensive theme configuration for Habit Forge
///
/// This file defines the complete visual identity of the application including:
/// - Material 3 design system implementation
/// - Light and dark theme variants
/// - Custom color palette for habit visualization
/// - Typography and component theming
/// - Consistent spacing and layout guidelines
///
/// The theme system supports:
/// ✅ Dynamic theme switching (light/dark/system)
/// ✅ 10 predefined vibrant habit colors
/// ✅ Material 3 components with custom styling
/// ✅ Accessibility-compliant color contrasts
/// ✅ Consistent visual hierarchy across all screens

/// Habit tracking app theme configuration using Material 3 design
///
/// Provides two complete theme variants (light and dark) with consistent
/// color schemes, typography, and component styling. The themes are
/// designed to provide optimal readability and visual hierarchy for
/// habit tracking workflows.
class AppTheme {
  /// Light theme color scheme optimized for daytime usage
  ///
  /// Features high contrast ratios for accessibility and uses
  /// Material 3's dynamic color principles with custom accent colors.
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2196F3), // Blue
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3F2FD),
    onPrimaryContainer: Color(0xFF1565C0),
    secondary: Color(0xFF4CAF50), // Green
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8F5E8),
    onSecondaryContainer: Color(0xFF2E7D32),
    tertiary: Color(0xFFFF9800), // Orange
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFF3E0),
    onTertiaryContainer: Color(0xFFE65100),
    error: Color(0xFFF44336),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFEBEE),
    onErrorContainer: Color(0xFFC62828),
    surface: Color(0xFFFFFFFF), // White background for cards
    onSurface: Color(0xFF212121),
    surfaceContainerHighest: Color(0xFFF5F5F5), // Light gray background
    onSurfaceVariant: Color(0xFF757575),
    outline: Color(0xFFBDBDBD),
    outlineVariant: Color(0xFFE0E0E0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF303030),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF90CAF9),
    surfaceTint: Color(0xFF2196F3),
  );

  /// Dark theme color scheme optimized for nighttime/low-light usage
  ///
  /// Uses darker backgrounds with carefully chosen accent colors to reduce
  /// eye strain while maintaining excellent readability and visual hierarchy.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF90CAF9),
    onPrimary: Color(0xFF0D47A1),
    primaryContainer: Color(0xFF1565C0),
    onPrimaryContainer: Color(0xFFE3F2FD),
    secondary: Color(0xFF81C784),
    onSecondary: Color(0xFF1B5E20),
    secondaryContainer: Color(0xFF2E7D32),
    onSecondaryContainer: Color(0xFFE8F5E8),
    tertiary: Color(0xFFFFB74D),
    onTertiary: Color(0xFFE65100),
    tertiaryContainer: Color(0xFFFF9800),
    onTertiaryContainer: Color(0xFFFFF3E0),
    error: Color(0xFFEF5350),
    onError: Color(0xFF000000),
    errorContainer: Color(0xFFD32F2F),
    onErrorContainer: Color(0xFFFFEBEE),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFF1E1E1E),
    onSurfaceVariant: Color(0xFFBDBDBD),
    outline: Color(0xFF8D8D8D),
    outlineVariant: Color(0xFF404040),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE0E0E0),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFF1565C0),
    surfaceTint: Color(0xFF90CAF9),
  );

  // Light theme data
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    fontFamily: 'Roboto', // Roboto sans-serif as requested

    // App bar styling
    appBarTheme: AppBarTheme(
      backgroundColor: lightColorScheme.surface,
      foregroundColor: lightColorScheme.onSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    // Card styling
    cardTheme: CardThemeData(
      color: lightColorScheme.surface,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: lightColorScheme.outlineVariant,
          width: 1,
        ),
      ),
    ),

    // Button styling
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    // Text styling
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: lightColorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: lightColorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: lightColorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: lightColorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: lightColorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: lightColorScheme.onSurfaceVariant,
      ),
    ),

    // Scaffold background
    scaffoldBackgroundColor: lightColorScheme.surfaceContainerHighest,
  );

  // Dark theme data
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    fontFamily: 'Roboto',

    appBarTheme: AppBarTheme(
      backgroundColor: darkColorScheme.surface,
      foregroundColor: darkColorScheme.onSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: darkColorScheme.surface,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: darkColorScheme.outlineVariant,
          width: 1,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: darkColorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: darkColorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: darkColorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: darkColorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: darkColorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: darkColorScheme.onSurfaceVariant,
      ),
    ),

    scaffoldBackgroundColor: darkColorScheme.surfaceContainerHighest,
  );
}

/// Extension to ColorScheme that provides predefined habit colors
///
/// This extension adds a curated palette of 20 vibrant, accessible colors
/// specifically designed for habit visualization. Each color has both light
/// and dark theme variants to ensure optimal visibility and contrast.
///
/// Usage: `Theme.of(context).colorScheme.getHabitColor(index, brightness)`
///
extension HabitColors on ColorScheme {
  /// Curated palette of 20 vibrant yet pleasant color pairs for habit visualization
  ///
  /// Layout: 3 rows × 7 columns (20 predefined colors + 1 custom color)
  /// - Index 20: Custom color (user-defined)
  static const List<HabitColorPair> _habitColorPairs = [
    // Row 1: Essential Colors (0-6)
    HabitColorPair(light: Color(0xffe44344), dark: Color(0xFF334155)),
    HabitColorPair(light: Color(0xffee6f1a), dark: Color(0xFF374151)),
    HabitColorPair(light: Color(0xffe99813), dark: Color(0xFF404040)),
    HabitColorPair(light: Color(0xffdfad11), dark: Color(0xFFb91c1c)),
    HabitColorPair(light: Color(0xff81c31a), dark: Color(0xFFc2410c)),
    HabitColorPair(light: Color(0xff24bd5b), dark: Color(0xFFb45309)),
    HabitColorPair(light: Color(0xff15b27e), dark: Color(0xFFa16207)),
    // Row 2: Secondary Colors (7-13)
    HabitColorPair(light: Color(0xff1ab1a1), dark: Color(0xFF4d7c0f)),
    HabitColorPair(light: Color(0xff0fafcd), dark: Color(0xFF15803d)),
    HabitColorPair(light: Color(0xff159fe0), dark: Color(0xFF047857)),
    HabitColorPair(light: Color(0xff3a7eec), dark: Color(0xFF0f766e)),
    HabitColorPair(light: Color(0xff6063e8), dark: Color(0xFF0e7490)),
    HabitColorPair(light: Color(0xff8759eb), dark: Color(0xFF0369a1)),
    HabitColorPair(light: Color(0xffa052ef), dark: Color(0xFF1d4ed8)),
    // Row 3: Tertiary Colors (14-19)
    HabitColorPair(light: Color(0xffd045e5), dark: Color(0xFF4338ca)),
    HabitColorPair(light: Color(0xffe14794), dark: Color(0xFF6d28d9)),
    HabitColorPair(light: Color(0xffeb3f5c), dark: Color(0xFF7e22ce)),
    HabitColorPair(light: Color(0xff637187), dark: Color(0xFFa21caf)),
    HabitColorPair(light: Color(0xff737373), dark: Color(0xFFbe185d)),
    HabitColorPair(light: Color(0xff756e69), dark: Color(0xFFbe123c)), 
  ];

  /// Convert integer color value to Color object
  ///
  /// Helper method to convert stored color values back to Color objects.
  /// This is used when reading color values from the database.
  ///
  /// @param value The integer color value (e.g., 0xFF2196F3)
  /// @return Color object
  static Color colorFromValue(int value) {
    return Color(value);
  }

  /// Get habit color by index with theme awareness
  ///
  /// Retrieves the appropriate color variant based on the current theme brightness.
  /// For index 20, returns a placeholder color (custom colors are handled separately).
  ///
  /// @param index The habit's color index (0-20)
  /// @param brightness The current theme brightness
  /// @return Color from the palette, cycling through available colors
  Color getHabitColor(int index, Brightness brightness) {
    if (index >= 0 && index < _habitColorPairs.length) {
      return _habitColorPairs[index].getColor(brightness);
    }
    // Fallback for custom color (index 20) or invalid indices
    return _habitColorPairs[0].getColor(brightness);
  }

  /// Get habit color by index using current theme brightness
  ///
  /// Convenience method that uses the current ColorScheme's brightness.
  /// This is the main method used throughout the app.
  ///
  /// @param index The habit's color index (0-20)
  /// @return Color from the palette based on current theme
  Color habitColor(int index) {
    return getHabitColor(index, brightness);
  }

  /// Get all habit color pairs for the color selector
  ///
  /// Returns the list of predefined color pairs for UI components
  /// that need to display the full palette.
  List<HabitColorPair> get habitColorPairs => _habitColorPairs;
}
