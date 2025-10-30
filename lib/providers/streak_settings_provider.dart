import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

/// StreakSettingsProvider - Manages streak calculation preferences
///
/// Handles the configuration for how streaks are calculated:
/// - All Days: Count consecutive days regardless of active days
/// - Active Days Only: Count consecutive active days only
/// 
/// Provides centralized management of this app-wide setting with
/// proper persistence and state management.
class StreakSettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  static const String _settingKey = 'active_days_streak_enabled';

  /// Whether streak calculation should consider only active days
  /// Default: true (Active Days Only)
  bool _isActiveDaysStreakEnabled = true;

  StreakSettingsProvider(this._settingsRepository);

  /// Get the current streak calculation mode
  /// 
  /// Returns true if streaks should be calculated for active days only,
  /// false if streaks should be calculated for all days.
  bool get isActiveDaysStreakEnabled => _isActiveDaysStreakEnabled;

  /// Get the current streak calculation mode as a human-readable string
  String get streakCalculationMode => 
      _isActiveDaysStreakEnabled ? 'Active Days Only' : 'All Days';

  /// Set the streak calculation state without saving to storage
  /// This is used by AppState for optimistic updates
  void setStreakCalculationState(bool isActiveDaysEnabled) {
    if (_isActiveDaysStreakEnabled != isActiveDaysEnabled) {
      _isActiveDaysStreakEnabled = isActiveDaysEnabled;
      notifyListeners();
      debugPrint('🔥 Streak calculation state changed to: $streakCalculationMode');
    }
  }

  /// Set the streak calculation mode and notify listeners
  /// 
  /// @param enabled true for active days only, false for all days
  void setActiveDaysStreakEnabled(bool enabled) {
    if (_isActiveDaysStreakEnabled != enabled) {
      _isActiveDaysStreakEnabled = enabled;
      notifyListeners();
      debugPrint('🔥 Streak calculation mode changed to: $streakCalculationMode');
    }
  }

  /// Toggle the streak calculation mode
  /// 
  /// Switches between "All Days" and "Active Days Only" modes
  Future<void> toggleActiveDaysStreak() async {
    setActiveDaysStreakEnabled(!_isActiveDaysStreakEnabled);
    await _saveSetting();
  }

  /// Load streak calculation setting from storage
  /// 
  /// This will be called during app initialization to restore
  /// the user's preferred streak calculation mode.
  Future<void> loadStreakSetting() async {
    try {
      debugPrint('🔥 Loading streak calculation setting from storage...');
      final settingValue = await _settingsRepository.getSettingWithDefault(
        _settingKey,
        'true', // Default to Active Days Only
      );

      _isActiveDaysStreakEnabled = settingValue.toLowerCase() == 'true';
      debugPrint('🔥 Streak calculation setting loaded: $streakCalculationMode');
    } catch (e) {
      debugPrint('❌ Error loading streak calculation setting: $e');
      // Fallback to default (Active Days Only)
      _isActiveDaysStreakEnabled = true;
    }
  }

  /// Save streak calculation setting to storage
  /// 
  /// This will be called when the setting changes to persist
  /// the user's preference across app restarts.
  Future<void> saveStreakSetting() async {
    try {
      debugPrint('🔥 Saving streak calculation setting to storage...');
      final settingValue = _isActiveDaysStreakEnabled.toString();
      final success = await _settingsRepository.saveSetting(_settingKey, settingValue);

      if (success) {
        debugPrint('🔥 Streak calculation setting saved: $streakCalculationMode');
      } else {
        debugPrint('❌ Failed to save streak calculation setting: $streakCalculationMode');
      }
    } catch (e) {
      debugPrint('❌ Error saving streak calculation setting: $e');
    }
  }

  /// Private method to save setting (used internally)
  Future<void> _saveSetting() async {
    await saveStreakSetting();
  }

  /// Reset to default settings
  /// 
  /// Useful for testing or if user wants to restore defaults
  Future<void> resetToDefaults() async {
    setActiveDaysStreakEnabled(true);
    await _saveSetting();
    debugPrint('🔥 Streak calculation settings reset to defaults');
  }
}
