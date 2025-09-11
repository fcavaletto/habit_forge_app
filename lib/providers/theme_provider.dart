import 'package:flutter/material.dart';

/// Theme Provider - Manages app theme state
///
/// Handles theme mode changes and persistence for the Habit Forge app.
/// Provides a centralized way to manage theme state across the application.
class ThemeProvider extends ChangeNotifier {
  /// Current theme mode
  ThemeMode _themeMode = ThemeMode.system;

  /// Get the current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Set the theme mode and notify listeners
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      debugPrint('🎨 Theme changed to: ${_themeMode.name}');
    }
  }

  /// Load theme mode from storage
  /// This will be called during app initialization
  Future<void> loadThemeMode() async {
    // TODO: Load from SQLite database
    // For now, default to system theme
    _themeMode = ThemeMode.system;
    debugPrint('🎨 Theme loaded: ${_themeMode.name}');
  }

  /// Save theme mode to storage
  /// This will be called when theme changes
  Future<void> saveThemeMode() async {
    // TODO: Save to SQLite database
    debugPrint('🎨 Theme saved: ${_themeMode.name}');
  }
}
