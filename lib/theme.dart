import 'package:flutter/material.dart';

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
/// This extension adds a curated palette of 10 vibrant, accessible colors
/// specifically designed for habit visualization. Each color is chosen to:
/// - Provide excellent contrast against both light and dark backgrounds
/// - Be visually distinct from neighboring colors in the palette
/// - Support accessibility standards for color-blind users
/// - Work well in both light and dark theme variants
///
/// Usage: `Theme.of(context).colorScheme.habitColors[index]`
///
extension HabitColors on ColorScheme {
  /// Curated palette of 10 vibrant colors for habit visualization
  ///
  /// Each color is carefully selected to ensure:
  /// ✅ High contrast ratios for accessibility
  /// ✅ Visual distinction between adjacent colors
  /// ✅ Support for color vision deficiencies
  /// ✅ Consistent appearance in light and dark themes
  ///
  /// Colors are ordered to provide natural visual progression
  /// and can be cycled through when more than 10 habits exist.
  List<Color> get habitColors => [
    const Color(0xFF4CAF50), // Green - Success, growth, nature
    const Color(0xFF2196F3), // Blue - Trust, calm, productivity
    const Color(0xFFFF9800), // Orange - Energy, enthusiasm, creativity
    const Color(0xFFF44336), // Red - Urgency, important habits, health
    const Color(0xFF9C27B0), // Purple - Luxury, mindfulness, spirituality
    const Color(0xFF00BCD4), // Cyan - Freshness, clarity, learning
    const Color(0xFFFFC107), // Yellow - Happiness, optimism, social
    const Color(0xFF795548), // Brown - Stability, grounding, routine
    const Color(0xFFE91E63), // Pink - Love, relationships, self-care
    const Color(0xFF607D8B), // Blue Grey - Balance, professionalism, work
  ];

  /// Get habit color by index with automatic cycling
  ///
  /// Safely retrieves a color from the palette using modulo arithmetic.
  /// This ensures that even if there are more habits than colors,
  /// each habit gets a consistent, visually appealing color.
  ///
  /// @param index The habit's position in the list (0-based)
  /// @return Color from the palette, cycling through available colors
  Color habitColor(int index) {
    return habitColors[index % habitColors.length];
  }
}
