import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

/// Pro Subscription Provider - Manages PRO subscription state
///
/// Handles the PRO subscription feature toggle that controls access to
/// premium features like advanced stats, analytics, and enhanced functionality.
/// Provides a centralized way to manage this subscription state.
class ProSubscriptionProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  static const String _settingKey = 'pro_subscription';

  /// Whether PRO subscription is active
  bool _isProSubscriptionActive = true; // Default to active

  ProSubscriptionProvider(this._settingsRepository);

  /// Get the current PRO subscription status
  bool get isProSubscriptionActive => _isProSubscriptionActive;

  /// Set the PRO subscription status and notify listeners
  void setProSubscriptionActive(bool isActive) {
    if (_isProSubscriptionActive != isActive) {
      _isProSubscriptionActive = isActive;
      notifyListeners();
      debugPrint('💎 PRO subscription status changed to: $isActive');
    }
  }

  /// Load PRO subscription setting from storage
  /// This will be called during app initialization
  Future<void> loadProSubscriptionSetting() async {
    try {
      debugPrint('💎 Loading PRO subscription setting from storage...');
      final settingValue = await _settingsRepository.getSettingWithDefault(
        _settingKey,
        'true', // Default to active
      );

      _isProSubscriptionActive = settingValue.toLowerCase() == 'true';
      debugPrint('💎 PRO subscription setting loaded: $_isProSubscriptionActive');
    } catch (e) {
      debugPrint('❌ Error loading PRO subscription setting: $e');
      // Fallback to default (active)
      _isProSubscriptionActive = true;
    }
  }

  /// Save PRO subscription setting to storage
  /// This will be called when the setting changes
  Future<void> saveProSubscriptionSetting() async {
    try {
      debugPrint('💎 Saving PRO subscription setting to storage...');
      final settingValue = _isProSubscriptionActive.toString();
      final success = await _settingsRepository.saveSetting(_settingKey, settingValue);

      if (success) {
        debugPrint('💎 PRO subscription setting saved: $_isProSubscriptionActive');
      } else {
        debugPrint('❌ Failed to save PRO subscription setting: $_isProSubscriptionActive');
      }
    } catch (e) {
      debugPrint('❌ Error saving PRO subscription setting: $e');
    }
  }

  /// Toggle the PRO subscription status
  Future<void> toggleProSubscription() async {
    setProSubscriptionActive(!_isProSubscriptionActive);
    await saveProSubscriptionSetting();
  }
}
