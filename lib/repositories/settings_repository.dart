import 'package:flutter/foundation.dart';
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
}
