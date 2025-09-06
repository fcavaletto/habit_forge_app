import 'dart:async';
import '../models/habit.dart';
import '../models/habit_storage.dart';

/// Abstract interface for habit data operations
/// This allows for easy testing and future data source changes
abstract class HabitRepository {
  /// Get all active habits
  Future<List<Habit>> getActiveHabits();

  /// Get all habits including archived ones
  Future<List<Habit>> getAllHabits();

  /// Get only archived habits
  Future<List<Habit>> getArchivedHabits();

  /// Save a new habit
  Future<HabitSaveResult> saveHabit(Habit habit);

  /// Update habit completion status
  Future<void> updateHabitCompletion(String habitId, DateTime date, bool completed);

  /// Archive a habit
  Future<bool> archiveHabit(String habitId);

  /// Unarchive a habit
  Future<bool> unarchiveHabit(String habitId);

  /// Delete a habit permanently
  Future<void> deleteHabit(String habitId);

  /// Overwrite an archived habit with new data
  Future<HabitSaveResult> overwriteArchivedHabit(String archivedHabitId, Habit newHabit);

  /// Get habit statistics
  Future<Map<String, dynamic>> getStatistics();

  /// Get habits that need attention
  Future<List<Habit>> getHabitsNeedingAttention();

  /// Clear all habits (for testing/debugging)
  Future<void> clearAllHabits();
}

/// Implementation of HabitRepository using SharedPreferences
class HabitRepositoryImpl implements HabitRepository {
  final HabitStorage _habitStorage;

  HabitRepositoryImpl(this._habitStorage);

  @override
  Future<List<Habit>> getActiveHabits() async {
    return await _habitStorage.getHabits(includeArchived: false);
  }

  @override
  Future<List<Habit>> getAllHabits() async {
    return await _habitStorage.getHabits(includeArchived: true);
  }

  @override
  Future<List<Habit>> getArchivedHabits() async {
    return await _habitStorage.getArchivedHabits();
  }

  @override
  Future<HabitSaveResult> saveHabit(Habit habit) async {
    return await _habitStorage.saveHabit(habit);
  }

  @override
  Future<void> updateHabitCompletion(String habitId, DateTime date, bool completed) async {
    await _habitStorage.updateHabitCompletion(habitId, date, completed);
  }

  @override
  Future<bool> archiveHabit(String habitId) async {
    return await _habitStorage.archiveHabit(habitId);
  }

  @override
  Future<bool> unarchiveHabit(String habitId) async {
    return await _habitStorage.unarchiveHabit(habitId);
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await _habitStorage.deleteHabit(habitId);
  }

  @override
  Future<HabitSaveResult> overwriteArchivedHabit(String archivedHabitId, Habit newHabit) async {
    return await _habitStorage.overwriteArchivedHabit(archivedHabitId, newHabit);
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return await _habitStorage.getStatistics();
  }

  @override
  Future<List<Habit>> getHabitsNeedingAttention() async {
    return await _habitStorage.getHabitsNeedingAttention();
  }

  @override
  Future<void> clearAllHabits() async {
    await _habitStorage.clearAllHabits();
  }
}
