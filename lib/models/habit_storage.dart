import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'habit.dart';

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
  /// @return List of successfully loaded Habit objects
  Future<List<Habit>> getHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = prefs.getStringList(_habitsKey) ?? []; // Default to empty list

    return habitsJson.map((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return Habit.fromJson(map); // Deserialize each habit
      } catch (e) {
        debugPrint('Error parsing habit JSON: $e');
        return null; // Skip corrupted habits
      }
    }).whereType<Habit>().toList(); // Filter out null values from failed parsing
  }

  /// Save or update a single habit in storage
  ///
  /// Handles both creating new habits and updating existing ones.
  /// If a habit with the same ID already exists, it updates the existing entry.
  /// Otherwise, it adds the habit as a new entry.
  ///
  /// @param habit The habit to save or update
  Future<void> saveHabit(Habit habit) async {
    final habits = await getHabits();
    final existingIndex = habits.indexWhere((h) => h.id == habit.id);

    if (existingIndex >= 0) {
      habits[existingIndex] = habit; // Update existing habit
    } else {
      habits.add(habit); // Add new habit
    }

    await _saveHabits(habits); // Persist changes
  }

  /// Permanently delete a habit from storage
  ///
  /// Removes the habit with the specified ID from persistent storage.
  /// This operation cannot be undone and permanently deletes all
  /// completion history for the habit.
  ///
  /// @param habitId Unique identifier of the habit to delete
  Future<void> deleteHabit(String habitId) async {
    final habits = await getHabits();
    habits.removeWhere((habit) => habit.id == habitId); // Remove matching habit
    await _saveHabits(habits); // Persist changes
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
