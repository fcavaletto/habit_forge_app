import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

/// Repository for managing app settings persistence
///
/// Handles storage and retrieval of app settings like theme preferences
/// using SQLite database. Provides a clean interface for settings management.
class SettingsRepository {
  final DatabaseService _databaseService;

  SettingsRepository(this._databaseService);

  /// Save a setting value to the database
  Future<bool> saveSetting(String key, String value) async {
    try {
      debugPrint('💾 Settings: Saving setting $key = $value');
      final db = await _databaseService.database;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final result = await db.insert(
        'app_settings',
        {
          'key': key,
          'value': value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      final success = result > 0;
      debugPrint('💾 Settings: Setting $key saved: $success');
      return success;
    } catch (e) {
      debugPrint('❌ Settings: Error saving setting $key: $e');
      return false;
    }
  }

  /// Get a setting value from the database
  Future<String?> getSetting(String key) async {
    try {
      debugPrint('📖 Settings: Getting setting $key');
      final db = await _databaseService.database;
      
      final results = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        final value = results.first['value'] as String;
        debugPrint('📖 Settings: Found setting $key = $value');
        return value;
      } else {
        debugPrint('📖 Settings: Setting $key not found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Settings: Error getting setting $key: $e');
      return null;
    }
  }

  /// Get a setting value with a default fallback
  Future<String> getSettingWithDefault(String key, String defaultValue) async {
    final value = await getSetting(key);
    return value ?? defaultValue;
  }

  /// Delete a setting from the database
  Future<bool> deleteSetting(String key) async {
    try {
      debugPrint('🗑️ Settings: Deleting setting $key');
      final db = await _databaseService.database;
      
      final result = await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      
      final success = result > 0;
      debugPrint('🗑️ Settings: Setting $key deleted: $success');
      return success;
    } catch (e) {
      debugPrint('❌ Settings: Error deleting setting $key: $e');
      return false;
    }
  }

  /// Get all settings as a map
  Future<Map<String, String>> getAllSettings() async {
    try {
      debugPrint('📖 Settings: Getting all settings');
      final db = await _databaseService.database;
      
      final results = await db.query('app_settings');
      
      final settings = <String, String>{};
      for (final row in results) {
        final key = row['key'] as String;
        final value = row['value'] as String;
        settings[key] = value;
      }
      
      debugPrint('📖 Settings: Retrieved ${settings.length} settings');
      return settings;
    } catch (e) {
      debugPrint('❌ Settings: Error getting all settings: $e');
      return {};
    }
  }

  /// Save boolean setting for time override visibility
  Future<bool> saveShowTimeOverride(bool show) async {
    return await saveSetting('show_time_override', show.toString());
  }

  /// Get boolean setting for time override visibility
  Future<bool> getShowTimeOverride() async {
    final value = await getSettingWithDefault('show_time_override', 'false');
    return value.toLowerCase() == 'true';
  }

  /// Save week start day preference
  /// @param isMonday If true, week starts on Monday; if false, on Sunday
  Future<bool> saveWeekStartDay(bool isMonday) async {
    return await saveSetting('week_starts_on_monday', isMonday.toString());
  }

  /// Get week start day preference
  /// @return true if week starts on Monday (default), false if Sunday
  Future<bool> getWeekStartDay() async {
    final value = await getSettingWithDefault('week_starts_on_monday', 'true');
    return value.toLowerCase() == 'true';
  }

  /// Save collapsed state for a specific habit card
  /// @param habitId The habit ID
  /// @param isCollapsed Whether the card is collapsed
  Future<bool> saveHabitCardCollapsed(String habitId, bool isCollapsed) async {
    final key = 'habit_card_collapsed_$habitId';
    return await saveSetting(key, isCollapsed.toString());
  }

  /// Get collapsed state for a specific habit card
  /// @param habitId The habit ID
  /// @return true if collapsed, false if expanded (default: true - collapsed)
  Future<bool> getHabitCardCollapsed(String habitId) async {
    final key = 'habit_card_collapsed_$habitId';
    final value = await getSettingWithDefault(key, 'true');
    return value.toLowerCase() == 'true';
  }
}
