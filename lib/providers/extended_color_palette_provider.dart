import 'package:flutter/foundation.dart';
import '../repositories/settings_repository.dart';

/// Provider for managing extended color palette setting
///
/// Handles the user preference for showing 24 colors (default) or 36 colors
/// (extended mode) in the color selector. The setting is persisted to the
/// database and provides a clean interface for the UI components.
class ExtendedColorPaletteProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  
  static const String _settingKey = 'extended_color_palette';
  static const bool _defaultValue = false; // Default to 24 colors
  
  bool _isExtendedMode = _defaultValue;
  bool _isLoading = true;
  String? _error;

  ExtendedColorPaletteProvider(this._settingsRepository);

  /// Whether extended color palette (36 colors) is enabled
  bool get isExtendedMode => _isExtendedMode;
  
  /// Whether the provider is currently loading settings
  bool get isLoading => _isLoading;
  
  /// Any error that occurred during loading/saving
  String? get error => _error;

  /// Load the extended color palette setting from storage
  Future<void> loadExtendedColorPaletteSetting() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🎨 ExtendedColorPalette: Loading setting');
      
      final value = await _settingsRepository.getSettingWithDefault(
        _settingKey, 
        _defaultValue.toString(),
      );
      
      _isExtendedMode = value.toLowerCase() == 'true';
      
      debugPrint('🎨 ExtendedColorPalette: Loaded setting: $_isExtendedMode');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ ExtendedColorPalette: Error loading setting: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle the extended color palette setting
  Future<void> toggleExtendedColorPalette() async {
    try {
      _error = null;
      
      final newValue = !_isExtendedMode;
      debugPrint('🎨 ExtendedColorPalette: Toggling to: $newValue');
      
      final success = await _settingsRepository.saveSetting(
        _settingKey, 
        newValue.toString(),
      );
      
      if (success) {
        _isExtendedMode = newValue;
        debugPrint('🎨 ExtendedColorPalette: Setting saved successfully');
      } else {
        _error = 'Failed to save setting';
        debugPrint('❌ ExtendedColorPalette: Failed to save setting');
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ ExtendedColorPalette: Error toggling setting: $e');
      notifyListeners();
    }
  }

  /// Set the extended color palette setting to a specific value
  Future<void> setExtendedColorPalette(bool value) async {
    try {
      _error = null;
      
      debugPrint('🎨 ExtendedColorPalette: Setting to: $value');
      
      final success = await _settingsRepository.saveSetting(
        _settingKey, 
        value.toString(),
      );
      
      if (success) {
        _isExtendedMode = value;
        debugPrint('🎨 ExtendedColorPalette: Setting saved successfully');
      } else {
        _error = 'Failed to save setting';
        debugPrint('❌ ExtendedColorPalette: Failed to save setting');
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ ExtendedColorPalette: Error setting value: $e');
      notifyListeners();
    }
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
