import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

/// Completion Count Provider - Manages completion count visibility setting
///
/// Handles the visibility of completion count text (e.g., "X of Y habits completed")
/// on the dashboard. Provides a centralized way to manage this UI preference.
class CompletionCountProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  static const String _settingKey = 'show_completion_count';

  /// Whether to show completion count text
  bool _showCompletionCount = false; // Default to hidden

  CompletionCountProvider(this._settingsRepository);

  /// Get the current completion count visibility setting
  bool get showCompletionCount => _showCompletionCount;

  /// Set the completion count visibility and notify listeners
  void setShowCompletionCount(bool show) {
    if (_showCompletionCount != show) {
      _showCompletionCount = show;
      notifyListeners();
      debugPrint('📊 Completion count visibility changed to: $show');
    }
  }

  /// Load completion count setting from storage
  /// This will be called during app initialization
  Future<void> loadCompletionCountSetting() async {
    try {
      debugPrint('📊 Loading completion count setting from storage...');
      final settingValue = await _settingsRepository.getSettingWithDefault(
        _settingKey,
        'false', // Default to hidden
      );

      _showCompletionCount = settingValue.toLowerCase() == 'true';
      debugPrint('📊 Completion count setting loaded: $_showCompletionCount');
    } catch (e) {
      debugPrint('❌ Error loading completion count setting: $e');
      // Fallback to default (hidden)
      _showCompletionCount = false;
    }
  }

  /// Save completion count setting to storage
  /// This will be called when the setting changes
  Future<void> saveCompletionCountSetting() async {
    try {
      debugPrint('📊 Saving completion count setting to storage...');
      final settingValue = _showCompletionCount.toString();
      final success = await _settingsRepository.saveSetting(_settingKey, settingValue);

      if (success) {
        debugPrint('📊 Completion count setting saved: $_showCompletionCount');
      } else {
        debugPrint('❌ Failed to save completion count setting: $_showCompletionCount');
      }
    } catch (e) {
      debugPrint('❌ Error saving completion count setting: $e');
    }
  }

  /// Toggle the completion count visibility
  Future<void> toggleCompletionCount() async {
    setShowCompletionCount(!_showCompletionCount);
    await saveCompletionCountSetting();
  }
}
