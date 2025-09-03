import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'habit.dart';

/// Result of a habit save operation
class HabitSaveResult {
  final bool success;
  final String? errorMessage;
  final Habit? savedHabit;

  const HabitSaveResult._({
    required this.success,
    this.errorMessage,
    this.savedHabit,
  });

  /// Successfully saved the habit
  factory HabitSaveResult.success(Habit habit) {
    return HabitSaveResult._(success: true, savedHabit: habit);
  }

  /// Failed to save due to duplicate habit
  factory HabitSaveResult.duplicate(String existingHabitName) {
    return HabitSaveResult._(
      success: false,
      errorMessage: 'A habit with the name "$existingHabitName" and the same icon already exists',
    );
  }

  /// Failed to save due to other error
  factory HabitSaveResult.error(String message) {
    return HabitSaveResult._(success: false, errorMessage: message);
  }
}

/// Service class for habit data persistence and retrieval
///
/// Handles all data storage operations using SharedPreferences for local persistence.
/// Provides methods for:
/// - Loading and saving individual habits
/// - Bulk operations for multiple habits
/// - Updating completion status
/// - Data migration and error handling
///
/// Uses JSON serialization for complex data structures and implements
/// robust error handling to prevent data corruption.
class HabitStorage {
  /// Storage key for habits list in SharedPreferences
  static const String _habitsKey = 'habits';

  /// Retrieve all stored habits from persistent storage
  ///
  /// Loads habit data from SharedPreferences, deserializes JSON strings
  /// back into Habit objects, and returns them as a list.
  ///
  /// Implements robust error handling - if any individual habit fails to
  /// deserialize (due to corruption or format changes), it logs the error
  /// and skips that habit rather than failing the entire operation.
  ///
  /// @param includeArchived Whether to include archived habits in the result
  /// @return List of successfully loaded Habit objects
  Future<List<Habit>> getHabits({bool includeArchived = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = prefs.getStringList(_habitsKey) ?? []; // Default to empty list

    final habits = habitsJson.map((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return Habit.fromJson(map); // Deserialize each habit
      } catch (e) {
        debugPrint('Error parsing habit JSON: $e');
        return null; // Skip corrupted habits
      }
    }).whereType<Habit>().toList(); // Filter out null values from failed parsing

    // Filter out archived habits unless specifically requested
    return includeArchived ? habits : habits.where((habit) => habit.isActive).toList();
  }

  /// Save a new habit to storage
  ///
  /// Creates a new habit in storage. Fails with a duplicate error if a habit
  /// with the same name and icon combination already exists (since this generates
  /// the same deterministic ID).
  ///
  /// Note: This method is designed for creating new habits. For updating existing
  /// habits, use the specific update methods like updateHabitCompletion, archiveHabit, etc.
  ///
  /// @param habit The new habit to save
  /// @return HabitSaveResult indicating success or failure with details
  Future<HabitSaveResult> saveHabit(Habit habit) async {
    try {
      final habits = await getHabits();

      // Check for duplicates using deterministic ID matching
      // With deterministic IDs, same name+icon = same ID
      final existingIndex = habits.indexWhere((h) => h.id == habit.id);

      if (existingIndex >= 0) {
        // Habit with same ID exists - this is a duplicate since we're using
        // deterministic IDs based on name+icon combination
        final existingHabit = habits[existingIndex];
        return HabitSaveResult.duplicate(existingHabit.name);
      } else {
        habits.add(habit); // Add new habit
      }

      await _saveHabits(habits); // Persist changes
      return HabitSaveResult.success(habit);
    } catch (e) {
      debugPrint('Error saving habit: $e');
      return HabitSaveResult.error('Failed to save habit: $e');
    }
  }

  /// Permanently delete a habit from storage
  ///
  /// Removes the habit with the specified ID from persistent storage.
  /// This operation cannot be undone and permanently deletes all
  /// completion history for the habit.
  ///
  /// @param habitId Unique identifier of the habit to delete
  Future<void> deleteHabit(String habitId) async {
    final habits = await getHabits(includeArchived: true); // Include archived for deletion
    habits.removeWhere((habit) => habit.id == habitId); // Remove matching habit
    await _saveHabits(habits); // Persist changes
  }

  /// Archive a habit (hide from main view but keep data)
  ///
  /// Marks the habit as archived so it doesn't appear in the main habit list
  /// but keeps all completion data intact. Archived habits can be unarchived later.
  ///
  /// @param habitId Unique identifier of the habit to archive
  /// @return true if successful, false otherwise
  Future<bool> archiveHabit(String habitId) async {
    try {
      final habits = await getHabits(includeArchived: true);
      final habitIndex = habits.indexWhere((habit) => habit.id == habitId);

      if (habitIndex >= 0) {
        final updatedHabit = habits[habitIndex].copyWith(isArchived: true);
        habits[habitIndex] = updatedHabit;
        await _saveHabits(habits);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error archiving habit: $e');
      return false;
    }
  }

  /// Unarchive a habit (restore to main view)
  ///
  /// Removes the archived status from a habit so it appears in the main habit list again.
  ///
  /// @param habitId Unique identifier of the habit to unarchive
  /// @return true if successful, false otherwise
  Future<bool> unarchiveHabit(String habitId) async {
    try {
      final habits = await getHabits(includeArchived: true);
      final habitIndex = habits.indexWhere((habit) => habit.id == habitId);

      if (habitIndex >= 0) {
        final updatedHabit = habits[habitIndex].copyWith(isArchived: false);
        habits[habitIndex] = updatedHabit;
        await _saveHabits(habits);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error unarchiving habit: $e');
      return false;
    }
  }

  /// Get all archived habits
  ///
  /// @return List of archived habits
  Future<List<Habit>> getArchivedHabits() async {
    final habits = await getHabits(includeArchived: true);
    return habits.where((habit) => habit.isArchived).toList();
  }

  /// Update the completion status of a specific habit on a specific date
  ///
  /// Modifies the completion record for a habit without changing other properties.
  /// Uses the immutable pattern - creates a new Habit instance with updated completion.
  ///
  /// @param habitId Unique identifier of the habit to update
  /// @param date The date for which to update completion status
  /// @param completed Whether the habit was completed on this date
  Future<void> updateHabitCompletion(String habitId, DateTime date, bool completed) async {
    final habits = await getHabits();
    final habitIndex = habits.indexWhere((habit) => habit.id == habitId);

    if (habitIndex >= 0) {
      final updatedHabit = habits[habitIndex].markCompleted(date, completed);
      habits[habitIndex] = updatedHabit; // Replace with updated habit
      await _saveHabits(habits); // Persist changes
    }
  }

  /// Persist all habits to SharedPreferences storage
  ///
  /// Internal method that serializes all habits to JSON and stores them
  /// as a list of strings in SharedPreferences. This replaces any existing
  /// habit data in storage.
  ///
  /// @param habits List of habits to persist
  Future<void> _saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = habits.map((habit) => jsonEncode(habit.toJson())).toList();
    await prefs.setStringList(_habitsKey, habitsJson);
  }

  /// Remove all stored habits (for testing/debugging purposes)
  ///
  /// Completely clears all habit data from persistent storage.
  /// This operation is irreversible and should only be used for
  /// debugging or when implementing a "reset app" feature.
  ///
  /// Warning: This permanently deletes all user habit data!
  Future<void> clearAllHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_habitsKey);
  }

  /// Calculate comprehensive habit statistics across all stored habits
  ///
  /// Aggregates data from all habits to provide insights into:
  /// - Total number of habits
  /// - Total completion count across all habits
  /// - Average current streak across habits
  /// - Average completion rate over the last 30 days
  ///
  /// @return Map containing aggregated statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final habits = await getHabits();

    if (habits.isEmpty) {
      return {
        'totalHabits': 0,
        'totalCompletions': 0,
        'averageStreak': 0.0,
        'averageCompletionRate': 0.0,
      };
    }

    // Aggregate statistics across all habits
    final totalCompletions = habits.fold<int>(0, (sum, habit) => sum + habit.totalCompletions);
    final totalStreak = habits.fold<int>(0, (sum, habit) => sum + habit.currentStreak);
    final averageCompletionRate = habits.fold<double>(0.0, (sum, habit) => sum + habit.completionRate) / habits.length;

    return {
      'totalHabits': habits.length,
      'totalCompletions': totalCompletions,
      'averageStreak': totalStreak / habits.length,
      'averageCompletionRate': averageCompletionRate,
    };
  }

  /// Get habits that need attention (low completion rate or broken streaks)
  ///
  /// Identifies habits that may need user attention based on:
  /// - Low completion rate in the last 30 days
  /// - Recently broken streaks
  /// - Habits that haven't been completed recently
  ///
  /// @return List of habits that need attention
  Future<List<Habit>> getHabitsNeedingAttention() async {
    try {
      final habits = await getHabits();
      final now = DateTime.now();

      return habits.where((habit) {
        // Check for low completion rate
        if (habit.completionRate < 0.3) return true;

        // Check for recently broken streaks (completed yesterday but not today)
        final yesterday = now.subtract(const Duration(days: 1));
        final wasCompletedYesterday = habit.isCompleted(yesterday);
        final isCompletedToday = habit.isCompleted(now);
        
        if (wasCompletedYesterday && !isCompletedToday) return true;

        // Check for habits not completed in the last week
        final lastWeek = now.subtract(const Duration(days: 7));
        final hasRecentCompletion = habit.completions.keys.any((date) => 
          date.isAfter(lastWeek) || date.isAtSameMomentAs(lastWeek)
        );
        
        if (!hasRecentCompletion) return true;

        return false;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting habits needing attention: $e');
      return [];
    }
  }
}

/// Global singleton instance of HabitStorage
///
/// Provides convenient access to habit persistence operations throughout the app.
/// This singleton pattern ensures consistent data access and prevents multiple
/// instances from interfering with each other.
///
/// Usage examples:
/// - `await habitStorage.getHabits()` - Load all habits
/// - `await habitStorage.saveHabit(newHabit)` - Save a habit
/// - `await habitStorage.updateHabitCompletion(id, date, true)` - Mark complete
/// - `await habitStorage.getStatistics()` - Get aggregated statistics
///
/// All operations are thread-safe and handle errors gracefully.
final habitStorage = HabitStorage();
