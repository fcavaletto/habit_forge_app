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
  
  /// Get database instance for atomic operations
  Future<Database> get database => _databaseService.database;
  
  
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
        FROM habit_metadata h
        INNER JOIN habit_display_order o ON h.id = o.habit_id
        WHERE h.is_archived = 0
        ORDER BY o.order_value DESC
      ''');
      
      if (results.isEmpty) {
        debugPrint('📖 Retrieved 0 active habit_metadata for reordering');
      return [];
      }
      
      // Convert TEXT timestamp strings to DateTime objects
      final createdAtDates = results.map((row) {
        final timestampString = row['created_at'] as String;
        return TimezoneUtils.fromTimestampString(timestampString);
      }).toList();
      
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
          lightColorValue: row['light_color_value'] as int? ?? 4287137464, // Default to slate light
          darkColorValue: row['dark_color_value'] as int? ?? 4281546069, // Default to slate dark
          createdAt: createdAtDates[i], // From batch conversion
          completions: const {}, // Empty - not loading completion data
          iconName: row['icon_name'] as String? ?? 'check_circle',
          reminderTime: reminderTime,
          enableReminders: (row['enable_reminders'] as int? ?? 0) == 1,
          isArchived: (row['is_archived'] as int? ?? 0) == 1,
          orderValue: row['order_value'] as double?,
          frequencyDays: frequencyDays,
          targetGoal: row['target_goal'] as int? ?? 1,
          allowExceedGoal: (row['allow_exceed_goal'] as int? ?? 1) == 1,
        ));
      }
      
      debugPrint('📖 Retrieved ${habits.length} active habits for reordering (metadata only, batch converted)');
      return habits;
    } catch (e) {
      debugPrint('❌ Error getting active habit_metadata for reordering: $e');
      return [];
    }
  }




  
  Future<HabitSaveResult> saveHabit(Habit habit) async {
    try {
      debugPrint('💾 Saving habit to SQLite: ${habit.name}');
      
      // Check if this is an update or new habit
      final isUpdate = await habitExists(habit.id);
      
      // Check for duplicates using name + icon combination
      // Exclude current habit ID when updating
      final hasDuplicate = await hasDuplicateHabit(
        habit.name,
        habit.iconName,
        excludeHabitId: isUpdate ? habit.id : null,
      );
      if (hasDuplicate) {
        debugPrint('💾 Found duplicate habit with same name and icon');
        return HabitSaveResult.duplicate(habit.name);
      }
      
      if (isUpdate) {
        // Update existing habit
        await _databaseService.transaction((txn) async {
          // Update habit metadata (preserve created_at and order)
          final rowData = _habitToRow(habit);
          // Don't update created_at on updates
          rowData.remove('created_at');
          await txn.update(
            'habit_metadata',
            rowData,
            where: 'id = ?',
            whereArgs: [habit.id],
          );
          
          // Handle reminder updates
          // First, check if reminder exists
          final existingReminder = await txn.query(
            'habit_reminders',
            where: 'habit_id = ?',
            whereArgs: [habit.id],
          );
          
          if (habit.enableReminders && habit.reminderTime != null) {
            // Update or insert reminder
            if (existingReminder.isNotEmpty) {
              await txn.update(
                'habit_reminders',
                {
                  'reminder_time_hour': habit.reminderTime!.hour,
                  'reminder_time_minute': habit.reminderTime!.minute,
                  'enable_reminders': 1,
                },
                where: 'habit_id = ?',
                whereArgs: [habit.id],
              );
            } else {
              await txn.insert('habit_reminders', {
                'habit_id': habit.id,
                'reminder_time_hour': habit.reminderTime!.hour,
                'reminder_time_minute': habit.reminderTime!.minute,
                'enable_reminders': 1,
              });
            }
          } else {
            // Remove reminder if disabled
            if (existingReminder.isNotEmpty) {
              await txn.delete(
                'habit_reminders',
                where: 'habit_id = ?',
                whereArgs: [habit.id],
              );
            }
          }
          
          // Note: We don't update completion records here as they should be
          // updated separately via updatePastCompletionGoals() if needed.
          // Completions are only inserted here for new habits.
        });
        
        debugPrint('💾 Habit updated successfully in SQLite');
      } else {
        // Save new habit
        await _databaseService.transaction((txn) async {
          // Insert habit
          await txn.insert('habit_metadata', _habitToRow(habit));
          
          // Insert ordering record (new habit_metadata go to top)
          final topOrder = await _getNextTopOrderValue(txn);
          await txn.insert('habit_display_order', {
            'habit_id': habit.id,
            'order_value': topOrder,
            'created_at': TimezoneUtils.getCurrentTimestampString(),
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
            await txn.insert('daily_completions', {
              'habit_id': habit.id,
              'completion_date': TimezoneUtils.toDateString(entry.key),
              'completion_count': entry.value.count,
              'goal_at_completion': entry.value.goalAtCompletion,
            });
          }
        });
        
        debugPrint('💾 Habit saved successfully to SQLite');
      }
      
      return HabitSaveResult.success(habit);
    } catch (e) {
      debugPrint('❌ Error saving habit: $e');
      return HabitSaveResult.error('Failed to save habit: $e');
    }
  }
  
  /// Check if a habit exists by its ID (lightweight existence check)
  Future<bool> habitExists(String habitId) async {
    try {
      final db = await _databaseService.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM habit_metadata WHERE id = ?',
        [habitId],
      );
      
      final count = result.first['count'] as int;
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error checking habit existence: $e');
      return false;
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
      // Convert date to 'YYYY-MM-DD' string format
      final dateString = TimezoneUtils.toDateString(date);
      
      // Get just the goal field - don't load all completion data!
      final db = await _databaseService.database;
      final goalResult = await db.query(
        'habit_metadata',
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
          'daily_completions',
          where: 'habit_id = ? AND completion_date = ?',
          whereArgs: [habitId, dateString],
        );
        
        if (existingRecord.isNotEmpty) {
          // Increment existing count by the batch amount
          await txn.update(
            'daily_completions',
            {
              'completion_count': (existingRecord.first['completion_count'] as int) + count,
              'goal_at_completion': goal,
            },
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateString],
          );
        } else {
          // Insert new record with batch count
          await txn.insert(
            'daily_completions',
            {
              'habit_id': habitId,
              'completion_date': dateString,
              'completion_count': count,
              'goal_at_completion': goal,
            },
          );
        }
        
        // Add multiple timestamp records (one per completion)
        for (int i = 0; i < count; i++) {
          final timestampFormats = TimezoneUtils.toTripleFormat(date);
          await txn.insert(
            'completion_times',
            {
              'habit_id': habitId,
              'completion_time_text': timestampFormats['text'],
              'completion_time_int': timestampFormats['int'],
              'completion_hour': timestampFormats['hour'],
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
  
  
  



  /// Remove newest completions for a habit on a specific date (LIFO)
  /// 
  /// This method removes the newest timestamps while preserving older ones.
  /// Used when decreasing completion count from a custom modal or for exceedable habits.
  Future<void> removeNewestCompletions(String habitId, DateTime date, int countToRemove) async {
    if (countToRemove <= 0) {
      debugPrint('📝 No completions to remove for habit $habitId');
      return;
    }
    
    try {
      // Convert date to 'YYYY-MM-DD' string format
      final dateString = TimezoneUtils.toDateString(date);
      
      await _databaseService.transaction((txn) async {
        // Get current completion count
        final completionRows = await txn.query(
          'daily_completions',
          where: 'habit_id = ? AND completion_date = ?',
          whereArgs: [habitId, dateString],
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
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59);
        final startTimestamp = startOfDay.millisecondsSinceEpoch;
        final endTimestamp = endOfDay.millisecondsSinceEpoch;
        
        // Get newest timestamps to remove (LIFO - Last In, First Out)
        // We want to remove the newest timestamps, so we order by completion_time_int DESC
        final timestampsToRemove = await txn.rawQuery('''
          SELECT id FROM completion_times 
          WHERE habit_id = ? AND completion_time_int >= ? AND completion_time_int <= ?
          ORDER BY completion_time_int DESC
          LIMIT ?
        ''', [habitId, startTimestamp, endTimestamp, countToRemove]);
        
        if (timestampsToRemove.length < countToRemove) {
          debugPrint('⚠️ Only found ${timestampsToRemove.length} timestamps to remove, requested $countToRemove');
        }
        
        // Remove the newest timestamps
        for (final timestampRow in timestampsToRemove) {
          await txn.delete(
            'completion_times',
            where: 'id = ?',
            whereArgs: [timestampRow['id']],
          );
        }
        
        // Update completion count
        if (newCount > 0) {
          await txn.update(
            'daily_completions',
            {
              'completion_count': newCount,
            },
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateString],
          );
        } else {
          // Remove completion record if count reaches 0
          await txn.delete(
            'daily_completions',
            where: 'habit_id = ? AND completion_date = ?',
            whereArgs: [habitId, dateString],
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
          'habit_metadata',
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
          'habit_metadata',
          {'is_archived': 1},
          where: 'id = ?',
          whereArgs: [habitId],
        );
        
        // Remove from ordering table (archived habit_metadata don't need ordering)
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
        'habit_metadata',
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
          'habit_metadata',
          {'is_archived': 0},
          where: 'id = ?',
          whereArgs: [habitId],
        );
        
        // Position at top (restored habit_metadata go to top)
        final topOrder = await _getNextTopOrderValue(txn);
        
        // Use INSERT OR REPLACE to handle both new and existing records
        await txn.rawInsert('''
          INSERT OR REPLACE INTO habit_display_order (habit_id, order_value, created_at)
          VALUES (?, ?, ?)
        ''', [habitId, topOrder, TimezoneUtils.getCurrentTimestampString()]);
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
        'habit_metadata',
        where: 'id = ?',
        whereArgs: [habitId],
      );
      
      debugPrint('💾 Deleted habit $habitId');
    } catch (e) {
      debugPrint('❌ Error deleting habit: $e');
    }
  }
  
  
  
  Future<List<Habit>> getHabitsNeedingAttention() async {
    try {
      final habits = await getActiveHabitsForReordering();
      final now = VirtualDateService().currentDate;
      
      return habits.where((habit) {
        // Check for low completion rate
        if (habit.completionRate < 0.3) return true;
        
        // Check for recently broken streaks
        final yesterday = now.subtract(const Duration(days: 1));
        final wasGoalAchievedYesterday = habit.isGoalAchieved(yesterday);
        final isGoalAchievedToday = habit.isGoalAchieved(now);
        
        if (wasGoalAchievedYesterday && !isGoalAchievedToday) return true;
        
        // Check for habit_metadata not completed in the last week
        final lastWeek = now.subtract(const Duration(days: 7));
        final hasRecentCompletion = habit.completions.keys.any((date) => 
          date.isAfter(lastWeek) || date.isAtSameMomentAs(lastWeek)
        );
        
        if (!hasRecentCompletion) return true;
        
        return false;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting habit_metadata needing attention: $e');
      return [];
    }
  }
  
  
  
  /// Convert Habit object to database row
  Map<String, dynamic> _habitToRow(Habit habit) {
    return {
      'id': habit.id,
      'name': habit.name,
      'description': habit.description,
      'light_color_value': habit.lightColorValue,
      'dark_color_value': habit.darkColorValue,
      'icon_name': habit.iconName,
      'created_at': TimezoneUtils.toTimestampString(habit.createdAt),
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
  
  /// Reorder habit_metadata using fractional positioning
  Future<void> reorderHabits(String draggedId, int newPosition) async {
    try {
      final habits = await getActiveHabitsForReordering();
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
      debugPrint('❌ Error reordering habit_metadata: $e');
      rethrow;
    }
  }

  /// Reorder habit_metadata with filtering context - handles filtered views correctly
  Future<void> reorderHabitsInContext(
    String draggedId, 
    int newPosition, 
    List<String> visibleHabitIds
  ) async {
    try {
      debugPrint('🔄 Reordering habit $draggedId to position $newPosition in filtered context');
      debugPrint('📋 Visible habit_metadata: ${visibleHabitIds.join(', ')}');
      
      // Get all active habit_metadata with minimal data (no completion data)
      final allHabits = await getActiveHabitsForReordering();
      
      // Create a map for quick lookup
      final habitMap = {for (var h in allHabits) h.id: h};
      
      // Validate that dragged habit exists and is visible
      if (!visibleHabitIds.contains(draggedId)) {
        throw Exception('Dragged habit $draggedId is not in visible list');
      }
      
      // Get visible habit_metadata in their current order
      final visibleHabits = visibleHabitIds
          .map((id) => habitMap[id])
          .where((h) => h != null)
          .cast<Habit>()
          .toList();
      
      if (visibleHabits.length != visibleHabitIds.length) {
        throw Exception('Some visible habit_metadata not found in database');
      }
      
      double newOrderValue;
      
      if (newPosition == 0) {
        // Move to top of visible habit_metadata
        final topVisibleHabit = visibleHabits.first;
        final topOrder = topVisibleHabit.orderValue ?? 0.0;
        newOrderValue = topOrder + 1000.0; // Large gap above
        debugPrint('📍 Moving to top of visible habit_metadata (above ${topVisibleHabit.name})');
      } else if (newPosition >= visibleHabits.length - 1) {
        // Move to bottom of visible habit_metadata
        final bottomVisibleHabit = visibleHabits.last;
        final bottomOrder = bottomVisibleHabit.orderValue ?? 0.0;
        newOrderValue = bottomOrder - 1000.0; // Large gap below
        debugPrint('📍 Moving to bottom of visible habit_metadata (below ${bottomVisibleHabit.name})');
      } else {
        // Insert between visible habit_metadata
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
      debugPrint('❌ Error reordering habit_metadata in context: $e');
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
      final habits = await getActiveHabitsForReordering();
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
  /// It checks against active (non-archived) habit_metadata only.
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
        'habit_metadata',
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
  /// This method is used when editing existing habit_metadata to ensure the new
  /// name/icon combination doesn't conflict with other active habit_metadata.
  ///
  /// @param habitId The ID of the habit being edited
  /// @param newName The new name for the habit
  /// @param newIconName The new icon name for the habit
  /// @return true if the update is safe (no duplicates), false otherwise
  Future<bool> canUpdateHabit(String habitId, String newName, String newIconName) async {
    return !await hasDuplicateHabit(newName, newIconName, excludeHabitId: habitId);
  }

  /// Update goal_at_completion for all past completion records of a habit
  ///
  /// This method updates all daily_completions records for a habit to use the new
  /// target goal. This affects how past completions are evaluated for streaks and
  /// completion rates. Use this when the user wants to retroactively apply a new
  /// target goal to all past completions.
  ///
  /// @param habitId The ID of the habit to update
  /// @param newGoal The new target goal value to apply to all completion records
  /// @return Number of completion records updated
  Future<int> updatePastCompletionGoals(String habitId, int newGoal) async {
    try {
      debugPrint('🔄 Updating past completion goals for habit $habitId to $newGoal');
      
      final db = await _databaseService.database;
      
      // Get count of records that will be updated
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM daily_completions WHERE habit_id = ?',
        [habitId],
      );
      final recordCount = (countResult.first['count'] as int?) ?? 0;
      
      if (recordCount == 0) {
        debugPrint('⚠️ No completion records found for habit $habitId');
        return 0;
      }
      
      // Update all completion records in a single transaction
      await _databaseService.transaction((txn) async {
        await txn.update(
          'daily_completions',
          {'goal_at_completion': newGoal},
          where: 'habit_id = ?',
          whereArgs: [habitId],
        );
      });
      
      debugPrint('✅ Updated $recordCount completion records with new goal $newGoal');
      return recordCount;
    } catch (e) {
      debugPrint('❌ Error updating past completion goals: $e');
      rethrow;
    }
  }

  /// Get hourly completion distribution for a specific date range
  ///
  /// Analyzes completion timestamps to show when during the day completions occur.
  /// Returns a map where keys are hours (0-23) and values are completion counts.
  ///
  /// @param habitId The ID of the habit to analyze
  /// @param startDate The start date for the analysis (inclusive) - null for all time
  /// @param endDate The end date for the analysis (inclusive) - null for all time
  /// @return Map<int, int> where key = hour (0-23), value = completion count
  Future<Map<int, int>> getHourlyCompletions(String habitId, DateTime? startDate, DateTime? endDate) async {
    try {
      final db = await _databaseService.database;
      
      // Build query dynamically based on whether date range is provided
      String whereClause = 'WHERE habit_id = ?';
      List<dynamic> whereArgs = [habitId];
      
      if (startDate != null && endDate != null) {
        // Convert dates to INTEGER timestamps for fast numeric comparison
        final startTimestamp = startDate.millisecondsSinceEpoch;
        final endTimestamp = endDate.millisecondsSinceEpoch;
        
        whereClause += ' AND completion_time_int >= ? AND completion_time_int <= ?';
        whereArgs.addAll([startTimestamp, endTimestamp]);
        
        debugPrint('📊 [HourlyQuery] Querying hourly completions for $habitId');
        debugPrint('📅 [HourlyQuery] Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
        debugPrint('🕒 [HourlyQuery] INTEGER range: $startTimestamp to $endTimestamp');
      } else {
        debugPrint('📊 [HourlyQuery] Querying total hourly completions for $habitId');
      }
      
      final result = await db.rawQuery('''
        SELECT 
          completion_hour as hour,
          COUNT(*) as count
        FROM completion_times 
        $whereClause
        GROUP BY completion_hour
        ORDER BY completion_hour
      ''', whereArgs);
      
      // Convert result to Map<int, int> and ensure all hours (0-23) are represented
      final hourlyCompletions = <int, int>{};
      for (int hour = 0; hour < 24; hour++) {
        hourlyCompletions[hour] = 0;
      }
      
      for (final row in result) {
        // Add null-safety checks to prevent casting errors
        final hourValue = row['hour'];
        final countValue = row['count'];
        
        if (hourValue != null && countValue != null) {
          final hour = hourValue as int;
          final count = countValue as int;
          hourlyCompletions[hour] = count;
          debugPrint('🕐 [HourlyQuery] Hour $hour: $count completions');
        } else {
          debugPrint('⚠️ [HourlyQuery] Skipping row with null values: hour=$hourValue, count=$countValue');
        }
      }
      
      final activeHours = hourlyCompletions.entries.where((e) => e.value > 0).length;
      if (startDate != null && endDate != null) {
        debugPrint('📊 Hourly completions for $habitId: $activeHours hours with completions');
      } else {
        debugPrint('📊 All-time hourly completions for $habitId: $activeHours hours with completions');
      }
      return hourlyCompletions;
    } catch (e) {
      debugPrint('❌ Error getting hourly completions: $e');
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
      
      // Convert dates to 'YYYY-MM-DD' strings
      final startDateString = TimezoneUtils.toDateString(startDate);
      final endDateString = TimezoneUtils.toDateString(endDate);
      
      final completionRows = await db.query(
        'daily_completions',
        where: 'habit_id = ? AND completion_date >= ? AND completion_date <= ?',
        whereArgs: [
          habitId,
          startDateString,
          endDateString,
        ],
      );
      
      final completions = <DateTime, CompletionRecord>{};
      for (final row in completionRows) {
        final dateString = row['completion_date'] as String;
        final date = TimezoneUtils.fromDateString(dateString);
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
  /// @param habitId The habit ID
  /// @param asOfDate The date to calculate streak as of
  /// @return Current streak value
  Future<int> calculateCurrentStreak(String habitId, DateTime asOfDate) async {
    try {
      final db = await _databaseService.database;
      
      // Convert asOfDate to date string for comparison
      final asOfDateString = TimezoneUtils.toDateString(asOfDate);
      
      debugPrint('📊 [STREAK] Calculating current streak for habit $habitId as of $asOfDateString');
      
      // Query to find the current streak by counting consecutive days backwards
      // We'll use a simpler approach: get all completion dates and count backwards
      final completionRows = await db.query(
        'daily_completions',
        columns: ['completion_date'],
        where: 'habit_id = ? AND completion_count > 0',
        whereArgs: [habitId],
        orderBy: 'completion_date DESC',
      );
      
      if (completionRows.isEmpty) {
        debugPrint('📊 [STREAK] No completions found for habit $habitId');
        return 0;
      }
      
      // Convert completion dates to DateTime objects and sort them
      final completionDates = completionRows
          .map((row) => TimezoneUtils.fromDateString(row['completion_date'] as String))
          .toList();
      
      // Sort by date descending (newest first)
      completionDates.sort((a, b) => b.compareTo(a));
      
      // Calculate streak by counting consecutive days backwards from asOfDate
      int streak = 0;
      DateTime currentDate = DateTime(asOfDate.year, asOfDate.month, asOfDate.day);
      
      for (final completionDate in completionDates) {
        final completionDay = DateTime(completionDate.year, completionDate.month, completionDate.day);
        
        // Check if this completion is on the current streak day
        if (completionDay.isAtSameMomentAs(currentDate)) {
          streak++;
          // Move to previous day
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else if (completionDay.isBefore(currentDate)) {
          // If there's a gap, streak is broken
          break;
        }
        // If completionDay.isAfter(currentDate), skip it (future completion)
      }
      
      debugPrint('📊 [STREAK] Calculated current streak for habit $habitId: $streak (as of $asOfDateString)');
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
      const query = '''
        WITH completion_dates AS (
          SELECT DISTINCT completion_date
          FROM daily_completions
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
      
      // Convert date to INTEGER timestamps for fast numeric comparison
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59);
      final startTimestamp = startOfDay.millisecondsSinceEpoch;
      final endTimestamp = endOfDay.millisecondsSinceEpoch;
      
      debugPrint('📅 [DayQuery] Querying completion timestamps for $habitId on ${date.toIso8601String()}');
      debugPrint('🕒 [DayQuery] INTEGER range: $startTimestamp to $endTimestamp');
      
      final result = await db.rawQuery('''
        SELECT completion_time_text
        FROM completion_times 
        WHERE habit_id = ? 
          AND completion_time_int >= ? 
          AND completion_time_int <= ?
        ORDER BY completion_time_int ASC
      ''', [habitId, startTimestamp, endTimestamp]);
      
      // Convert TEXT timestamps back to DateTime
      final timestamps = result.map((row) {
        final timestampString = row['completion_time_text'] as String;
        return TimezoneUtils.fromTimestampString(timestampString);
      }).toList();
      
      debugPrint('📊 [DayQuery] Found ${timestamps.length} completions for $habitId on ${date.toIso8601String()}');
      return timestamps;
    } catch (e) {
      debugPrint('❌ Error getting completion timestamps for day: $e');
      rethrow;
    }
  }

  /// Import multiple habit_metadata with their completion data in a single transaction
  ///
  /// This method efficiently imports multiple habit_metadata with large amounts of completion data
  /// using batch operations and a single transaction for optimal performance.
  ///
  /// @param habit_metadata List of habit_metadata to import
  /// @param onProgress Optional callback for progress tracking
  /// @return Number of habit_metadata successfully imported
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
        // Get the next top order value for all habit_metadata
        final topOrder = await _getNextTopOrderValue(txn);
        
        for (int i = 0; i < habits.length; i++) {
          final habit = habits[i];
          
          try {
            // Insert habit
            await txn.insert('habit_metadata', _habitToRow(habit));
            
            // Insert ordering record (new habit_metadata go to top)
            await txn.insert('habit_display_order', {
              'habit_id': habit.id,
              'order_value': topOrder + (habits.length - i) * 1000.0, // Space them out
              'created_at': TimezoneUtils.getCurrentTimestampString(),
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
                'completion_date': TimezoneUtils.toDateString(entry.key),
                'completion_count': entry.value.count,
                'goal_at_completion': entry.value.goalAtCompletion,
              }).toList();

              // Use batch insert for better performance with OR REPLACE to handle duplicates
              for (final row in completionRows) {
                await txn.rawInsert(
                  'INSERT OR REPLACE INTO daily_completions (habit_id, completion_date, completion_count, goal_at_completion) VALUES (?, ?, ?, ?)',
                  [row['habit_id'], row['completion_date'], row['completion_count'], row['goal_at_completion']],
                );
              }

              // Insert one timestamp per completion using the actual completion times
              for (final entry in habit.completions.entries) {
                final completionDateTime = entry.key; // Use the actual DateTime from sample data
                final count = entry.value.count;

                // Insert multiple timestamps for the same day if count > 1
                // Spread them throughout the day with small increments
                for (int j = 0; j < count; j++) {
                  final timestampDateTime = DateTime(
                    completionDateTime.year,
                    completionDateTime.month,
                    completionDateTime.day,
                    completionDateTime.hour,
                    completionDateTime.minute,
                    completionDateTime.second + j, // Small increment for multiple completions
                  );
                  
                  final timestampFormats = TimezoneUtils.toTripleFormat(timestampDateTime);
                  await txn.rawInsert(
                    'INSERT OR REPLACE INTO completion_times (habit_id, completion_time_text, completion_time_int, completion_hour) VALUES (?, ?, ?, ?)',
                    [habit.id, timestampFormats['text'], timestampFormats['int'], timestampFormats['hour']],
                  );
                }
              }
            }

            importedCount++;
            debugPrint('📥 Imported habit ${i + 1}/${habits.length}: ${habit.name}');
            
          } catch (e) {
            debugPrint('❌ Error importing habit ${habit.name}: $e');
            // Continue with other habit_metadata instead of failing the entire import
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

  /// Clear all existing habit_metadata and import new ones
  ///
  /// This method provides a clean slate for importing sample data by first
  /// clearing all existing habit_metadata and their related data.
  ///
  /// @param habit_metadata List of habit_metadata to import
  /// @return Number of habit_metadata successfully imported
  Future<int> clearAndImportHabits(List<Habit> habits) async {
    debugPrint('🗑️ Clearing all existing habit_metadata before import...');
    
    try {
      await _databaseService.transaction((txn) async {
        // Clear all related tables in correct order (respecting foreign keys)
        await txn.delete('completion_times');
        await txn.delete('daily_completions');
        await txn.delete('habit_reminders');
        await txn.delete('habit_display_order');
        await txn.delete('habit_metadata');
      });
      
      debugPrint('✅ All existing habit_metadata cleared');
      
      // Now import the new habit_metadata
      return await importHabits(habits);
      
    } catch (e) {
      debugPrint('❌ Error clearing and importing habit_metadata: $e');
      rethrow;
    }
  }
}
