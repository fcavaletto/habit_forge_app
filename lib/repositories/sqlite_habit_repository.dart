import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../services/database_service.dart';

/// SQLite implementation for habit data operations
///
/// Provides all habit data operations using SQLite database.
class SqliteHabitRepository {
  final DatabaseService _databaseService;
  
  SqliteHabitRepository(this._databaseService);
  
  Future<List<Habit>> getActiveHabits() async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        'habits',
        where: 'is_archived = ?',
        whereArgs: [0],
        orderBy: 'created_at DESC',
      );
      
      final habits = <Habit>[];
      for (final row in results) {
        final habit = await _rowToHabit(row);
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits from SQLite');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits: $e');
      return [];
    }
  }
  
  Future<List<Habit>> getAllHabits() async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        'habits',
        orderBy: 'created_at DESC',
      );
      
      final habits = <Habit>[];
      for (final row in results) {
        final habit = await _rowToHabit(row);
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} total habits from SQLite');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting all habits: $e');
      return [];
    }
  }
  
  Future<List<Habit>> getArchivedHabits() async {
    try {
      debugPrint('🗄️ Repository: Starting getArchivedHabits query...');
      final db = await _databaseService.database;
      debugPrint('🗄️ Repository: Database connection obtained');
      
      final results = await db.query(
        'habits',
        where: 'is_archived = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );
      
      debugPrint('🗄️ Repository: Raw query returned ${results.length} rows');
      
      // Log raw database results
      for (int i = 0; i < results.length; i++) {
        final row = results[i];
        debugPrint('🗄️ Repository: Row $i - ID: ${row['id']}, Name: ${row['name']}, Archived: ${row['is_archived']}');
      }
      
      final habits = <Habit>[];
      for (final row in results) {
        final habit = await _rowToHabit(row);
        if (habit != null) {
          habits.add(habit);
          debugPrint('🗄️ Repository: Successfully converted row to habit: ${habit.name}');
        } else {
          debugPrint('🗄️ Repository: Failed to convert row to habit: ${row['id']}');
        }
      }
      
      debugPrint('📖 Repository: Retrieved ${habits.length} archived habits from SQLite');
      return habits;
    } catch (e) {
      debugPrint('❌ Repository: Error getting archived habits: $e');
      debugPrint('❌ Repository: Error type: ${e.runtimeType}');
      debugPrint('❌ Repository: Stack trace: ${StackTrace.current}');
      return [];
    }
  }
  
  Future<HabitSaveResult> saveHabit(Habit habit) async {
    try {
      debugPrint('💾 Saving habit to SQLite: ${habit.name}');
      
      // Check for duplicates (including archived)
      final existingHabits = await getAllHabits();
      final existingIndex = existingHabits.indexWhere((h) => h.id == habit.id);
      
      if (existingIndex >= 0) {
        final existingHabit = existingHabits[existingIndex];
        if (existingHabit.isArchived) {
          debugPrint('💾 Found archived duplicate habit');
          return HabitSaveResult.duplicateArchived(existingHabit);
        } else {
          debugPrint('💾 Found active duplicate habit');
          return HabitSaveResult.duplicate(existingHabit.name);
        }
      }
      
      // Save new habit
      await _databaseService.transaction((txn) async {
        // Insert habit
        await txn.insert('habits', _habitToRow(habit));
        
        // Insert reminder if enabled
        if (habit.enableReminders && habit.reminderTime != null) {
          await txn.insert('habit_reminders', {
            'habit_id': habit.id,
            'reminder_time_hour': habit.reminderTime!.hour,
            'reminder_time_minute': habit.reminderTime!.minute,
            'enable_reminders': 1,
          });
        }
        
        // Insert completion records
        for (final entry in habit.completions.entries) {
          await txn.insert('habit_completions', {
            'habit_id': habit.id,
            'completion_date': entry.key.millisecondsSinceEpoch,
            'completion_count': entry.value,
            'completion_goal': habit.targetGoal,
          });
        }
      });
      
      debugPrint('💾 Habit saved successfully to SQLite');
      return HabitSaveResult.success(habit);
    } catch (e) {
      debugPrint('❌ Error saving habit: $e');
      return HabitSaveResult.error('Failed to save habit: $e');
    }
  }
  
  Future<void> updateHabitCompletion(String habitId, DateTime date, int count) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final timestamp = normalizedDate.millisecondsSinceEpoch;
      
      await _databaseService.transaction((txn) async {
        if (count > 0) {
          // Insert or update completion record
          await txn.insert(
            'habit_completions',
            {
              'habit_id': habitId,
              'completion_date': timestamp,
              'completion_count': count,
              'completion_goal': 1, // Default goal, will be updated if needed
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          // Remove completion record
          await txn.delete(
            'habit_completions',
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, timestamp],
          );
        }
      });
      
      debugPrint('💾 Updated habit completion: $habitId on ${normalizedDate.toIso8601String()} = $count');
    } catch (e) {
      debugPrint('❌ Error updating habit completion: $e');
    }
  }
  
  Future<bool> archiveHabit(String habitId) async {
    try {
      debugPrint('🗄️ Repository: Starting archiveHabit for ID: $habitId');
      final db = await _databaseService.database;
      
      // First, check if the habit exists
      final existingHabit = await db.query(
        'habits',
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      if (existingHabit.isEmpty) {
        debugPrint('❌ Repository: Habit with ID $habitId not found in database');
        return false;
      }
      
      debugPrint('🗄️ Repository: Found habit: ${existingHabit.first['name']}, currently archived: ${existingHabit.first['is_archived']}');
      
      final result = await db.update(
        'habits',
        {'is_archived': 1},
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      final success = result > 0;
      debugPrint('💾 Repository: Archived habit $habitId: $success (affected rows: $result)');
      
      // Verify the update
      final updatedHabit = await db.query(
        'habits',
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      if (updatedHabit.isNotEmpty) {
        debugPrint('✅ Repository: Verification - habit ${updatedHabit.first['name']} is now archived: ${updatedHabit.first['is_archived']}');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Repository: Error archiving habit: $e');
      debugPrint('❌ Repository: Error type: ${e.runtimeType}');
      debugPrint('❌ Repository: Stack trace: ${StackTrace.current}');
      return false;
    }
  }
  
  Future<bool> unarchiveHabit(String habitId) async {
    try {
      final db = await _databaseService.database;
      final result = await db.update(
        'habits',
        {'is_archived': 0},
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      final success = result > 0;
      debugPrint('💾 Unarchived habit $habitId: $success');
      return success;
    } catch (e) {
      debugPrint('❌ Error unarchiving habit: $e');
      return false;
    }
  }
  
  Future<void> deleteHabit(String habitId) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        'habits',
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      debugPrint('💾 Deleted habit $habitId');
    } catch (e) {
      debugPrint('❌ Error deleting habit: $e');
    }
  }
  
  Future<HabitSaveResult> overwriteArchivedHabit(String archivedHabitId, Habit newHabit) async {
    try {
      await _databaseService.transaction((txn) async {
        // Update habit properties
        await txn.update(
          'habits',
          {
            'name': newHabit.name,
            'description': newHabit.description,
            'color_index': newHabit.colorIndex,
            'icon_name': newHabit.iconName,
            'frequency_days': jsonEncode(newHabit.frequencyDays),
            'target_goal': newHabit.targetGoal,
            'is_archived': 0, // Unarchive
          },
          where: 'id = ?',
          whereArgs: [archivedHabitId],
        );
        
        // Update reminder settings
        await txn.delete('habit_reminders', where: 'habit_id = ?', whereArgs: [archivedHabitId]);
        
        if (newHabit.enableReminders && newHabit.reminderTime != null) {
          await txn.insert('habit_reminders', {
            'habit_id': archivedHabitId,
            'reminder_time_hour': newHabit.reminderTime!.hour,
            'reminder_time_minute': newHabit.reminderTime!.minute,
            'enable_reminders': 1,
          });
        }
      });
      
      // Create updated habit with preserved data
      final updatedHabit = Habit(
        id: archivedHabitId,
        name: newHabit.name,
        description: newHabit.description,
        colorIndex: newHabit.colorIndex,
        createdAt: DateTime.now(), // Will be updated from DB
        completions: <DateTime, int>{}, // Will be loaded from DB
        iconName: newHabit.iconName,
        reminderTime: newHabit.reminderTime,
        enableReminders: newHabit.enableReminders,
        isArchived: false,
        frequencyDays: newHabit.frequencyDays,
        targetGoal: newHabit.targetGoal,
      );
      
      debugPrint('💾 Overwrote archived habit $archivedHabitId');
      return HabitSaveResult.success(updatedHabit);
    } catch (e) {
      debugPrint('❌ Error overwriting archived habit: $e');
      return HabitSaveResult.error('Failed to overwrite archived habit: $e');
    }
  }
  
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final habits = await getActiveHabits();
      
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
    } catch (e) {
      debugPrint('❌ Error getting statistics: $e');
      return {
        'totalHabits': 0,
        'totalCompletions': 0,
        'averageStreak': 0.0,
        'averageCompletionRate': 0.0,
      };
    }
  }
  
  Future<List<Habit>> getHabitsNeedingAttention() async {
    try {
      final habits = await getActiveHabits();
      final now = DateTime.now();
      
      return habits.where((habit) {
        // Check for low completion rate
        if (habit.completionRate < 0.3) return true;
        
        // Check for recently broken streaks
        final yesterday = now.subtract(const Duration(days: 1));
        final wasGoalAchievedYesterday = habit.isGoalAchieved(yesterday);
        final isGoalAchievedToday = habit.isGoalAchieved(now);
        
        if (wasGoalAchievedYesterday && !isGoalAchievedToday) return true;
        
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
  
  Future<void> clearAllHabits() async {
    try {
      await _databaseService.transaction((txn) async {
        await txn.delete('habit_completions');
        await txn.delete('habit_reminders');
        await txn.delete('habits');
      });
      
      debugPrint('💾 Cleared all habits from SQLite');
    } catch (e) {
      debugPrint('❌ Error clearing all habits: $e');
    }
  }
  
  /// Convert database row to Habit object
  Future<Habit?> _rowToHabit(Map<String, dynamic> row) async {
    try {
      // Load completions
      final db = await _databaseService.database;
      final completionRows = await db.query(
        'habit_completions',
        where: 'habit_id = ?',
        whereArgs: [row['id']],
      );
      
      final completions = <DateTime, int>{};
      for (final completionRow in completionRows) {
        final date = DateTime.fromMillisecondsSinceEpoch(completionRow['completion_date'] as int);
        final count = completionRow['completion_count'] as int;
        completions[date] = count;
      }
      
      // Load reminder settings
      final reminderRows = await db.query(
        'habit_reminders',
        where: 'habit_id = ?',
        whereArgs: [row['id']],
      );
      
      TimeOfDay? reminderTime;
      bool enableReminders = false;
      
      if (reminderRows.isNotEmpty) {
        final reminderRow = reminderRows.first;
        enableReminders = (reminderRow['enable_reminders'] as int) == 1;
        if (enableReminders && reminderRow['reminder_time_hour'] != null) {
          reminderTime = TimeOfDay(
            hour: reminderRow['reminder_time_hour'] as int,
            minute: reminderRow['reminder_time_minute'] as int,
          );
        }
      }
      
      // Parse frequency days
      final frequencyDaysJson = row['frequency_days'] as String;
      final frequencyDays = Map<String, int>.from(jsonDecode(frequencyDaysJson));
      
      return Habit(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        colorIndex: row['color_index'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        completions: completions,
        iconName: row['icon_name'] as String,
        reminderTime: reminderTime,
        enableReminders: enableReminders,
        isArchived: (row['is_archived'] as int) == 1,
        frequencyDays: frequencyDays,
        targetGoal: row['target_goal'] as int,
      );
    } catch (e) {
      debugPrint('❌ Error converting row to habit: $e');
      return null;
    }
  }
  
  /// Convert Habit object to database row
  Map<String, dynamic> _habitToRow(Habit habit) {
    return {
      'id': habit.id,
      'name': habit.name,
      'description': habit.description,
      'color_index': habit.colorIndex,
      'icon_name': habit.iconName,
      'created_at': habit.createdAt.millisecondsSinceEpoch,
      'is_archived': habit.isArchived ? 1 : 0,
      'frequency_days': jsonEncode(habit.frequencyDays),
      'target_goal': habit.targetGoal,
    };
  }
}
