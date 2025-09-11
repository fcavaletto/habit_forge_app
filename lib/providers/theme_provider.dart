import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

/// Theme Provider - Manages app theme state
///
/// Handles theme mode changes and persistence for the Habit Forge app.
/// Provides a centralized way to manage theme state across the application.
class ThemeProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  
  /// Current theme mode
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider(this._settingsRepository);

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
    try {
      debugPrint('🎨 Loading theme from storage...');
      final themeValue = await _settingsRepository.getSettingWithDefault(
        'theme_mode',
        'system', // Default to system theme
      );
      
      // Convert string to ThemeMode
      switch (themeValue) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      
      debugPrint('🎨 Theme loaded: ${_themeMode.name}');
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
      // Fallback to system theme on error
      _themeMode = ThemeMode.system;
    }
  }

  /// Save theme mode to storage
  /// This will be called when theme changes
  Future<void> saveThemeMode() async {
    try {
      debugPrint('🎨 Saving theme to storage...');
      final themeValue = _themeMode.name;
      final success = await _settingsRepository.saveSetting('theme_mode', themeValue);
      
      if (success) {
        debugPrint('🎨 Theme saved: ${_themeMode.name}');
      } else {
        debugPrint('❌ Failed to save theme: ${_themeMode.name}');
      }
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');
    }
  }
}
