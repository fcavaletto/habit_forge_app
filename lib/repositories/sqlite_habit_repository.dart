import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../services/database_service.dart';
import '../services/virtual_date_service.dart';
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
  
  /// Get active habits with minimal data for reordering operations
  /// 
  /// This method loads habits with only essential metadata (name, description, 
  /// order values, etc.) but NO completion data. This is perfect for reordering
  /// operations where we only need to know about the habits themselves, not
  /// their completion history.
  /// 
  /// Benefits:
  /// - No timezone conversions (no completion dates to convert)
  /// - Much faster loading (no completion data to process)
  /// - Minimal memory usage
  /// - Perfect for reordering, filtering, and other metadata operations
  Future<List<Habit>> getActiveHabitsForReordering() async {
    try {
      final db = await _databaseService.database;
      final results = await db.rawQuery('''
        SELECT h.*, o.order_value
        FROM habits h
        INNER JOIN habit_display_order o ON h.id = o.habit_id
        WHERE h.is_archived = 0
        ORDER BY o.order_value DESC
      ''');
      
      if (results.isEmpty) {
        debugPrint('📖 Retrieved 0 active habits for reordering');
        return [];
      }
      
      // Batch convert all creation timestamps at once
      final createdAtTimestamps = results.map((row) => row['created_at'] as int).toList();
      final createdAtDates = TimezoneUtils.batchFromUtcTimestamp(
        createdAtTimestamps,
        context: 'Batch habit creation dates for reordering',
      );
      
      // Build habits directly without _rowToHabit
      final habits = <Habit>[];
      for (int i = 0; i < results.length; i++) {
        final row = results[i];
        
        // Parse reminder time if present
        TimeOfDay? reminderTime;
        final reminderTimeStr = row['reminder_time'] as String?;
        if (reminderTimeStr != null && reminderTimeStr.isNotEmpty) {
          final parts = reminderTimeStr.split(':');
          if (parts.length == 2) {
            reminderTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
        
        // Parse frequency days
        final frequencyDaysJson = row['frequency_days'] as String;
        final frequencyDays = Map<String, int>.from(jsonDecode(frequencyDaysJson));
        
        habits.add(Habit(
          id: row['id'] as String,
          name: row['name'] as String,
          description: row['description'] as String? ?? '',
          colorIndex: row['color_index'] as int,
          createdAt: createdAtDates[i], // From batch conversion
          completions: const {}, // Empty - not loading completion data
          iconName: row['icon_name'] as String? ?? 'check_circle',
          reminderTime: reminderTime,
          enableReminders: (row['enable_reminders'] as int) == 1,
          isArchived: (row['is_archived'] as int) == 1,
          orderValue: row['order_value'] as double?,
          frequencyDays: frequencyDays,
          targetGoal: row['target_goal'] as int? ?? 1,
          allowExceedGoal: (row['allow_exceed_goal'] as int? ?? 1) == 1,
        ));
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for reordering (metadata only, batch converted)');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits for reordering: $e');
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
  
  /// Get active habits optimized for dashboard display (last 7 days, local timezone)
  /// 
  /// This method loads only the completion data needed for dashboard display,
  /// dramatically reducing database queries and improving performance.
  Future<List<Habit>> getActiveHabitsForDashboard() async {
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
      final today = VirtualDateService().currentDate;
      final last7Days = today.subtract(const Duration(days: 6));
      
      for (final row in results) {
        final habit = await _rowToHabit(
          row, 
          startDate: last7Days, 
          endDate: today,
          convertToLocal: true, // Dashboard needs local timezone for display
        );
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for dashboard (last 7 days only)');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits for dashboard: $e');
      return [];
    }
  }

  /// Get active habits optimized for streak calculation (UTC dates, no timezone conversion)
  /// 
  /// This method loads all completion data but skips timezone conversion,
  /// which is unnecessary for streak calculations and improves performance.
  Future<List<Habit>> getActiveHabitsForStreakCalculation() async {
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
        final habit = await _rowToHabit(
          row,
          convertToLocal: false, // Streak calculation doesn't need local timezone
        );
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for streak calculation (UTC dates)');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits for streak calculation: $e');
      return [];
    }
  }

  /// Get active habits optimized for stats screen (last 30 days, local timezone)
  /// 
  /// This method loads only the last 30 days of completion data, which is
  /// sufficient for most stats screen operations and improves performance.
  Future<List<Habit>> getActiveHabitsForStats() async {
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
      final today = VirtualDateService().currentDate;
      final last30Days = today.subtract(const Duration(days: 29));
      
      for (final row in results) {
        final habit = await _rowToHabit(
          row,
          startDate: last30Days,
          endDate: today,
          convertToLocal: true, // Stats screen needs local timezone for display
        );
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for stats (last 30 days only)');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits for stats: $e');
      return [];
    }
  }

  /// Get active habits with full data for calendar screen (all data, local timezone)
  /// 
  /// This method loads all completion data and is used by calendar screen
  /// and other views that need historical data.
  Future<List<Habit>> getActiveHabitsWithFullData() async {
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
        final habit = await _rowToHabit(
          row,
          convertToLocal: true, // Calendar needs local timezone for display
        );
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits with full completion data');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits with full data: $e');
      return [];
    }
  }

  /// Get active habits for dashboard with custom date range
  /// 
  /// [startDate] - Start date for completion data filtering
  /// [endDate] - End date for completion data filtering
  /// [habitIds] - Optional list of specific habit IDs to load
  Future<List<Habit>> getActiveHabitsForDashboardWithDateRange({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
  }) async {
    try {
      final db = await _databaseService.database;
      
      String query = '''
        SELECT h.*, o.order_value
        FROM habits h
        INNER JOIN habit_display_order o ON h.id = o.habit_id
        WHERE h.is_archived = 0
      ''';
      
      List<dynamic> whereArgs = [];
      
      if (habitIds != null && habitIds.isNotEmpty) {
        final placeholders = habitIds.map((_) => '?').join(',');
        query += ' AND h.id IN ($placeholders)';
        whereArgs.addAll(habitIds);
      }
      
      query += ' ORDER BY o.order_value DESC';
      
      final results = await db.rawQuery(query, whereArgs);
      
      final habits = <Habit>[];
      for (final row in results) {
        final habit = await _rowToHabit(
          row, 
          startDate: startDate, 
          endDate: endDate,
          convertToLocal: true, // Dashboard needs local timezone for display
        );
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for dashboard (${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]})');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits for dashboard with date range: $e');
      return [];
    }
  }

  /// Get active habits for streak calculation with custom date range
  /// 
  /// [startDate] - Start date for completion data filtering
  /// [endDate] - End date for completion data filtering
  /// [habitIds] - Optional list of specific habit IDs to load
  Future<List<Habit>> getActiveHabitsForStreakCalculationWithDateRange({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
  }) async {
    try {
      final db = await _databaseService.database;
      
      String query = '''
        SELECT h.*, o.order_value
        FROM habits h
        INNER JOIN habit_display_order o ON h.id = o.habit_id
        WHERE h.is_archived = 0
      ''';
      
      List<dynamic> whereArgs = [];
      
      if (habitIds != null && habitIds.isNotEmpty) {
        final placeholders = habitIds.map((_) => '?').join(',');
        query += ' AND h.id IN ($placeholders)';
        whereArgs.addAll(habitIds);
      }
      
      query += ' ORDER BY o.order_value DESC';
      
      final results = await db.rawQuery(query, whereArgs);
      
      final habits = <Habit>[];
      for (final row in results) {
        final habit = await _rowToHabit(
          row, 
          startDate: startDate, 
          endDate: endDate,
          convertToLocal: false, // Streak calculation uses UTC dates
        );
        if (habit != null) {
          habits.add(habit);
        }
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for streak calculation (${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]})');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habits for streak calculation with date range: $e');
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
      
      // Get just the goal field - don't load all completion data!
      final db = await _databaseService.database;
      final goalResult = await db.query(
        'habits',
        columns: ['target_goal'],
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      if (goalResult.isEmpty) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }
      
      final goal = goalResult.first['target_goal'] as int;
      
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
              'goal_at_completion': goal,
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
              'goal_at_completion': goal,
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
      
      // Get just the goal field - don't load all completion data!
      final db = await _databaseService.database;
      final goalResult = await db.query(
        'habits',
        columns: ['target_goal'],
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      if (goalResult.isEmpty) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }
      
      final goal = goalResult.first['target_goal'] as int;
      
      await _databaseService.transaction((txn) async {
        if (count > 0) {
          // Insert or update completion record
          await txn.insert(
            'habit_completions',
            {
              'habit_id': habitId,
              'completion_date': dateTimestamp,
              'completion_count': count,
              'goal_at_completion': goal,
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

  /// Add additional completions for a habit on a specific date (incremental)
  /// 
  /// This method adds new timestamps with the current time while preserving existing ones.
  /// Used when increasing completion count from a custom modal.
  Future<void> addAdditionalCompletions(String habitId, DateTime date, int additionalCount) async {
    if (additionalCount <= 0) {
      debugPrint('📝 No additional completions to add for habit $habitId');
      return;
    }
    
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateTimestamp = TimezoneUtils.toUtcTimestamp(normalizedDate);
      
      // Get just the goal field - don't load all completion data!
      final db = await _databaseService.database;
      final goalResult = await db.query(
        'habits',
        columns: ['target_goal'],
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      if (goalResult.isEmpty) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }
      
      final goal = goalResult.first['target_goal'] as int;
      
      await _databaseService.transaction((txn) async {
        // Update completion count in habit_completions table
        final existingRecord = await txn.query(
          'habit_completions',
          where: 'habit_id = ? AND completion_date = ?',
          whereArgs: [habitId, dateTimestamp],
        );
        
        if (existingRecord.isNotEmpty) {
          // Increment existing count
          await txn.update(
            'habit_completions',
            {
              'completion_count': (existingRecord.first['completion_count'] as int) + additionalCount,
              'goal_at_completion': goal,
            },
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateTimestamp],
          );
        } else {
          // Insert new record (shouldn't happen in normal flow, but handle gracefully)
          await txn.insert(
            'habit_completions',
            {
              'habit_id': habitId,
              'completion_date': dateTimestamp,
              'completion_count': additionalCount,
              'goal_at_completion': goal,
            },
          );
        }
        
        // Add new timestamp records with current time
        final currentTimestamp = TimezoneUtils.toUtcTimestampSeconds(VirtualDateService().currentDate);
        for (int i = 0; i < additionalCount; i++) {
          await txn.insert(
            'habit_completion_timestamps',
            {
              'habit_id': habitId,
              'completion_timestamp': currentTimestamp,
            },
          );
        }
      });
      
      debugPrint('✅ Added $additionalCount additional completions for habit $habitId on ${date.toIso8601String()}');
    } catch (e) {
      debugPrint('❌ Error adding additional completions: $e');
      rethrow;
    }
  }

  /// Remove newest completions for a habit on a specific date (LIFO)
  /// 
  /// This method removes the newest timestamps while preserving older ones.
  /// Used when decreasing completion count from a custom modal.
  Future<void> removeOldestCompletions(String habitId, DateTime date, int countToRemove) async {
    if (countToRemove <= 0) {
      debugPrint('📝 No completions to remove for habit $habitId');
      return;
    }
    
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
        
        if (completionRows.isEmpty) {
          debugPrint('⚠️ No completion record found for habit $habitId on ${date.toIso8601String()}');
          return;
        }
        
        final currentCount = completionRows.first['completion_count'] as int;
        final newCount = currentCount - countToRemove;
        
        if (newCount < 0) {
          debugPrint('⚠️ Cannot remove $countToRemove completions from $currentCount (would result in negative count)');
          return;
        }
        
        // Calculate the full day range for timestamp operations
        final startOfDay = TimezoneUtils.toUtcTimestampSeconds(normalizedDate);
        final endOfDay = TimezoneUtils.toUtcTimestampSeconds(
          DateTime(normalizedDate.year, normalizedDate.month, normalizedDate.day, 23, 59, 59)
        );
        
        // Get newest timestamps to remove (LIFO - Last In, First Out)
        // We want to remove the newest timestamps, so we order by completion_timestamp DESC
        final timestampsToRemove = await txn.rawQuery('''
          SELECT id FROM habit_completion_timestamps 
          WHERE habit_id = ? AND completion_timestamp >= ? AND completion_timestamp <= ?
          ORDER BY completion_timestamp DESC
          LIMIT ?
        ''', [habitId, startOfDay, endOfDay, countToRemove]);
        
        if (timestampsToRemove.length < countToRemove) {
          debugPrint('⚠️ Only found ${timestampsToRemove.length} timestamps to remove, requested $countToRemove');
        }
        
        // Remove the newest timestamps
        for (final timestampRow in timestampsToRemove) {
          await txn.delete(
            'habit_completion_timestamps',
            where: 'id = ?',
            whereArgs: [timestampRow['id']],
          );
        }
        
        // Update completion count
        if (newCount > 0) {
          await txn.update(
            'habit_completions',
            {
              'completion_count': newCount,
            },
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateTimestamp],
          );
        } else {
          // Remove completion record if count reaches 0
          await txn.delete(
            'habit_completions',
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateTimestamp],
          );
        }
      });
      
      debugPrint('✅ Removed $countToRemove newest completions for habit $habitId on ${date.toIso8601String()}');
    } catch (e) {
      debugPrint('❌ Error removing newest completions: $e');
      rethrow;
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
        
        // Position at top (restored habits go to top)
        final topOrder = await _getNextTopOrderValue(txn);
        
        // Use INSERT OR REPLACE to handle both new and existing records
        await txn.rawInsert('''
          INSERT OR REPLACE INTO habit_display_order (habit_id, order_value, created_at)
          VALUES (?, ?, ?)
        ''', [habitId, topOrder, TimezoneUtils.getCurrentUtcTimestamp()]);
      });
      
      debugPrint('💾 Unarchived habit $habitId and positioned at top');
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
      final now = VirtualDateService().currentDate;
      
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
  
  /// Convert database row to Habit object with intelligent data loading
  Future<Habit?> _rowToHabit(
    Map<String, dynamic> row, {
    DateTime? startDate,
    DateTime? endDate,
    bool convertToLocal = true, // Default to local conversion for display
    bool loadCompletions = true, // Default to loading completions
  }) async {
    try {
      final completions = <DateTime, CompletionRecord>{};
      
      // Get database connection
      final db = await _databaseService.database;
      
      // Only load completions if requested
      if (loadCompletions) {
        // Load completions with optional date filtering
        String whereClause = 'habit_id = ?';
        List<dynamic> whereArgs = [row['id']];
        
        if (startDate != null && endDate != null) {
          whereClause += ' AND completion_date >= ? AND completion_date <= ?';
          whereArgs.addAll([
            TimezoneUtils.toUtcTimestamp(startDate),
            TimezoneUtils.toUtcTimestamp(endDate),
          ]);
        }
        
        final completionRows = await db.query(
          'habit_completions',
          where: whereClause,
          whereArgs: whereArgs,
        );
        
        // Log completion loading with context
        if (completionRows.length > 10) {
          debugPrint('📅 Loading ${completionRows.length} completion records for habit ${row['id']} (${startDate?.toIso8601String().split('T')[0] ?? 'all'} to ${endDate?.toIso8601String().split('T')[0] ?? 'all'})');
        } else {
          debugPrint('📅 Loading ${completionRows.length} completion records for habit ${row['id']}');
        }
        
        for (final completionRow in completionRows) {
          final date = convertToLocal 
              ? TimezoneUtils.fromUtcTimestamp(
                  completionRow['completion_date'] as int,
                  context: 'Habit ${row['id']} completion date',
                  caller: '_rowToHabit'
                )
              : DateTime.fromMillisecondsSinceEpoch(completionRow['completion_date'] as int, isUtc: true);
          
          final count = completionRow['completion_count'] as int;
          final goalAtCompletion = completionRow['goal_at_completion'] as int;
          completions[date] = CompletionRecord(
            count: count,
            goalAtCompletion: goalAtCompletion,
          );
        }
      } else {
        debugPrint('📅 Skipping completion data for habit ${row['id']} (minimal data mode)');
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
          return TimezoneUtils.fromUtcTimestamp(
            row['created_at'] as int,
            context: 'Habit ${row['id']} creation date',
            caller: '_rowToHabit'
          );
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
      
      // Get all active habits with minimal data (no completion data)
      final allHabits = await getActiveHabitsForReordering();
      
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

  /// Gets completion data for a habit within a date range
  /// 
  /// [habitId] - ID of the habit
  /// [startDate] - Start date for completion data
  /// [endDate] - End date for completion data
  /// 
  /// Returns: Map of date -> CompletionRecord
  Future<Map<DateTime, CompletionRecord>> getCompletionDataForHabit(String habitId, DateTime startDate, DateTime endDate) async {
    try {
      final db = await _databaseService.database;
      
      final completionRows = await db.query(
        'habit_completions',
        where: 'habit_id = ? AND completion_date >= ? AND completion_date <= ?',
        whereArgs: [
          habitId,
          TimezoneUtils.toUtcTimestamp(startDate),
          TimezoneUtils.toUtcTimestamp(endDate),
        ],
      );
      
      final completions = <DateTime, CompletionRecord>{};
      for (final row in completionRows) {
        final date = TimezoneUtils.fromUtcTimestamp(
          row['completion_date'] as int,
          context: 'Habit $habitId completion date',
          caller: 'getCompletionDataForHabit'
        );
        final count = row['completion_count'] as int;
        final goalAtCompletion = row['goal_at_completion'] as int;
        completions[date] = CompletionRecord(
          count: count,
          goalAtCompletion: goalAtCompletion,
        );
      }
      
      debugPrint('📅 Loaded ${completions.length} completion records for habit $habitId (${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]})');
      return completions;
    } catch (e) {
      debugPrint('❌ Error getting completion data for habit $habitId: $e');
      return {};
    }
  }

  /// Calculates current streak for a habit using SQL
  /// 
  /// [habitId] - ID of the habit
  /// [asOfDate] - Date to calculate streak for
  /// 
  /// Returns: Current streak value
  Future<int> calculateCurrentStreak(String habitId, DateTime asOfDate) async {
    try {
      final db = await _databaseService.database;
      
      // Convert asOfDate to UTC timestamp
      final asOfTimestamp = TimezoneUtils.toUtcTimestamp(asOfDate);
      
      // Query to find the current streak by counting consecutive days backwards
      final query = '''
        WITH RECURSIVE streak_days AS (
          -- Start from the asOfDate
          SELECT ? as check_date, 0 as streak_count
          
          UNION ALL
          
          -- Recursively go backwards day by day
          SELECT 
            check_date - (24 * 60 * 60 * 1000), -- Subtract 1 day in milliseconds
            CASE 
              WHEN EXISTS (
                SELECT 1 FROM habit_completions 
                WHERE habit_id = ? 
                AND completion_date = check_date - (24 * 60 * 60 * 1000)
                AND completion_count > 0
              ) THEN streak_count + 1
              ELSE streak_count
            END
          FROM streak_days
          WHERE check_date > ? -- Stop when we go too far back (e.g., 1 year)
            AND streak_count < 1000 -- Prevent infinite recursion
        )
        SELECT MAX(streak_count) as max_streak
        FROM streak_days
        WHERE check_date <= ?
      ''';
      
      final result = await db.rawQuery(query, [
        asOfTimestamp, // Start date
        habitId,       // Habit ID for completion check
        asOfTimestamp - (365 * 24 * 60 * 60 * 1000), // Stop after 1 year
        asOfTimestamp  // End date
      ]);
      
      final streak = result.first['max_streak'] as int? ?? 0;
      debugPrint('📊 Calculated current streak for habit $habitId: $streak (as of ${asOfDate.toIso8601String().split('T')[0]})');
      return streak;
    } catch (e) {
      debugPrint('❌ Error calculating current streak for habit $habitId: $e');
      return 0;
    }
  }

  /// Calculates maximum streak for a habit using SQL
  /// 
  /// [habitId] - ID of the habit
  /// 
  /// Returns: Maximum streak value
  Future<int> calculateMaxStreak(String habitId) async {
    try {
      final db = await _databaseService.database;
      
      // Query to find the maximum streak by analyzing all completion data
      final query = '''
        WITH completion_dates AS (
          SELECT DISTINCT completion_date
          FROM habit_completions
          WHERE habit_id = ? AND completion_count > 0
          ORDER BY completion_date
        ),
        streak_groups AS (
          SELECT 
            completion_date,
            ROW_NUMBER() OVER (ORDER BY completion_date) as row_num,
            completion_date - (ROW_NUMBER() OVER (ORDER BY completion_date) * 24 * 60 * 60 * 1000) as streak_group
          FROM completion_dates
        ),
        streak_lengths AS (
          SELECT 
            streak_group,
            COUNT(*) as streak_length
          FROM streak_groups
          GROUP BY streak_group
        )
        SELECT MAX(streak_length) as max_streak
        FROM streak_lengths
      ''';
      
      final result = await db.rawQuery(query, [habitId]);
      final maxStreak = result.first['max_streak'] as int? ?? 0;
      debugPrint('📊 Calculated max streak for habit $habitId: $maxStreak');
      return maxStreak;
    } catch (e) {
      debugPrint('❌ Error calculating max streak for habit $habitId: $e');
      return 0;
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

  /// Import multiple habits with their completion data in a single transaction
  ///
  /// This method efficiently imports multiple habits with large amounts of completion data
  /// using batch operations and a single transaction for optimal performance.
  ///
  /// @param habits List of habits to import
  /// @param onProgress Optional callback for progress tracking
  /// @return Number of habits successfully imported
  Future<int> importHabits(List<Habit> habits, {Function(String habitName, double progress)? onProgress}) async {
    if (habits.isEmpty) {
      debugPrint('📥 No habits to import');
      return 0;
    }

    debugPrint('📥 Starting bulk import of ${habits.length} habits...');
    final stopwatch = Stopwatch()..start();

    try {
      int importedCount = 0;
      
      await _databaseService.transaction((txn) async {
        // Get the next top order value for all habits
        final topOrder = await _getNextTopOrderValue(txn);
        
        for (int i = 0; i < habits.length; i++) {
          final habit = habits[i];
          
          try {
            // Insert habit
            await txn.insert('habits', _habitToRow(habit));
            
            // Insert ordering record (new habits go to top)
            await txn.insert('habit_display_order', {
              'habit_id': habit.id,
              'order_value': topOrder + (habits.length - i) * 1000.0, // Space them out
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
            
            // Batch insert completion records and corresponding timestamps
            if (habit.completions.isNotEmpty) {
              final completionRows = habit.completions.entries.map((entry) => {
                'habit_id': habit.id,
                'completion_date': TimezoneUtils.toUtcTimestamp(entry.key),
                'completion_count': entry.value.count,
                'goal_at_completion': entry.value.goalAtCompletion,
              }).toList();

              // Use batch insert for better performance
              for (final row in completionRows) {
                await txn.insert('habit_completions', row);
              }

              // Insert one timestamp per completion
              for (final entry in habit.completions.entries) {
                final date = entry.key;
                final count = entry.value.count;

                // Generate timestamps throughout the day (one per completion)
                for (int j = 0; j < count; j++) {
                  final hour = 8 + (j * 2) % 12; // Spread throughout day
                  final minute = (j * 5) % 60;
                  final completionTime = DateTime(date.year, date.month, date.day, hour, minute);

                  await txn.insert('habit_completion_timestamps', {
                    'habit_id': habit.id,
                    'completion_timestamp': TimezoneUtils.toUtcTimestampSeconds(completionTime),
                  });
                }
              }
            }

            importedCount++;
            debugPrint('📥 Imported habit ${i + 1}/${habits.length}: ${habit.name}');
            
          } catch (e) {
            debugPrint('❌ Error importing habit ${habit.name}: $e');
            // Continue with other habits instead of failing the entire import
          }
        }
      });
      
      stopwatch.stop();
      debugPrint('✅ Bulk import completed: $importedCount/${habits.length} habits imported in ${stopwatch.elapsedMilliseconds}ms');
      
      return importedCount;
      
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Error during bulk import: $e');
      rethrow;
    }
  }

  /// Clear all existing habits and import new ones
  ///
  /// This method provides a clean slate for importing sample data by first
  /// clearing all existing habits and their related data.
  ///
  /// @param habits List of habits to import
  /// @return Number of habits successfully imported
  Future<int> clearAndImportHabits(List<Habit> habits) async {
    debugPrint('🗑️ Clearing all existing habits before import...');
    
    try {
      await _databaseService.transaction((txn) async {
        // Clear all related tables in correct order (respecting foreign keys)
        await txn.delete('habit_completion_timestamps');
        await txn.delete('habit_completions');
        await txn.delete('habit_reminders');
        await txn.delete('habit_display_order');
        await txn.delete('habits');
      });
      
      debugPrint('✅ All existing habits cleared');
      
      // Now import the new habits
      return await importHabits(habits);
      
    } catch (e) {
      debugPrint('❌ Error clearing and importing habits: $e');
      rethrow;
    }
  }
}
