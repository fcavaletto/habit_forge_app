import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'habit.dart';

/// Service for managing habit persistence using local storage
class HabitStorage {
  static const String _habitsKey = 'habits';

  /// Get all stored habits
  Future<List<Habit>> getHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = prefs.getStringList(_habitsKey) ?? [];

    return habitsJson.map((json) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return Habit.fromJson(map);
      } catch (e) {
        // Error parsing habit, return null
        return null;
      }
    }).whereType<Habit>().toList();
  }

  /// Save a single habit
  Future<void> saveHabit(Habit habit) async {
    final habits = await getHabits();
    final existingIndex = habits.indexWhere((h) => h.id == habit.id);

    if (existingIndex >= 0) {
      habits[existingIndex] = habit;
    } else {
      habits.add(habit);
    }

    await _saveHabits(habits);
  }

  /// Delete a habit by ID
  Future<void> deleteHabit(String habitId) async {
    final habits = await getHabits();
    habits.removeWhere((habit) => habit.id == habitId);
    await _saveHabits(habits);
  }

  /// Update habit completion status
  Future<void> updateHabitCompletion(String habitId, DateTime date, bool completed) async {
    final habits = await getHabits();
    final habitIndex = habits.indexWhere((habit) => habit.id == habitId);

    if (habitIndex >= 0) {
      final updatedHabit = habits[habitIndex].markCompleted(date, completed);
      habits[habitIndex] = updatedHabit;
      await _saveHabits(habits);
    }
  }

  /// Save all habits to storage
  Future<void> _saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = habits.map((habit) => jsonEncode(habit.toJson())).toList();
    await prefs.setStringList(_habitsKey, habitsJson);
  }

  /// Clear all stored habits (for testing/debugging)
  Future<void> clearAllHabits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_habitsKey);
  }

  /// Get habit statistics
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

/// Singleton instance for easy access throughout the app
final habitStorage = HabitStorage();
