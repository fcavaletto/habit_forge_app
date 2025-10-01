import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../services/database_service.dart';
import '../utils/timezone_utils.dart';

/// SQLite implementation for habit data operations
///
/// Provides all habit data operations using SQLite database.
class SqliteHabitRepository {
  final DatabaseService _databaseService;
  
  SqliteHabitRepository(this._databaseService);
  
  Future<List<Habit>> getActiveHabits() async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery('''
        SELECT h.*, o.order_value
        FROM habits h
        INNER JOIN habit_display_order o ON h.id = o.habit_id
        WHERE h.is_archived = 0
        ORDER BY o.order_value DESC
      ''');
      
      final habits = <Habit>[];
      for (final row in results) {
        final habit = await _rowToHabit(row);
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits from SQLite (with custom ordering)');
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
      
      // Check for duplicates using name + icon combination
      final hasDuplicate = await hasDuplicateHabit(habit.name, habit.iconName);
      if (hasDuplicate) {
        debugPrint('💾 Found duplicate habit with same name and icon');
        return HabitSaveResult.duplicate(habit.name);
      }
      
      // Save new habit
      await _databaseService.transaction((txn) async {
        // Insert habit
        await txn.insert('habits', _habitToRow(habit));
        
        // Insert ordering record (new habits go to top)
        final topOrder = await _getNextTopOrderValue(txn);
        await txn.insert('habit_display_order', {
          'habit_id': habit.id,
          'order_value': topOrder,
          'created_at': TimezoneUtils.getCurrentUtcTimestamp(),
        });
        
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
            'completion_date': TimezoneUtils.toUtcTimestamp(entry.key),
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
  
  /// Get a specific habit by its ID
  Future<Habit?> getHabitById(String habitId) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        'habits',
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      if (results.isNotEmpty) {
        return await _rowToHabit(results.first);
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting habit by ID: $e');
      return null;
    }
  }
  
  /// Add multiple completions for a habit on a specific date (batch operation)
  /// 
  /// This is an optimized version that adds multiple completions in a single transaction
  /// instead of multiple individual calls. This reduces database operations significantly.
  Future<void> addMultipleCompletions(String habitId, DateTime date, int count) async {
    if (count <= 0) {
      debugPrint('📝 No completions to add for habit $habitId');
      return;
    }
    
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateTimestamp = TimezoneUtils.toUtcTimestamp(normalizedDate);
      
      // Get current habit to get the goal (only once, not per completion)
      final habit = await getHabitById(habitId);
      if (habit == null) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }
      
      await _databaseService.transaction((txn) async {
        // Check if completion record exists
        final existingRecord = await txn.query(
          'habit_completions',
          where: 'habit_id = ? AND completion_date = ?',
          whereArgs: [habitId, dateTimestamp],
        );
        
        if (existingRecord.isNotEmpty) {
          // Increment existing count by the batch amount
          await txn.update(
            'habit_completions',
            {
              'completion_count': (existingRecord.first['completion_count'] as int) + count,
              'goal_at_completion': habit.targetGoal,
            },
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateTimestamp],
          );
        } else {
          // Insert new record with batch count
          await txn.insert(
            'habit_completions',
            {
              'habit_id': habitId,
              'completion_date': dateTimestamp,
              'completion_count': count,
              'goal_at_completion': habit.targetGoal,
            },
          );
        }
        
        // Add multiple timestamp records (one per completion)
        for (int i = 0; i < count; i++) {
          final completionTimestamp = TimezoneUtils.toUtcTimestampSeconds(date);
          await txn.insert(
            'habit_completion_timestamps',
            {
              'habit_id': habitId,
              'completion_timestamp': completionTimestamp,
            },
          );
        }
      });
      
      debugPrint('✅ Added $count completions for habit $habitId on ${date.toIso8601String()} (batch operation)');
    } catch (e) {
      debugPrint('❌ Error adding multiple habit completions: $e');
      rethrow;
    }
  }
  
  /// Add a completion for a habit on a specific date (legacy method)
  /// 
  /// This method is kept for backward compatibility but should be replaced
  /// with addMultipleCompletions for better performance.
  Future<void> addHabitCompletion(String habitId, DateTime date) async {
    await addMultipleCompletions(habitId, date, 1);
  }
  
  /// Remove a completion for a habit on a specific date
  Future<void> removeHabitCompletion(String habitId, DateTime date) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateTimestamp = TimezoneUtils.toUtcTimestamp(normalizedDate);
      
      await _databaseService.transaction((txn) async {
        // Get current completion count
        final completionRows = await txn.query(
          'habit_completions',
          where: 'habit_id = ? AND completion_date = ?',
          whereArgs: [habitId, dateTimestamp],
        );
        
        if (completionRows.isNotEmpty) {
          final currentCount = completionRows.first['completion_count'] as int;
          
          if (currentCount > 1) {
            // Decrement completion count
            await txn.update(
              'habit_completions',
              {'completion_count': currentCount - 1},
              where: 'habit_id = ? AND completion_date = ?',
              whereArgs: [habitId, dateTimestamp],
            );
          } else {
            // Remove completion record entirely
            await txn.delete(
              'habit_completions',
              where: 'habit_id = ? AND completion_date = ?',
              whereArgs: [habitId, dateTimestamp],
            );
          }
        }
        
        // Remove most recent timestamp record for this habit on this specific date
        // We need to be more specific about which timestamp to remove
        final startOfDay = TimezoneUtils.toUtcTimestampSeconds(normalizedDate);
        final endOfDay = TimezoneUtils.toUtcTimestampSeconds(
          DateTime(normalizedDate.year, normalizedDate.month, normalizedDate.day, 23, 59, 59)
        );
        
        final timestampRows = await txn.query(
          'habit_completion_timestamps',
          where: 'habit_id = ? AND completion_timestamp >= ? AND completion_timestamp <= ?',
          whereArgs: [habitId, startOfDay, endOfDay],
          orderBy: 'completion_timestamp DESC',
          limit: 1,
        );
        
        if (timestampRows.isNotEmpty) {
          await txn.delete(
            'habit_completion_timestamps',
            where: 'id = ?',
            whereArgs: [timestampRows.first['id']],
          );
        }
      });
      
      debugPrint('❌ Removed completion for habit $habitId on ${date.toIso8601String()}');
    } catch (e) {
      debugPrint('❌ Error removing habit completion: $e');
    }
  }
  
  /// Update completion count for a habit on a specific date
  Future<void> updateHabitCompletion(String habitId, DateTime date, int count) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateTimestamp = TimezoneUtils.toUtcTimestamp(normalizedDate);
      
      // Get current habit to get the goal
      final habit = await getHabitById(habitId);
      if (habit == null) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }
      
      await _databaseService.transaction((txn) async {
        if (count > 0) {
          // Insert or update completion record
          await txn.insert(
            'habit_completions',
            {
              'habit_id': habitId,
              'completion_date': dateTimestamp,
              'completion_count': count,
              'goal_at_completion': habit.targetGoal,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          // Remove completion record
          await txn.delete(
            'habit_completions',
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateTimestamp],
          );
        }
      });
      
      debugPrint('💾 Updated habit completion: $habitId on ${date.toIso8601String()} = $count');
    } catch (e) {
      debugPrint('❌ Error updating habit completion: $e');
    }
  }

  /// Remove all completions for a habit on a specific date
  /// This completely resets the habit for that day, removing all completion records
  Future<void> removeAllCompletionsForDate(String habitId, DateTime date) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateTimestamp = TimezoneUtils.toUtcTimestamp(normalizedDate);
      
      await _databaseService.transaction((txn) async {
        // Remove completion record for this date
        await txn.delete(
          'habit_completions',
          where: 'habit_id = ? AND completion_date = ?',
          whereArgs: [habitId, dateTimestamp],
        );
        
        // Remove all timestamp records for this habit on this date
        // Calculate the full day range for timestamp cleanup
        // IMPORTANT: Use toUtcTimestampSeconds for timestamps table (stored in seconds)
        final startOfDay = TimezoneUtils.toUtcTimestampSeconds(normalizedDate);
        final endOfDay = TimezoneUtils.toUtcTimestampSeconds(
          DateTime(normalizedDate.year, normalizedDate.month, normalizedDate.day, 23, 59, 59)
        );
        
        debugPrint('🗑️ [Reset] Deleting timestamps for $habitId from $startOfDay to $endOfDay (seconds)');
        
        await txn.delete(
          'habit_completion_timestamps',
          where: 'habit_id = ? AND completion_timestamp >= ? AND completion_timestamp <= ?',
          whereArgs: [habitId, startOfDay, endOfDay],
        );
      });
      
      debugPrint('🔄 Reset all completions for habit $habitId on ${date.toIso8601String()}');
    } catch (e) {
      debugPrint('❌ Error removing all completions for date: $e');
    }
  }
  
  Future<bool> archiveHabit(String habitId) async {
    try {
      debugPrint('🗄️ Repository: Starting archiveHabit for ID: $habitId');
      final db = await _databaseService.database;
      
      final result = await db.transaction<bool>((txn) async {
        // First, check if the habit exists
        final existingHabit = await txn.query(
          'habits',
          where: 'id = ?',
          whereArgs: [habitId],
        );
        
        if (existingHabit.isEmpty) {
          debugPrint('❌ Repository: Habit with ID $habitId not found in database');
          return false;
        }
        
        debugPrint('🗄️ Repository: Found habit: ${existingHabit.first['name']}, currently archived: ${existingHabit.first['is_archived']}');
        
        // Archive the habit
        final updateResult = await txn.update(
          'habits',
          {'is_archived': 1},
          where: 'id = ?',
          whereArgs: [habitId],
        );
        
        // Remove from ordering table (archived habits don't need ordering)
        await txn.delete(
          'habit_display_order',
          where: 'habit_id = ?',
          whereArgs: [habitId],
        );
        
        debugPrint('💾 Repository: Archived habit $habitId and removed from ordering (affected rows: $updateResult)');
        return updateResult > 0;
      });
      
      final success = result;
      
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
      await _databaseService.transaction((txn) async {
        // Unarchive habit
        await txn.update(
          'habits',
          {'is_archived': 0},
          where: 'id = ?',
          whereArgs: [habitId],
        );
        
        // Position at bottom (unarchived habits go to bottom)
        final bottomOrder = await _getNextBottomOrderValue(txn);
        
        // Use INSERT OR REPLACE to handle both new and existing records
        await txn.rawInsert('''
          INSERT OR REPLACE INTO habit_display_order (habit_id, order_value, created_at)
          VALUES (?, ?, ?)
        ''', [habitId, bottomOrder, TimezoneUtils.getCurrentUtcTimestamp()]);
      });
      
      debugPrint('💾 Unarchived habit $habitId and positioned at bottom');
      return true;
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
            'allow_exceed_goal': newHabit.allowExceedGoal ? 1 : 0,
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
        completions: <DateTime, CompletionRecord>{}, // Will be loaded from DB
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
      
      final completions = <DateTime, CompletionRecord>{};
      for (final completionRow in completionRows) {
        debugPrint('📅 Loading completion record for habit ${row['id']}');
        final date = TimezoneUtils.fromUtcTimestamp(completionRow['completion_date'] as int);
        final count = completionRow['completion_count'] as int;
        final goalAtCompletion = completionRow['goal_at_completion'] as int;
        completions[date] = CompletionRecord(
          count: count,
          goalAtCompletion: goalAtCompletion,
        );
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
        createdAt: (() {
          debugPrint('🕒 Loading habit creation timestamp for habit ${row['id']}');
          return TimezoneUtils.fromUtcTimestamp(row['created_at'] as int);
        })(),
        completions: completions,
        iconName: row['icon_name'] as String,
        reminderTime: reminderTime,
        enableReminders: enableReminders,
        isArchived: (row['is_archived'] as int) == 1,
        orderValue: row['order_value'] as double?,
        frequencyDays: frequencyDays,
        targetGoal: row['target_goal'] as int,
        allowExceedGoal: (row['allow_exceed_goal'] as int) == 1,
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
      'created_at': TimezoneUtils.toUtcTimestamp(habit.createdAt),
      'is_archived': habit.isArchived ? 1 : 0,
      'frequency_days': jsonEncode(habit.frequencyDays),
      'target_goal': habit.targetGoal,
      'allow_exceed_goal': habit.allowExceedGoal ? 1 : 0,
    };
  }
  
  /// Get the next order value for positioning at the top
  Future<double> _getNextTopOrderValue([Transaction? txn]) async {
    final db = txn ?? await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT MAX(order_value) as max_order FROM habit_display_order'
    );
    final maxOrder = result.first['max_order'] as double? ?? 0.0;
    return maxOrder + 1000.0; // Large gap for future insertions
  }
  
  /// Get the next order value for positioning at the bottom
  Future<double> _getNextBottomOrderValue([Transaction? txn]) async {
    final db = txn ?? await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT MIN(order_value) as min_order FROM habit_display_order'
    );
    final minOrder = result.first['min_order'] as double? ?? 0.0;
    return minOrder - 1000.0; // Large gap below existing items
  }
  
  /// Reorder habits using fractional positioning
  Future<void> reorderHabits(String draggedId, int newPosition) async {
    try {
      final habits = await getActiveHabits();
      double newOrderValue;
      
      if (newPosition == 0) {
        // Move to top
        newOrderValue = await _getNextTopOrderValue();
      } else if (newPosition >= habits.length - 1) {
        // Move to bottom
        newOrderValue = await _getNextBottomOrderValue();
      } else {
        // Insert between items using fractional positioning
        final prevOrder = habits[newPosition - 1].orderValue ?? 0.0;
        final nextOrder = habits[newPosition].orderValue ?? 0.0;
        newOrderValue = (prevOrder + nextOrder) / 2.0;
      }
      
      await _updateHabitOrder(draggedId, newOrderValue);
      debugPrint('🔄 Reordered habit $draggedId to position $newPosition with order value $newOrderValue');
    } catch (e) {
      debugPrint('❌ Error reordering habits: $e');
      rethrow;
    }
  }

  /// Reorder habits with filtering context - handles filtered views correctly
  Future<void> reorderHabitsInContext(
    String draggedId, 
    int newPosition, 
    List<String> visibleHabitIds
  ) async {
    try {
      debugPrint('🔄 Reordering habit $draggedId to position $newPosition in filtered context');
      debugPrint('📋 Visible habits: ${visibleHabitIds.join(', ')}');
      
      // Get all active habits with their order values
      final allHabits = await getActiveHabits();
      
      // Create a map for quick lookup
      final habitMap = {for (var h in allHabits) h.id: h};
      
      // Validate that dragged habit exists and is visible
      if (!visibleHabitIds.contains(draggedId)) {
        throw Exception('Dragged habit $draggedId is not in visible list');
      }
      
      // Get visible habits in their current order
      final visibleHabits = visibleHabitIds
          .map((id) => habitMap[id])
          .where((h) => h != null)
          .cast<Habit>()
          .toList();
      
      if (visibleHabits.length != visibleHabitIds.length) {
        throw Exception('Some visible habits not found in database');
      }
      
      double newOrderValue;
      
      if (newPosition == 0) {
        // Move to top of visible habits
        final topVisibleHabit = visibleHabits.first;
        final topOrder = topVisibleHabit.orderValue ?? 0.0;
        newOrderValue = topOrder + 1000.0; // Large gap above
        debugPrint('📍 Moving to top of visible habits (above ${topVisibleHabit.name})');
      } else if (newPosition >= visibleHabits.length - 1) {
        // Move to bottom of visible habits
        final bottomVisibleHabit = visibleHabits.last;
        final bottomOrder = bottomVisibleHabit.orderValue ?? 0.0;
        newOrderValue = bottomOrder - 1000.0; // Large gap below
        debugPrint('📍 Moving to bottom of visible habits (below ${bottomVisibleHabit.name})');
      } else {
        // Insert between visible habits
        final prevHabit = visibleHabits[newPosition - 1];
        final nextHabit = visibleHabits[newPosition];
        final prevOrder = prevHabit.orderValue ?? 0.0;
        final nextOrder = nextHabit.orderValue ?? 0.0;
        newOrderValue = (prevOrder + nextOrder) / 2.0;
        debugPrint('📍 Inserting between ${prevHabit.name} and ${nextHabit.name}');
      }
      
      await _updateHabitOrder(draggedId, newOrderValue);
      debugPrint('✅ Reordered habit $draggedId to position $newPosition with order value $newOrderValue');
    } catch (e) {
      debugPrint('❌ Error reordering habits in context: $e');
      rethrow;
    }
  }
  
  /// Update a habit's order value
  Future<void> _updateHabitOrder(String habitId, double orderValue) async {
    final db = await _databaseService.database;
    await db.update(
      'habit_display_order',
      {'order_value': orderValue},
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
  }
  
  /// Normalize order values to prevent precision issues
  Future<void> normalizeOrderValues() async {
    try {
      final habits = await getActiveHabits();
      await _databaseService.transaction((txn) async {
        for (int i = 0; i < habits.length; i++) {
          await txn.update(
            'habit_display_order',
            {'order_value': (i + 1) * 1000.0}, // Clean integer multiples
            where: 'habit_id = ?',
            whereArgs: [habits[i].id],
          );
        }
      });
      debugPrint('🔄 Normalized order values for ${habits.length} habits');
    } catch (e) {
      debugPrint('❌ Error normalizing order values: $e');
    }
  }

  /// Check if a habit with the same name and icon already exists
  ///
  /// This method provides duplicate detection for habit creation and editing.
  /// It checks against active (non-archived) habits only.
  ///
  /// @param name The habit name to check
  /// @param iconName The icon name to check
  /// @param excludeHabitId Optional habit ID to exclude from check (for editing)
  /// @return true if a duplicate exists, false otherwise
  Future<bool> hasDuplicateHabit(String name, String iconName, {String? excludeHabitId}) async {
    try {
      final normalizedName = name.toLowerCase().trim();
      final normalizedIcon = iconName.toLowerCase().trim();
      
      final db = await _databaseService.database;
      
      String whereClause = 'LOWER(TRIM(name)) = ? AND LOWER(TRIM(icon_name)) = ? AND is_archived = 0';
      List<dynamic> whereArgs = [normalizedName, normalizedIcon];
      
      if (excludeHabitId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludeHabitId);
      }
      
      final results = await db.query(
        'habits',
        where: whereClause,
        whereArgs: whereArgs,
      );
      
      final hasDuplicate = results.isNotEmpty;
      debugPrint('🔍 Duplicate check: name="$name", icon="$iconName", exclude="$excludeHabitId" -> $hasDuplicate');
      
      return hasDuplicate;
    } catch (e) {
      debugPrint('❌ Error checking for duplicate habit: $e');
      return false; // Fail safe - allow creation if check fails
    }
  }

  /// Check if a habit can be updated without creating duplicates
  ///
  /// This method is used when editing existing habits to ensure the new
  /// name/icon combination doesn't conflict with other active habits.
  ///
  /// @param habitId The ID of the habit being edited
  /// @param newName The new name for the habit
  /// @param newIconName The new icon name for the habit
  /// @return true if the update is safe (no duplicates), false otherwise
  Future<bool> canUpdateHabit(String habitId, String newName, String newIconName) async {
    return !await hasDuplicateHabit(newName, newIconName, excludeHabitId: habitId);
  }

  /// Get hourly completion distribution for a specific date range
  ///
  /// Analyzes completion timestamps to show when during the day completions occur.
  /// Returns a map where keys are hours (0-23) and values are completion counts.
  ///
  /// @param habitId The ID of the habit to analyze
  /// @param startDate The start date for the analysis (inclusive)
  /// @param endDate The end date for the analysis (inclusive)
  /// @return Map<int, int> where key = hour (0-23), value = completion count
  Future<Map<int, int>> getHourlyCompletions(String habitId, DateTime startDate, DateTime endDate) async {
    try {
      final db = await _databaseService.database;
      
      // Convert dates to UTC timestamps for SQLite comparison
      final startTimestamp = TimezoneUtils.toUtcTimestampSeconds(startDate);
      final endTimestamp = TimezoneUtils.toUtcTimestampSeconds(endDate);
      
      debugPrint('📊 [HourlyQuery] Querying hourly completions for $habitId');
      debugPrint('📅 [HourlyQuery] Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      debugPrint('🌍 [HourlyQuery] UTC range: $startTimestamp to $endTimestamp');
      
      final result = await db.rawQuery('''
        SELECT 
          CAST(strftime('%H', completion_timestamp, 'unixepoch', 'localtime') AS INTEGER) as hour,
          COUNT(*) as count
        FROM habit_completion_timestamps 
        WHERE habit_id = ? 
          AND completion_timestamp >= ? 
          AND completion_timestamp <= ?
        GROUP BY hour
        ORDER BY hour
      ''', [habitId, startTimestamp, endTimestamp]);
      
      // Convert result to Map<int, int> and ensure all hours (0-23) are represented
      final hourlyCompletions = <int, int>{};
      for (int hour = 0; hour < 24; hour++) {
        hourlyCompletions[hour] = 0;
      }
      
      for (final row in result) {
        final hour = row['hour'] as int;
        final count = row['count'] as int;
        hourlyCompletions[hour] = count;
        debugPrint('🕐 [HourlyQuery] Hour $hour: $count completions');
      }
      
      debugPrint('📊 Hourly completions for $habitId: ${hourlyCompletions.entries.where((e) => e.value > 0).length} hours with completions');
      return hourlyCompletions;
    } catch (e) {
      debugPrint('❌ Error getting hourly completions: $e');
      rethrow;
    }
  }

  /// Get total hourly completion distribution for a habit
  ///
  /// Analyzes all completion timestamps for a habit to show historical
  /// completion patterns throughout the day.
  ///
  /// @param habitId The ID of the habit to analyze
  /// @return Map<int, int> where key = hour (0-23), value = completion count
  Future<Map<int, int>> getTotalHourlyCompletions(String habitId) async {
    try {
      final db = await _databaseService.database;
      
      debugPrint('📊 [HourlyQuery] Querying total hourly completions for $habitId');
      
      final result = await db.rawQuery('''
        SELECT 
          CAST(strftime('%H', completion_timestamp, 'unixepoch', 'localtime') AS INTEGER) as hour,
          COUNT(*) as count
        FROM habit_completion_timestamps 
        WHERE habit_id = ?
        GROUP BY hour
        ORDER BY hour
      ''', [habitId]);
      
      // Convert result to Map<int, int> and ensure all hours (0-23) are represented
      final hourlyCompletions = <int, int>{};
      for (int hour = 0; hour < 24; hour++) {
        hourlyCompletions[hour] = 0;
      }
      
      for (final row in result) {
        final hour = row['hour'] as int;
        final count = row['count'] as int;
        hourlyCompletions[hour] = count;
      }
      
      debugPrint('📊 All-time hourly completions for $habitId: ${hourlyCompletions.entries.where((e) => e.value > 0).length} hours with completions');
      return hourlyCompletions;
    } catch (e) {
      debugPrint('❌ Error getting all-time hourly completions: $e');
      rethrow;
    }
  }

  /// Get completion timestamps for a specific day
  Future<List<DateTime>> getCompletionTimestampsForDay(String habitId, DateTime date) async {
    try {
      final db = await _databaseService.database;
      
      // Convert date to UTC timestamps for SQLite comparison
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final startTimestamp = TimezoneUtils.toUtcTimestampSeconds(startOfDay);
      final endTimestamp = TimezoneUtils.toUtcTimestampSeconds(endOfDay);
      
      debugPrint('📅 [DayQuery] Querying completion timestamps for $habitId on ${date.toIso8601String()}');
      debugPrint('🌍 [DayQuery] UTC range: $startTimestamp to $endTimestamp');
      
      final result = await db.rawQuery('''
        SELECT completion_timestamp
        FROM habit_completion_timestamps 
        WHERE habit_id = ? 
          AND completion_timestamp >= ? 
          AND completion_timestamp <= ?
        ORDER BY completion_timestamp ASC
      ''', [habitId, startTimestamp, endTimestamp]);
      
      // Convert UTC timestamps back to local DateTime
      final timestamps = result.map((row) {
        final utcTimestampSeconds = row['completion_timestamp'] as int;
        return TimezoneUtils.fromUtcTimestampSeconds(utcTimestampSeconds);
      }).toList();
      
      debugPrint('📊 [DayQuery] Found ${timestamps.length} completions for $habitId on ${date.toIso8601String()}');
      return timestamps;
    } catch (e) {
      debugPrint('❌ Error getting completion timestamps for day: $e');
      rethrow;
    }
  }
}
