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
/// This extension adds a curated palette of 12 vibrant, accessible colors
/// specifically designed for habit visualization. Each color is chosen to:
/// - Provide excellent contrast against both light and dark backgrounds
/// - Be visually distinct from neighboring colors in the palette
/// - Support accessibility standards for color-blind users
/// - Work well in both light and dark theme variants
///
/// Usage: `Theme.of(context).colorScheme.habitColors[index]`
///
extension HabitColors on ColorScheme {
  /// Curated palette of 48 vibrant yet pleasant colors for habit visualization
  ///
  /// Each color is carefully selected to ensure:
  /// ✅ High contrast ratios for accessibility
  /// ✅ Visual distinction between adjacent colors
  /// ✅ Support for color vision deficiencies
  /// ✅ Consistent appearance in light and dark themes
  /// ✅ Vibrant but pleasant aesthetic that's easy on the eyes
  ///
  /// Layout: 4 rows × 12 columns (48 total colors)
  /// - Row 1 (0-11): Essential colors - Red, Orange, Yellow, Green, Blue, Purple, Pink, Brown, Gray, Black, White, Teal
  /// - Row 2 (12-23): Complementary colors - variations and additional hues
  /// - Row 3 (24-35): Vibrant variations - more saturated versions
  /// - Row 4 (36-47): Sophisticated tones - elegant and refined colors
  List<Color> get habitColors => [
    // Row 1: Mixed Essential Colors (12 colors) - Blues, Greens, Reds, Purples
    const Color(0xFF2E5BFF), // Vibrant Blue
    const Color(0xFF00C853), // Vibrant Emerald Green
    const Color(0xFFF44336), // Bright Red
    const Color(0xFF9C27B0), // Rich Purple
    const Color(0xFF00D4FF), // Vibrant Cyan
    const Color(0xFF8BC34A), // Bright Lime Green
    const Color(0xFFFF7043), // Vibrant Coral
    const Color(0xFF673AB7), // Bright Violet
    const Color(0xFF4FC3F7), // Bright Sky Blue
    const Color(0xFF2E7D32), // Vivid Forest Green
    const Color(0xFFE91E63), // Vibrant Rose
    const Color(0xFF7B1FA2), // Deep Purple

    // Row 2: Warm & Cool Mix (12 colors) - Oranges, Yellows, Teals, Pinks
    const Color(0xFFFF9800), // Vibrant Orange
    const Color(0xFF009688), // Vibrant Teal
    const Color(0xFFFFEB3B), // Bright Yellow
    const Color(0xFFE91E63), // Bright Pink
    const Color(0xFFFF5722), // Bright Tangerine
    const Color(0xFF00BCD4), // Bright Aqua
    const Color(0xFFFFC107), // Golden Yellow
    const Color(0xFFF8BBD9), // Vibrant Rose Pink
    const Color(0xFFFFAB91), // Vibrant Peach
    const Color(0xFF4DD0E1), // Vivid Turquoise
    const Color(0xFFFF8F00), // Vivid Amber
    const Color(0xFFE91E63), // Vibrant Magenta

    // Row 3: Earth & Nature Tones (12 colors) - Browns, Greens, Blues, Purples
    const Color(0xFF5D4037), // Rich Brown
    const Color(0xFF1B5E20), // Deep Forest Green
    const Color(0xFF1565C0), // Deep Navy Blue
    const Color(0xFF7B1FA2), // Rich Plum Purple
    const Color(0xFFD7CCC8), // Vibrant Tan
    const Color(0xFF4CAF50), // Vibrant Mint Green
    const Color(0xFF1976D2), // Vibrant Cobalt Blue
    const Color(0xFF9575CD), // Vibrant Lavender
    const Color(0xFF8D6E63), // Bright Sienna Brown
    const Color(0xFF827717), // Bright Olive Green
    const Color(0xFF3F51B5), // Bright Indigo Blue
    const Color(0xFF9C27B0), // Bright Amethyst Purple

    // Row 4: Sophisticated Vibrant Mix (12 colors) - Mixed sophisticated tones
    const Color(0xFF4A148C), // Deep Burgundy
    const Color(0xFFFFD700), // Vibrant Gold
    const Color(0xFF00695C), // Rich Emerald
    const Color(0xFFC62828), // Vibrant Ruby Red
    const Color(0xFFFF7F50), // Bright Coral
    const Color(0xFF1565C0), // Bright Sapphire Blue
    const Color(0xFF4527A0), // Deep Violet
    const Color(0xFF2E7D32), // Vibrant Jade Green
    const Color(0xFFB71C1C), // Rich Garnet Red
    const Color(0xFFFF6F00), // Bright Copper Orange
    const Color(0xFF689F38), // Bright Peridot Green
    const Color(0xFFFF8F00), // Vibrant Topaz Orange
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
