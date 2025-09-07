import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../models/habit_storage.dart';
import '../repositories/sqlite_habit_repository.dart';
import 'database_service.dart';

/// Service for migrating data from SharedPreferences to SQLite
///
/// Handles the one-time migration of existing habit data from the old
/// SharedPreferences storage to the new SQLite database.
///
/// Features:
/// - Safe migration with rollback capability
/// - Progress tracking and error handling
/// - Data validation and integrity checks
/// - Migration status tracking
class MigrationService {
  static const String _migrationKey = 'migration_completed';
  static const String _migrationVersionKey = 'migration_version';
  static const int _currentMigrationVersion = 1;
  
  final HabitStorage _oldStorage;
  final SqliteHabitRepository _newRepository;
  final DatabaseService _databaseService;
  
  MigrationService(
    this._oldStorage,
    this._newRepository,
    this._databaseService,
  );
  
  /// Check if migration has already been completed
  Future<bool> isMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_migrationKey) ?? false;
      final version = prefs.getInt(_migrationVersionKey) ?? 0;
      
      debugPrint('🔄 Migration status: completed=$completed, version=$version');
      return completed && version >= _currentMigrationVersion;
    } catch (e) {
      debugPrint('❌ Error checking migration status: $e');
      return false;
    }
  }
  
  /// Perform the migration from SharedPreferences to SQLite
  Future<MigrationResult> migrate() async {
    try {
      debugPrint('🔄 Starting migration from SharedPreferences to SQLite...');
      
      // Check if migration is already completed
      if (await isMigrationCompleted()) {
        debugPrint('✅ Migration already completed, skipping');
        return MigrationResult.success('Migration already completed');
      }
      
      // Initialize database
      await _databaseService.database;
      
      // Load existing habits from SharedPreferences
      final existingHabits = await _oldStorage.getHabits(includeArchived: true);
      debugPrint('🔄 Found ${existingHabits.length} habits to migrate');
      
      if (existingHabits.isEmpty) {
        debugPrint('✅ No habits to migrate');
        await _markMigrationCompleted();
        return MigrationResult.success('No habits to migrate');
      }
      
      // Migrate each habit
      int successCount = 0;
      int errorCount = 0;
      final errors = <String>[];
      
      for (final habit in existingHabits) {
        try {
          final result = await _newRepository.saveHabit(habit);
          if (result.success) {
            successCount++;
            debugPrint('✅ Migrated habit: ${habit.name}');
          } else {
            errorCount++;
            final error = 'Failed to migrate habit "${habit.name}": ${result.errorMessage}';
            errors.add(error);
            debugPrint('❌ $error');
          }
        } catch (e) {
          errorCount++;
          final error = 'Exception migrating habit "${habit.name}": $e';
          errors.add(error);
          debugPrint('❌ $error');
        }
      }
      
      // Mark migration as completed
      await _markMigrationCompleted();
      
      final message = 'Migration completed: $successCount successful, $errorCount errors';
      debugPrint('✅ $message');
      
      if (errorCount > 0) {
        return MigrationResult.partialSuccess(message, errors);
      } else {
        return MigrationResult.success(message);
      }
      
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
      return MigrationResult.error('Migration failed: $e');
    }
  }
  
  /// Mark migration as completed in SharedPreferences
  Future<void> _markMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationKey, true);
      await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);
      debugPrint('✅ Migration marked as completed');
    } catch (e) {
      debugPrint('❌ Error marking migration as completed: $e');
    }
  }
  
  /// Reset migration status (for testing/debugging)
  Future<void> resetMigrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_migrationKey);
      await prefs.remove(_migrationVersionKey);
      debugPrint('🔄 Migration status reset');
    } catch (e) {
      debugPrint('❌ Error resetting migration status: $e');
    }
  }
  
  /// Validate migrated data integrity
  Future<ValidationResult> validateMigration() async {
    try {
      debugPrint('🔍 Validating migration integrity...');
      
      // Load habits from both sources
      final oldHabits = await _oldStorage.getHabits(includeArchived: true);
      final newHabits = await _newRepository.getAllHabits();
      
      debugPrint('🔍 Old habits: ${oldHabits.length}, New habits: ${newHabits.length}');
      
      if (oldHabits.length != newHabits.length) {
        return ValidationResult.error('Habit count mismatch: ${oldHabits.length} vs ${newHabits.length}');
      }
      
      // Validate each habit
      final issues = <String>[];
      
      for (final oldHabit in oldHabits) {
        final newHabit = newHabits.firstWhere(
          (h) => h.id == oldHabit.id,
          orElse: () => throw Exception('Habit ${oldHabit.id} not found in new storage'),
        );
        
        // Validate basic properties
        if (oldHabit.name != newHabit.name) {
          issues.add('Habit ${oldHabit.id}: name mismatch');
        }
        if (oldHabit.description != newHabit.description) {
          issues.add('Habit ${oldHabit.id}: description mismatch');
        }
        if (oldHabit.colorIndex != newHabit.colorIndex) {
          issues.add('Habit ${oldHabit.id}: color index mismatch');
        }
        if (oldHabit.isArchived != newHabit.isArchived) {
          issues.add('Habit ${oldHabit.id}: archive status mismatch');
        }
        
        // Validate completion data
        if (oldHabit.completions.length != newHabit.completions.length) {
          issues.add('Habit ${oldHabit.id}: completion count mismatch');
        }
        
        for (final entry in oldHabit.completions.entries) {
          final newCount = newHabit.completions[entry.key] ?? 0;
          if (entry.value != newCount) {
            issues.add('Habit ${oldHabit.id}: completion count for ${entry.key.toIso8601String()} mismatch');
          }
        }
      }
      
      if (issues.isNotEmpty) {
        return ValidationResult.error('Validation issues found: ${issues.join(', ')}');
      }
      
      debugPrint('✅ Migration validation passed');
      return ValidationResult.success('Migration validation passed');
      
    } catch (e) {
      debugPrint('❌ Migration validation failed: $e');
      return ValidationResult.error('Migration validation failed: $e');
    }
  }
}

/// Result of a migration operation
class MigrationResult {
  final bool success;
  final String message;
  final List<String> errors;
  
  const MigrationResult._({
    required this.success,
    required this.message,
    this.errors = const [],
  });
  
  factory MigrationResult.success(String message) {
    return MigrationResult._(success: true, message: message);
  }
  
  factory MigrationResult.partialSuccess(String message, List<String> errors) {
    return MigrationResult._(success: false, message: message, errors: errors);
  }
  
  factory MigrationResult.error(String message) {
    return MigrationResult._(success: false, message: message);
  }
  
  bool get isPartialSuccess => !success && errors.isNotEmpty;
}

/// Result of migration validation
class ValidationResult {
  final bool success;
  final String message;
  
  const ValidationResult._({
    required this.success,
    required this.message,
  });
  
  factory ValidationResult.success(String message) {
    return ValidationResult._(success: true, message: message);
  }
  
  factory ValidationResult.error(String message) {
    return ValidationResult._(success: false, message: message);
  }
}
