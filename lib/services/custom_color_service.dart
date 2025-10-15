import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing custom habit colors with theme-aware storage
///
/// Handles storage and retrieval of user-defined custom colors for both
/// light and dark themes. Uses SharedPreferences for fast access and
/// implements HSL-based color adjustment for automatic theme variants.
class CustomColorService {
  static const String _lightColorKey = 'custom_color_light';
  static const String _darkColorKey = 'custom_color_dark';
  
  SharedPreferences? _prefs;
  
  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Save custom colors for both light and dark themes
  ///
  /// @param lightColor The color to use in light theme
  /// @param darkColor The color to use in dark theme
  Future<void> saveCustomColor(Color lightColor, Color darkColor) async {
    if (_prefs == null) await initialize();
    
    await _prefs!.setString(_lightColorKey, _colorToHex(lightColor));
    await _prefs!.setString(_darkColorKey, _colorToHex(darkColor));
  }
  
  /// Get custom color for the specified brightness
  ///
  /// @param brightness The theme brightness (light or dark)
  /// @return The custom color for the theme, or null if not set
  Color? getCustomColor(Brightness brightness) {
    if (_prefs == null) return null;
    
    final key = brightness == Brightness.light ? _lightColorKey : _darkColorKey;
    final hexString = _prefs!.getString(key);
    
    if (hexString == null) return null;
    return _hexToColor(hexString);
  }
  
  /// Check if user has set a custom color
  ///
  /// @return true if custom color is available, false otherwise
  bool hasCustomColor() {
    if (_prefs == null) return false;
    
    return _prefs!.getString(_lightColorKey) != null || 
           _prefs!.getString(_darkColorKey) != null;
  }
  
  /// Generate a theme-appropriate variant of a color
  ///
  /// Uses HSL color space to create natural-looking variants:
  /// - Light → Dark: reduce saturation by ~15%, darken by ~10%
  /// - Dark → Light: increase saturation by ~15%, lighten by ~10%
  ///
  /// @param color The base color to adjust
  /// @param targetBrightness The target theme brightness
  /// @return Adjusted color for the target theme
  Color generateThemeVariant(Color color, Brightness targetBrightness) {
    final hsl = HSLColor.fromColor(color);
    
    if (targetBrightness == Brightness.dark) {
      // Light → Dark: reduce saturation, darken
      return hsl
          .withSaturation((hsl.saturation - 0.15).clamp(0.0, 1.0))
          .withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0))
          .toColor();
    } else {
      // Dark → Light: increase saturation, lighten
      return hsl
          .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
          .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
          .toColor();
    }
  }
  
  /// Save a custom color and auto-generate the opposite theme variant
  ///
  /// @param color The color selected by the user
  /// @param currentBrightness The current theme brightness when color was selected
  Future<void> saveCustomColorWithVariant(Color color, Brightness currentBrightness) async {
    final oppositeBrightness = currentBrightness == Brightness.light 
        ? Brightness.dark 
        : Brightness.light;
    
    final variantColor = generateThemeVariant(color, oppositeBrightness);
    
    if (currentBrightness == Brightness.light) {
      await saveCustomColor(color, variantColor);
    } else {
      await saveCustomColor(variantColor, color);
    }
  }
  
  /// Clear custom colors
  Future<void> clearCustomColor() async {
    if (_prefs == null) await initialize();
    
    await _prefs!.remove(_lightColorKey);
    await _prefs!.remove(_darkColorKey);
  }
  
  /// Convert Color to hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }
  
  /// Convert hex string to Color
  Color _hexToColor(String hexString) {
    final hexCode = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
