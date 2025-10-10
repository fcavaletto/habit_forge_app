import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/habit_metadata_cache_service.dart';
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
  /// [habitIds] - Optional list of specific habit IDs to retrieve
  /// [context] - Logging context for the operation
  ///
  /// Returns metadata for habits including: id, name, description, color, icon,
  /// creation date, frequency settings, target goals, and display order.
  Future<DataAccessResult<List<HabitMetadata>>> getHabitFeatures({
    List<String>? habitIds,
    required DataAccessContext context,
  });

  /// Get all habits including archived ones (returns full Habit objects)
  ///
  /// [context] - Logging context for the operation
  ///
  /// Returns all habits in the system, both active and archived.
  /// This is primarily used for operations that need to check existence or
  /// restore archived habits (e.g., Add Sample Habits functionality).
  Future<DataAccessResult<List<Habit>>> getAllHabitsIncludingArchived({
    required DataAccessContext context,
  });

  /// Get completion counts for habits within a date range
  ///
  /// [startDate] - Start of date range (inclusive)
  /// [endDate] - End of date range (inclusive)
  /// [habitIds] - Optional list of specific habit IDs
  /// [context] - Logging context for the operation
  ///
  /// Returns map of habit ID -> date -> completion count
  /// Throws DataValidationException if date range is invalid
  Future<DataAccessResult<Map<String, Map<DateTime, int>>>> getCompletionDays({
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

/// Interface for data preparation services
///
/// These services combine atomic operations to provide UI-ready data structures
abstract class IDataPreparationService {
  /// Get habits optimized for dashboard display with completion data
  Future<DataAccessResult<List<Habit>>> getDashboardHabits({
    required DataAccessContext context,
  });

  /// Get habits optimized for statistics screen with full historical data
  Future<DataAccessResult<List<Habit>>> getStatsHabits({
    required DataAccessContext context,
  });

  /// Get habits for calendar view with date range filtering
  Future<DataAccessResult<List<Habit>>> getCalendarHabits({
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  });

  /// Get habits optimized for reordering operations (metadata only)
  Future<DataAccessResult<List<Habit>>> getReorderableHabits({
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
  Future<DataAccessResult<List<HabitMetadata>>> getHabitFeatures({
    List<String>? habitIds,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getHabitFeatures called: ${context.component}.${context.operation}');

      // Get habit metadata from repository (still using existing method for now)
      final habits = await _repository.getActiveHabitsForReordering();

      // Filter by habit IDs if provided
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

      // Convert to metadata objects
      final metadata = filteredHabits.map(HabitMetadata.fromHabit).toList();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getHabitFeatures completed: ${metadata.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: metadata,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getHabitFeatures failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get habit features: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<List<Habit>>> getAllHabitsIncludingArchived({
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getAllHabitsIncludingArchived called: ${context.component}.${context.operation}');

      // Get all habits (active + archived) from repository
      final habits = await _repository.getAllHabits();

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getAllHabitsIncludingArchived completed: ${habits.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: habits,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getAllHabitsIncludingArchived failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get all habits including archived: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<Map<String, Map<DateTime, int>>>> getCompletionDays({
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

      if (endDate.difference(startDate).inDays > 365) {
        throw DataValidationException(
          'Date range cannot exceed 365 days',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] getCompletionDays called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final habits = await _repository.getActiveHabitsForReordering();
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

      final result = <String, Map<DateTime, int>>{};

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
          // Extract just the counts
          final completions = <DateTime, int>{};
          for (final entry in completionResult.data!.completions.entries) {
            completions[entry.key] = entry.value.count;
          }
          result[habit.id] = completions;
        }
      }

      stopwatch.stop();
      debugPrint('✅ [ATOMIC] getCompletionDays completed: ${result.length} habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: result,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [ATOMIC] getCompletionDays failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to get completion days: $e',
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

      if (endDate.difference(startDate).inDays > 365) {
        throw DataValidationException(
          'Date range cannot exceed 365 days',
          DataAccessContext(component: 'AtomicDataService', operation: 'validation'),
        );
      }

      debugPrint('🔍 [ATOMIC] getCompletionTimestamps called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final habits = await _repository.getActiveHabitsForReordering();
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

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
  Future<DataAccessResult<Map<String, int>>> getMaxStreak({
    List<String>? habitIds,
    bool activeDaysOnly = false,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] getMaxStreak called: ${context.component}.${context.operation}');

      // Get habit metadata first to know which habits to query
      final habits = await _repository.getActiveHabitsForReordering();
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

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
      final habits = await _repository.getActiveHabitsForReordering();
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

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

      // Check if habit exists
      final habit = await _repository.getHabitById(habitId);
      if (habit == null) {
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
  Future<DataAccessResult<Habit>> modifyHabit({
    required String habitId,
    required Map<String, dynamic> updates,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [ATOMIC] modifyHabit called: ${context.component}.${context.operation}');

      // Get current habit
      final currentHabit = await _repository.getHabitById(habitId);
      if (currentHabit == null) {
        throw NotFoundException(
          'Habit not found: $habitId',
          context,
        );
      }

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

