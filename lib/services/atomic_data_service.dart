import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/habit_metadata_cache_service.dart';
import '../utils/timezone_utils.dart';
import 'caching_service.dart';
import 'row_processor.dart';

/// Context information for logging and debugging data access operations
class DataAccessContext {
  final String component; // Which UI component is making the request
  final String operation; // What operation is being performed
  final Map<String, dynamic> parameters; // Additional context parameters
  final DateTime? timestamp;

  DataAccessContext({
    required this.component,
    required this.operation,
    this.parameters = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'DataAccessContext(component: $component, operation: $operation, params: $parameters)';
  }
}

/// Result wrapper for atomic data operations
class DataAccessResult<T> {
  final T? data;  // Made nullable to support failure cases
  final bool success;
  final String? errorMessage;
  final DataAccessContext context;
  final Duration executionTime;

  const DataAccessResult.success({
    required T this.data,  // Still requires non-null data for success
    required this.context,
    required this.executionTime,
  })  : success = true,
        errorMessage = null;

  const DataAccessResult.failure({
    required this.errorMessage,
    required this.context,
    required this.executionTime,
  })  : success = false,
        data = null;  // No cast needed - data is now nullable

  @override
  String toString() {
    return 'DataAccessResult(success: $success, executionTime: ${executionTime.inMilliseconds}ms, context: $context)';
  }
}

/// Exception types for different kinds of data access failures
abstract class DataAccessException implements Exception {
  final String message;
  final DataAccessContext context;

  const DataAccessException(this.message, this.context);

  @override
  String toString() => 'DataAccessException: $message (context: $context)';
}

class DatabaseConnectionException extends DataAccessException {
  const DatabaseConnectionException(super.message, super.context);
}

class DataValidationException extends DataAccessException {
  const DataValidationException(super.message, super.context);
}

class NotFoundException extends DataAccessException {
  const NotFoundException(super.message, super.context);
}

/// Interface defining atomic data access operations
///
/// These operations are the fundamental building blocks for all habit data access.
/// Each method performs a single, well-defined operation with comprehensive logging.
abstract class IAtomicDataService {
  /// Get habit metadata without completion data
  ///
  /// [includeArchived] - Whether to include archived habits (default: false)
  /// [habitIds] - Optional list of specific habit IDs to retrieve
  /// [context] - Logging context for the operation
  ///
  /// Returns metadata for habits including: id, name, description, color, icon,
  /// creation date, frequency settings, target goals, and display order.
  /// 
  /// This is the consolidated method that replaces:
  /// - getHabitFeatures()
  /// - getAllHabitsIncludingArchived() (when combined with getCompletionRecords)
  /// - getActiveHabitsForReordering() (repository method)
  Future<DataAccessResult<List<HabitMetadata>>> getHabitMetadata({
    bool includeArchived = false,
    List<String>? habitIds,
    required DataAccessContext context,
  });



  /// Get completion records for habits within a date range
  ///
  /// [startDate] - Start of date range (inclusive)
  /// [endDate] - End of date range (inclusive)
  /// [habitIds] - Optional list of specific habit IDs
  /// [context] - Logging context for the operation
  ///
  /// Returns map of habit ID -> date -> CompletionRecord (includes count and goalAtCompletion)
  /// Throws DataValidationException if date range is invalid
  Future<DataAccessResult<Map<String, Map<DateTime, CompletionRecord>>>> getCompletionRecords({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
    required DataAccessContext context,
  });

  /// Get detailed completion records with timestamps
  ///
  /// [startDate] - Start of date range (inclusive)
  /// [endDate] - End of date range (inclusive)
  /// [habitIds] - Optional list of specific habit IDs
  /// [context] - Logging context for the operation
  ///
  /// Returns map of habit ID -> date -> CompletionRecord
  /// Throws DataValidationException if date range is invalid
  Future<DataAccessResult<Map<String, Map<DateTime, CompletionRecord>>>> getCompletionTimestamps({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
    required DataAccessContext context,
  });

  /// Get individual completion timestamps for a specific day
  ///
  /// [habitId] - ID of the habit to get timestamps for
  /// [date] - Date to get timestamps for (will query entire day)
  /// [context] - Logging context for the operation
  ///
  /// Returns list of individual completion timestamps for the day
  Future<DataAccessResult<List<DateTime>>> getIndividualCompletionTimestamps({
    required String habitId,
    required DateTime date,
    required DataAccessContext context,
  });

  /// Calculate maximum streak for habits
  ///
  /// [habitIds] - Optional list of specific habit IDs
  /// [activeDaysOnly] - If true, only count active days for each habit's frequency
  /// [context] - Logging context for the operation
  ///
  /// Returns map of habit ID -> maximum streak length
  Future<DataAccessResult<Map<String, int>>> getMaxStreak({
    List<String>? habitIds,
    bool activeDaysOnly = false,
    required DataAccessContext context,
  });

  /// Calculate current streak for habits as of a specific date
  ///
  /// [asOfDate] - Date to calculate streak for
  /// [habitIds] - Optional list of specific habit IDs
  /// [activeDaysOnly] - If true, only count active days for each habit's frequency
  /// [context] - Logging context for the operation
  ///
  /// Returns map of habit ID -> current streak length
  Future<DataAccessResult<Map<String, int>>> getCurrentStreak({
    required DateTime asOfDate,
    List<String>? habitIds,
    bool activeDaysOnly = false,
    required DataAccessContext context,
  });

  /// Add completions for a habit on a specific date
  ///
  /// [habitId] - ID of the habit to add completions for
  /// [date] - Date to add completions for
  /// [count] - Number of completions to add (must be positive)
  /// [context] - Logging context for the operation
  ///
  /// Also creates corresponding timestamp records
  /// Throws DataValidationException if count is not positive
  Future<DataAccessResult<void>> addCompletions({
    required String habitId,
    required DateTime date,
    required int count,
    required DataAccessContext context,
  });

  /// Remove completions for a habit on a specific date
  ///
  /// [habitId] - ID of the habit to remove completions for
  /// [date] - Date to remove completions for
  /// [count] - Number of completions to remove (must be positive)
  /// [context] - Logging context for the operation
  ///
  /// Also removes corresponding timestamp records
  /// Throws DataValidationException if count is not positive
  Future<DataAccessResult<void>> removeCompletions({
    required String habitId,
    required DateTime date,
    required int count,
    required DataAccessContext context,
  });

  /// Create a new habit
  ///
  /// [habitData] - Complete habit data for creation
  /// [context] - Logging context for the operation
  ///
  /// Returns the created habit with assigned ID
  /// Throws DataValidationException if habit data is invalid
  Future<DataAccessResult<Habit>> createHabit({
    required HabitData habitData,
    required DataAccessContext context,
  });

  /// Archive a habit (move to archived state)
  ///
  /// [habitId] - ID of the habit to archive
  /// [context] - Logging context for the operation
  ///
  /// Returns success/failure status
  Future<DataAccessResult<void>> archiveHabit({
    required String habitId,
    required DataAccessContext context,
  });

  /// Unarchive a habit (restore from archived state)
  ///
  /// [habitId] - ID of the habit to unarchive
  /// [context] - Logging context for the operation
  ///
  /// Returns success/failure status
  Future<DataAccessResult<void>> unarchiveHabit({
    required String habitId,
    required DataAccessContext context,
  });

  /// Delete a habit and all its associated data
  ///
  /// [habitId] - ID of the habit to delete
  /// [context] - Logging context for the operation
  ///
  /// Throws NotFoundException if habit doesn't exist
  Future<DataAccessResult<void>> deleteHabit({
    required String habitId,
    required DataAccessContext context,
  });

  /// Get habits that need attention (overdue, missed goals, etc.)
  ///
  /// [context] - Logging context for the operation
  ///
  /// Returns habits that need user attention
  Future<DataAccessResult<List<Habit>>> getHabitsNeedingAttention({
    required DataAccessContext context,
  });

  /// Check if a habit with the same name and icon already exists
  ///
  /// [name] - Habit name to check
  /// [iconName] - Icon name to check
  /// [excludeHabitId] - Optional habit ID to exclude from check
  /// [context] - Logging context for the operation
  ///
  /// Returns true if duplicate exists, false otherwise
  Future<DataAccessResult<bool>> hasDuplicateHabit({
    required String name,
    required String iconName,
    String? excludeHabitId,
    required DataAccessContext context,
  });

  /// Check if a habit can be updated without conflicts
  ///
  /// [habitId] - ID of the habit to update
  /// [newName] - New name for the habit
  /// [newIconName] - New icon name for the habit
  /// [context] - Logging context for the operation
  ///
  /// Returns true if update is allowed, false otherwise
  Future<DataAccessResult<bool>> canUpdateHabit({
    required String habitId,
    required String newName,
    required String newIconName,
    required DataAccessContext context,
  });

  /// Import sample habits for new users
  ///
  /// [sampleHabits] - List of sample habits to import
  /// [clearExisting] - Whether to clear existing habits first
  /// [onProgress] - Optional progress callback
  /// [context] - Logging context for the operation
  ///
  /// Returns number of habits imported
  Future<DataAccessResult<int>> importSampleHabits({
    required List<Habit> sampleHabits,
    bool clearExisting = false,
    Function(int)? onProgress,
    required DataAccessContext context,
  });

  /// Reorder habits by moving one habit to a new position
  ///
  /// [draggedId] - ID of the habit being moved
  /// [newPosition] - New position for the habit
  /// [context] - Logging context for the operation
  Future<DataAccessResult<void>> reorderHabits({
    required String draggedId,
    required int newPosition,
    required DataAccessContext context,
  });

  /// Reorder habits with filtering context - handles filtered views correctly
  ///
  /// [draggedId] - ID of the habit being moved
  /// [newPosition] - New position in the filtered list
  /// [visibleHabitIds] - List of habit IDs currently visible in the filtered view
  /// [context] - Logging context for the operation
  Future<DataAccessResult<void>> reorderHabitsInContext({
    required String draggedId,
    required int newPosition,
    required List<String> visibleHabitIds,
    required DataAccessContext context,
  });

  /// Normalize order values to prevent gaps
  ///
  /// [context] - Logging context for the operation
  Future<DataAccessResult<void>> normalizeOrderValues({
    required DataAccessContext context,
  });


  /// Get hourly completion data for histogram analysis
  ///
  /// [habitId] - ID of the habit to analyze
  /// [startDate] - Start date for the data
  /// [endDate] - End date for the data
  /// [context] - Logging context for the operation
  ///
  /// Returns map of hour -> completion count for histogram display
  Future<DataAccessResult<Map<int, int>>> getHourlyCompletions({
    required String habitId,
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  });

  /// Modify habit metadata
  ///
  /// [habitId] - ID of the habit to modify
  /// [updates] - Map of fields to update (name, description, color, etc.)
  /// [context] - Logging context for the operation
  ///
  /// Throws NotFoundException if habit doesn't exist
  /// Throws DataValidationException if updates are invalid
  Future<DataAccessResult<Habit>> modifyHabit({
    required String habitId,
    required Map<String, dynamic> updates,
    required DataAccessContext context,
  });

  /// Get performance statistics for monitoring
  Future<Map<String, dynamic>> getPerformanceStats();

  /// Clear all cached data (for testing/debugging)
  Future<void> clearCache();
}

/// Interface for atomic row processing operations
///
/// Replaces the monolithic _rowToHabit method with focused, testable operations
abstract class IRowProcessor {
  /// Process basic habit metadata from database row
  ///
  /// [row] - Database row containing habit table data
  /// [context] - Logging context for the operation
  ///
  /// Returns processed metadata without completions, reminders, or frequency data
  Future<DataAccessResult<HabitMetadata>> processHabitMetadata({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  });

  /// Process completion data for a habit with optional date filtering
  ///
  /// [habitId] - ID of the habit to load completions for
  /// [config] - Loading configuration including date range
  /// [context] - Logging context for the operation
  ///
  /// Returns processed completion data or empty map if no completions loaded
  Future<DataAccessResult<ProcessedCompletions>> processCompletions({
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  });

  /// Process reminder settings for a habit
  ///
  /// [habitId] - ID of the habit to load reminders for
  /// [context] - Logging context for the operation
  ///
  /// Returns processed reminder settings or defaults if none found
  Future<DataAccessResult<ProcessedReminders>> processReminders({
    required String habitId,
    required DataAccessContext context,
  });

  /// Process frequency days for a habit
  ///
  /// [row] - Database row containing frequency_days JSON
  /// [context] - Logging context for the operation
  ///
  /// Returns processed frequency data or defaults if parsing fails
  Future<DataAccessResult<ProcessedFrequency>> processFrequencyDays({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  });

  /// Assemble complete Habit object from processed components
  ///
  /// [metadata] - Basic habit metadata
  /// [completions] - Optional completion data
  /// [reminders] - Optional reminder settings
  /// [frequency] - Optional frequency settings
  /// [context] - Logging context for the operation
  ///
  /// Returns fully assembled Habit object ready for use
  Future<DataAccessResult<Habit>> assembleHabit({
    required HabitMetadata metadata,
    ProcessedCompletions? completions,
    ProcessedReminders? reminders,
    ProcessedFrequency? frequency,
    required DataAccessContext context,
  });

  /// Process complete habit from database row (convenience method)
  ///
  /// [row] - Database row containing habit data
  /// [habitId] - ID of the habit (for loading completions and reminders)
  /// [config] - Loading configuration
  /// [context] - Logging context for the operation
  ///
  /// This method combines all atomic operations for backward compatibility
  Future<DataAccessResult<Habit>> processHabitFromRow({
    required Map<String, dynamic> row,
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  });
}

/// Atomic Data Service Implementation
///
/// This service provides the core atomic operations for habit data access.
/// It wraps the existing repository with proper error handling, logging, and caching.
class AtomicDataService implements IAtomicDataService {
  final SqliteHabitRepository _repository;
  final ICachingService _cache;
  final IRowProcessor _rowProcessor;

  AtomicDataService({
    required SqliteHabitRepository repository,
    required ICachingService cache,
    required IRowProcessor rowProcessor,
  })  : _repository = repository,
        _cache = cache,
        _rowProcessor = rowProcessor;

  @override
  Future<DataAccessResult<List<HabitMetadata>>> getHabitMetadata({
    bool includeArchived = false,
    List<String>? habitIds,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getHabitMetadata called: ${context.component}.${context.operation} (includeArchived: $includeArchived, habitIds: ${habitIds?.length ?? 'all'})');

      // Build optimized SQL query
      final db = await _repository.database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (!includeArchived) {
        whereClause = 'WHERE h.is_archived = 0';
      }
      
      if (habitIds != null && habitIds.isNotEmpty) {
        final placeholders = habitIds.map((_) => '?').join(',');
        whereClause += whereClause.isEmpty ? 'WHERE' : ' AND';
        whereClause += ' h.id IN ($placeholders)';
        whereArgs.addAll(habitIds);
      }
      
      final results = await db.rawQuery('''
        SELECT h.*, o.order_value
        FROM habit_metadata h
        LEFT JOIN habit_display_order o ON h.id = o.habit_id
        $whereClause
        ORDER BY o.order_value DESC, h.created_at DESC
      ''', whereArgs);

      if (results.isEmpty) {
        debugPrint('📖 Retrieved 0 habits for metadata');
      return DataAccessResult.success(
          data: <HabitMetadata>[],
        context: context,
        executionTime: stopwatch.elapsed,
      );
      }

      // Convert TEXT timestamp strings to DateTime objects
      final createdAtDates = results.map((row) {
        final timestampString = row['created_at'] as String;
        return TimezoneUtils.fromTimestampString(timestampString);
      }).toList();

      // Convert to metadata objects
      final metadata = <HabitMetadata>[];
      for (int i = 0; i < results.length; i++) {
        final row = results[i];
        
        // Parse reminder time
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
        
        metadata.add(HabitMetadata(
          id: row['id'] as String,
          name: row['name'] as String,
          description: row['description'] as String? ?? '',
          colorIndex: row['color_index'] as int? ?? 0,
          createdAt: createdAtDates[i],
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

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getHabitMetadata completed: ${metadata.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: metadata,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getHabitMetadata failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get habit metadata: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }




  @override
  Future<DataAccessResult<Map<String, Map<DateTime, CompletionRecord>>>> getCompletionRecords({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Validate date range
      if (startDate.isAfter(endDate)) {
        throw DataValidationException(
          'Start date cannot be after end date',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] getCompletionRecords called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final metadataResult = await getHabitMetadata(
        habitIds: habitIds,
        context: DataAccessContext(
          component: 'AtomicDataService',
          operation: 'getCompletionRecords',
        ),
      );

      if (!metadataResult.success || metadataResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get habit metadata: ${metadataResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      final filteredHabits = metadataResult.data!;

      final result = <String, Map<DateTime, CompletionRecord>>{};

      // Get completion data for each habit using new RowProcessor
      for (final habit in filteredHabits) {
        final config = HabitLoadConfig(
          startDate: startDate,
          endDate: endDate,
          convertToLocal: false, // Keep UTC for calculations
          loadCompletions: true,
          loadReminders: false,
          loadFrequencyDays: false,
        );

        final completionResult = await _rowProcessor.processCompletions(
          habitId: habit.id,
          config: config,
          context: DataAccessContext(
            component: 'AtomicDataService',
            operation: 'processCompletions',
            parameters: {'habitId': habit.id},
          ),
        );

        if (completionResult.success && completionResult.data != null) {
          // Return the full CompletionRecord objects (includes count and goalAtCompletion)
          result[habit.id] = completionResult.data!.completions;
        }
      }

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getCompletionRecords completed: ${result.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: result,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getCompletionRecords failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get completion records: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Map<String, Map<DateTime, CompletionRecord>>>> getCompletionTimestamps({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Validate date range
      if (startDate.isAfter(endDate)) {
        throw DataValidationException(
          'Start date cannot be after end date',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] getCompletionTimestamps called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final metadataResult = await getHabitMetadata(
        habitIds: habitIds,
        context: DataAccessContext(
          component: 'AtomicDataService',
          operation: 'getCompletionTimestamps',
        ),
      );

      if (!metadataResult.success || metadataResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get habit metadata: ${metadataResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      final filteredHabits = metadataResult.data!;

      final result = <String, Map<DateTime, CompletionRecord>>{};

      // Get completion data for each habit using new RowProcessor
      for (final habit in filteredHabits) {
        final config = HabitLoadConfig(
          startDate: startDate,
          endDate: endDate,
          convertToLocal: true, // Convert to local time for display
          loadCompletions: true,
          loadReminders: false,
          loadFrequencyDays: false,
        );

        final completionResult = await _rowProcessor.processCompletions(
          habitId: habit.id,
          config: config,
          context: DataAccessContext(
            component: 'AtomicDataService',
            operation: 'processCompletions',
            parameters: {'habitId': habit.id},
          ),
        );

        if (completionResult.success && completionResult.data != null) {
          result[habit.id] = completionResult.data!.completions;
        }
      }

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getCompletionTimestamps completed: ${result.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: result,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getCompletionTimestamps failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get completion timestamps: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<List<DateTime>>> getIndividualCompletionTimestamps({
    required String habitId,
    required DateTime date,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getIndividualCompletionTimestamps called: ${context.component}.${context.operation}');

      // Use repository method to get individual timestamps for the day
      final timestamps = await _repository.getCompletionTimestampsForDay(habitId, date);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getIndividualCompletionTimestamps completed: ${timestamps.length} timestamps in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: timestamps,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getIndividualCompletionTimestamps failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get individual completion timestamps: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Map<String, int>>> getMaxStreak({
    List<String>? habitIds,
    bool activeDaysOnly = false,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getMaxStreak called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final metadataResult = await getHabitMetadata(
        habitIds: habitIds,
        context: DataAccessContext(
          component: 'AtomicDataService',
          operation: 'getMaxStreak',
        ),
      );

      if (!metadataResult.success || metadataResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get habit metadata: ${metadataResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      final filteredHabits = metadataResult.data!;

      final result = <String, int>{};

      // Calculate max streak for each habit
      for (final habit in filteredHabits) {
        final maxStreak = await _repository.calculateMaxStreak(habit.id);
        result[habit.id] = maxStreak;
      }

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getMaxStreak completed: ${result.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: result,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getMaxStreak failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get max streak: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Map<String, int>>> getCurrentStreak({
    required DateTime asOfDate,
    List<String>? habitIds,
    bool activeDaysOnly = false,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getCurrentStreak called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final metadataResult = await getHabitMetadata(
        habitIds: habitIds,
        context: DataAccessContext(
          component: 'AtomicDataService',
          operation: 'getCurrentStreak',
        ),
      );

      if (!metadataResult.success || metadataResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get habit metadata: ${metadataResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      final filteredHabits = metadataResult.data!;

      final result = <String, int>{};

      // Calculate current streak for each habit
      for (final habit in filteredHabits) {
        final currentStreak = await _repository.calculateCurrentStreak(habit.id, asOfDate);
        result[habit.id] = currentStreak;
      }

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getCurrentStreak completed: ${result.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: result,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getCurrentStreak failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get current streak: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> addCompletions({
    required String habitId,
    required DateTime date,
    required int count,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (count <= 0) {
        throw DataValidationException(
          'Completion count must be positive',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] addCompletions called: ${context.component}.${context.operation}');

      // Add completions using repository
      await _repository.addMultipleCompletions(habitId, date, count);

      // Invalidate cache for this habit and date
      await _cache.invalidateCompletion(habitId, date);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] addCompletions completed: $count completions in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] addCompletions failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to add completions: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> removeCompletions({
    required String habitId,
    required DateTime date,
    required int count,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (count <= 0) {
        throw DataValidationException(
          'Removal count must be positive',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] removeCompletions called: ${context.component}.${context.operation}');

      // Remove completions using repository
      await _repository.removeOldestCompletions(habitId, date, count);

      // Invalidate cache for this habit and date
      await _cache.invalidateCompletion(habitId, date);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] removeCompletions completed: $count completions in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] removeCompletions failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to remove completions: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Habit>> createHabit({
    required HabitData habitData,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Validate habit data
      habitData.validate();

      debugPrint('🔍 [ATOMIC] createHabit called: ${context.component}.${context.operation}');

      // Create habit using repository
      final habit = Habit.createWithUuid(
        name: habitData.name,
        description: habitData.description,
        colorIndex: habitData.colorIndex,
        iconName: habitData.iconName,
        reminderTime: habitData.reminderTime,
        enableReminders: habitData.enableReminders,
        frequencyDays: habitData.frequencyDays,
        targetGoal: habitData.targetGoal,
        allowExceedGoal: habitData.allowExceedGoal,
      );

      final result = await _repository.saveHabit(habit);

      if (!result.success) {
        throw Exception('Failed to save habit: ${result.errorMessage}');
      }

      // Invalidate metadata cache
      await _cache.invalidateMetadata();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] createHabit completed: ${habit.name} in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: habit,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] createHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to create habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> archiveHabit({
    required String habitId,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] archiveHabit called: ${context.component}.${context.operation}');

      // Archive habit using repository
      await _repository.archiveHabit(habitId);

      // Invalidate caches
      await _cache.invalidateMetadata();
      await _cache.invalidateAllCompletions();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] archiveHabit completed: $habitId in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] archiveHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to archive habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> unarchiveHabit({
    required String habitId,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] unarchiveHabit called: ${context.component}.${context.operation}');

      // Unarchive habit using repository
      await _repository.unarchiveHabit(habitId);

      // Invalidate caches
      await _cache.invalidateMetadata();
      await _cache.invalidateAllCompletions();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] unarchiveHabit completed: $habitId in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] unarchiveHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to unarchive habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> deleteHabit({
    required String habitId,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] deleteHabit called: ${context.component}.${context.operation}');

      // Check if habit exists (lightweight check)
      final exists = await _repository.habitExists(habitId);
      if (!exists) {
        throw NotFoundException(
          'Habit not found: $habitId',
          context,
        );
      }

      // Delete habit using repository
      await _repository.deleteHabit(habitId);

      // Invalidate caches
      await _cache.invalidateMetadata();
      await _cache.invalidateAllCompletions();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] deleteHabit completed: $habitId in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] deleteHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to delete habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Map<int, int>>> getHourlyCompletions({
    required String habitId,
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Validate date range
      if (startDate.isAfter(endDate)) {
        throw DataValidationException(
          'Start date cannot be after end date',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] getHourlyCompletions called: ${context.component}.${context.operation}');

      // Use repository method for hourly completions
      final hourlyData = await _repository.getHourlyCompletions(habitId, startDate, endDate);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getHourlyCompletions completed: ${hourlyData.length} hours in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: hourlyData,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getHourlyCompletions failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get hourly completions: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Habit>> modifyHabit({
    required String habitId,
    required Map<String, dynamic> updates,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] modifyHabit called: ${context.component}.${context.operation}');

      // Check if habit exists and get current metadata
      final exists = await _repository.habitExists(habitId);
      if (!exists) {
        throw NotFoundException(
          'Habit not found: $habitId',
          context,
        );
      }

      // Get current habit metadata only (no completion data needed for updates)
      final metadataResult = await getHabitMetadata(
        habitIds: [habitId],
        context: DataAccessContext(
          component: 'AtomicDataService',
          operation: 'getHabitMetadataForUpdate',
          parameters: {'habitId': habitId},
        ),
      );

      if (!metadataResult.success || metadataResult.data == null || metadataResult.data!.isEmpty) {
        throw NotFoundException(
          'Habit metadata not found: $habitId',
          context,
        );
      }

      final currentMetadata = metadataResult.data!.first;
      
      // Create a minimal habit object for updates (no completion data)
      final currentHabit = Habit.fromMetadata(currentMetadata);

      // Apply updates to create new habit
      final updatedHabit = currentHabit.copyWith(
        name: updates['name'] as String?,
        description: updates['description'] as String?,
        colorIndex: updates['colorIndex'] as int?,
        iconName: updates['iconName'] as String?,
        reminderTime: _parseReminderTime(updates['reminderTime']),
        enableReminders: updates['enableReminders'] as bool?,
        isArchived: updates['isArchived'] as bool?,
        frequencyDays: updates['frequencyDays'] as Map<String, int>?,
        targetGoal: updates['targetGoal'] as int?,
        allowExceedGoal: updates['allowExceedGoal'] as bool?,
      );

      // Save updated habit
      final result = await _repository.saveHabit(updatedHabit);

      if (!result.success) {
        throw Exception('Failed to save updated habit: ${result.errorMessage}');
      }

      // Invalidate caches
      await _cache.invalidateMetadata();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] modifyHabit completed: ${updatedHabit.name} in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: updatedHabit,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] modifyHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to modify habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<DataAccessResult<HabitMetadata>> processHabitMetadata({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] processHabitMetadata called: ${context.component}.${context.operation}');

      // Use the row processor to process metadata
      final result = await _rowProcessor.processHabitMetadata(
        row: row,
        context: context,
      );

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] processHabitMetadata completed in ${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] processHabitMetadata failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process habit metadata: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<DataAccessResult<ProcessedCompletions>> processCompletions({
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] processCompletions called: ${context.component}.${context.operation}');

      // Use the row processor to process completions
      final result = await _rowProcessor.processCompletions(
        habitId: habitId,
        config: config,
        context: context,
      );

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] processCompletions completed in ${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] processCompletions failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process completions: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<DataAccessResult<ProcessedReminders>> processReminders({
    required String habitId,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] processReminders called: ${context.component}.${context.operation}');

      // Use the row processor to process reminders
      final result = await _rowProcessor.processReminders(
        habitId: habitId,
        context: context,
      );

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] processReminders completed in ${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] processReminders failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process reminders: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<DataAccessResult<ProcessedFrequency>> processFrequencyDays({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] processFrequencyDays called: ${context.component}.${context.operation}');

      // Use the row processor to process frequency days
      final result = await _rowProcessor.processFrequencyDays(
        row: row,
        context: context,
      );

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] processFrequencyDays completed in ${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] processFrequencyDays failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process frequency days: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<DataAccessResult<Habit>> assembleHabit({
    required HabitMetadata metadata,
    ProcessedCompletions? completions,
    ProcessedReminders? reminders,
    ProcessedFrequency? frequency,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] assembleHabit called: ${context.component}.${context.operation}');

      // Use the row processor to assemble the habit
      final result = await _rowProcessor.assembleHabit(
        metadata: metadata,
        completions: completions,
        reminders: reminders,
        frequency: frequency,
        context: context,
      );

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] assembleHabit completed in ${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] assembleHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to assemble habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<DataAccessResult<Habit>> processHabitFromRow({
    required Map<String, dynamic> row,
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] processHabitFromRow called: ${context.component}.${context.operation}');

      // Use the row processor to process the habit from row
      final result = await _rowProcessor.processHabitFromRow(
        row: row,
        habitId: habitId,
        config: config,
        context: context,
      );

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] processHabitFromRow completed in ${stopwatch.elapsedMilliseconds}ms');

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] processHabitFromRow failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process habit from row: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<List<Habit>>> getHabitsNeedingAttention({
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getHabitsNeedingAttention called: ${context.component}.${context.operation}');

      // Use repository method for habits needing attention
      final habits = await _repository.getHabitsNeedingAttention();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getHabitsNeedingAttention completed: ${habits.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: habits,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getHabitsNeedingAttention failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get habits needing attention: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<bool>> hasDuplicateHabit({
    required String name,
    required String iconName,
    String? excludeHabitId,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] hasDuplicateHabit called: ${context.component}.${context.operation}');

      // Use repository method for duplicate check
      final hasDuplicate = await _repository.hasDuplicateHabit(name, iconName, excludeHabitId: excludeHabitId);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] hasDuplicateHabit completed: $hasDuplicate in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: hasDuplicate,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] hasDuplicateHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to check for duplicate habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<bool>> canUpdateHabit({
    required String habitId,
    required String newName,
    required String newIconName,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] canUpdateHabit called: ${context.component}.${context.operation}');

      // Use repository method for update check
      final canUpdate = await _repository.canUpdateHabit(habitId, newName, newIconName);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] canUpdateHabit completed: $canUpdate in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: canUpdate,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] canUpdateHabit failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to check if habit can be updated: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<int>> importSampleHabits({
    required List<Habit> sampleHabits,
    bool clearExisting = false,
    Function(int)? onProgress,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] importSampleHabits called: ${context.component}.${context.operation}');

      // Use repository method for importing sample habits
      final importedCount = await _repository.importHabits(sampleHabits, onProgress: (habitName, progress) {
        onProgress?.call((progress * 100).round());
      });

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] importSampleHabits completed: $importedCount habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: importedCount,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] importSampleHabits failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to import sample habits: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> reorderHabits({
    required String draggedId,
    required int newPosition,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] reorderHabits called: ${context.component}.${context.operation}');

      // Use repository method for reordering
      await _repository.reorderHabits(draggedId, newPosition);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] reorderHabits completed in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] reorderHabits failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to reorder habits: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> reorderHabitsInContext({
    required String draggedId,
    required int newPosition,
    required List<String> visibleHabitIds,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] reorderHabitsInContext called: ${context.component}.${context.operation}');

      // Use repository method for reordering with context
      await _repository.reorderHabitsInContext(draggedId, newPosition, visibleHabitIds);

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] reorderHabitsInContext completed in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] reorderHabitsInContext failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to reorder habits in context: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<void>> normalizeOrderValues({
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] normalizeOrderValues called: ${context.component}.${context.operation}');

      // Use repository method for normalizing order values
      await _repository.normalizeOrderValues();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] normalizeOrderValues completed in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: null,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] normalizeOrderValues failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to normalize order values: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }


  @override
  Future<Map<String, dynamic>> getPerformanceStats() async {
    return {
      'cache_stats': await _cache.getStats(),
      'repository_stats': {}, // Could add repository stats here
    };
  }

  @override
  Future<void> clearCache() async {
    await _cache.clearAll();
    debugPrint('🗑️ [ATOMIC] Cache cleared');
  }

  /// Helper method to parse reminder time from dynamic value
  TimeOfDay? _parseReminderTime(dynamic value) {
    if (value == null) return null;
    if (value is TimeOfDay) return value;

    // Handle map format from JSON
    if (value is Map<String, dynamic>) {
      final hour = value['hour'] as int?;
      final minute = value['minute'] as int?;
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }
}

/// Data structure for habit creation
class HabitData {
  final String name;
  final String description;
  final int colorIndex;
  final String iconName;
  final TimeOfDay? reminderTime;
  final bool enableReminders;
  final Map<String, int> frequencyDays;
  final int targetGoal;
  final bool allowExceedGoal;

  const HabitData({
    required this.name,
    this.description = '',
    this.colorIndex = 0,
    this.iconName = 'check_circle',
    this.reminderTime,
    this.enableReminders = false,
    this.frequencyDays = Habit.defaultFrequencyDays,
    this.targetGoal = 1,
    this.allowExceedGoal = false,
  });

  /// Validate habit data
  void validate() {
    if (name.trim().isEmpty) {
      throw DataValidationException('Habit name cannot be empty', DataAccessContext(
        component: 'HabitData',
        operation: 'validation',
      ));
    }
    if (colorIndex < 0 || colorIndex > Habit.maxColorIndex) {
      throw DataValidationException(
        'Color index must be between 0 and ${Habit.maxColorIndex}',
        DataAccessContext(
          component: 'HabitData',
          operation: 'validation',
        ),
      );
    }
    if (targetGoal <= 0) {
      throw DataValidationException(
        'Target goal must be greater than 0',
        DataAccessContext(
          component: 'HabitData',
          operation: 'validation',
        ),
      );
    }
  }
}

