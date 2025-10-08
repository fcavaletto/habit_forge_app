import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/persistent_cache_service.dart';

/// Centralized service for all database queries with mandatory date ranges
/// and comprehensive logging to prevent data access issues.
class DataAccessService {
  final SqliteHabitRepository _repository;
  final PersistentCacheService _cache;

  DataAccessService({
    required SqliteHabitRepository repository,
    required PersistentCacheService cache,
  }) : _repository = repository, _cache = cache;

  /// Loads habit metadata only (no completion data)
  /// 
  /// [habitIds] - Optional list of specific habit IDs to load.
  ///              If null, loads all active habits.
  Future<List<Habit>> getHabitFeatures({List<String>? habitIds}) async {
    _logQuery('getHabitFeatures', {'habitIds': habitIds?.length ?? 'all'});
    
    return await _withTiming('getHabitFeatures', () async {
      final habits = await _repository.getActiveHabitsForReordering();
      
      // Filter by IDs if provided
      if (habitIds != null && habitIds.isNotEmpty) {
        final filteredHabits = habits.where((h) => habitIds.contains(h.id)).toList();
        _logDataVolume('getHabitFeatures', filteredHabits.length, DateTime.now(), DateTime.now());
        return filteredHabits;
      }
      
      _logDataVolume('getHabitFeatures', habits.length, DateTime.now(), DateTime.now());
      return habits;
    });
  }

  /// Loads completion counts by date for specified habits
  /// 
  /// [startDate] - Start date for completion data (mandatory)
  /// [endDate] - End date for completion data (mandatory)
  /// [habitIds] - Optional list of specific habit IDs to load.
  ///              If null, loads data for all active habits.
  /// 
  /// Returns: Map of habitId -> Map of date -> completion count
  Future<Map<String, Map<DateTime, int>>> getCompletionDays({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
  }) async {
    _validateDateRange(startDate, endDate);
    _logQuery('getCompletionDays', {
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'habitIds': habitIds?.length ?? 'all',
    });

    return await _withTiming('getCompletionDays', () async {
      final habits = await _repository.getActiveHabitsForDashboardWithDateRange(
        startDate: startDate,
        endDate: endDate,
        habitIds: habitIds,
      );

      final result = <String, Map<DateTime, int>>{};
      int totalCompletions = 0;

      for (final habit in habits) {
        final completions = <DateTime, int>{};
        for (final entry in habit.completions.entries) {
          completions[entry.key] = entry.value.count;
          totalCompletions++;
        }
        result[habit.id] = completions;
      }

      _logDataVolume('getCompletionDays', totalCompletions, startDate, endDate);
      return result;
    });
  }

  /// Loads detailed completion records with timestamps
  /// 
  /// [startDate] - Start date for completion data (mandatory)
  /// [endDate] - End date for completion data (mandatory)
  /// [habitIds] - Optional list of specific habit IDs to load.
  ///              If null, loads data for all active habits.
  /// 
  /// Returns: Map of habitId -> Map of date -> CompletionRecord
  Future<Map<String, Map<DateTime, CompletionRecord>>> getCompletionTimestamps({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? habitIds,
  }) async {
    _validateDateRange(startDate, endDate);
    _logQuery('getCompletionTimestamps', {
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'habitIds': habitIds?.length ?? 'all',
    });

    return await _withTiming('getCompletionTimestamps', () async {
      final habits = await _repository.getActiveHabitsForDashboardWithDateRange(
        startDate: startDate,
        endDate: endDate,
        habitIds: habitIds,
      );

      final result = <String, Map<DateTime, CompletionRecord>>{};
      int totalCompletions = 0;

      for (final habit in habits) {
        final completions = <DateTime, CompletionRecord>{};
        for (final entry in habit.completions.entries) {
          completions[entry.key] = entry.value;
          totalCompletions++;
        }
        result[habit.id] = completions;
      }

      _logDataVolume('getCompletionTimestamps', totalCompletions, startDate, endDate);
      return result;
    });
  }

  /// Calculates maximum streak for specified habits
  /// 
  /// [habitIds] - Optional list of specific habit IDs to calculate.
  ///              If null, calculates for all active habits.
  /// 
  /// Returns: Map of habitId -> maximum streak value
  Future<Map<String, int>> getMaxStreak({List<String>? habitIds}) async {
    _logQuery('getMaxStreak', {'habitIds': habitIds?.length ?? 'all'});

    return await _withTiming('getMaxStreak', () async {
      // For max streak, we need all historical data, so we use a wide date range
      final now = DateTime.now();
      final habits = await _repository.getActiveHabitsForStreakCalculationWithDateRange(
        startDate: DateTime(2020), // Start from a reasonable past date
        endDate: now,
        habitIds: habitIds,
      );

      final result = <String, int>{};
      for (final habit in habits) {
        result[habit.id] = habit.currentStreak; // Use the getter instead of non-existent method
      }

      _logDataVolume('getMaxStreak', result.length, DateTime.now(), DateTime.now());
      return result;
    });
  }

  /// Calculates current streak for a specific date
  /// 
  /// [date] - Date to calculate streak for (mandatory)
  /// [habitIds] - Optional list of specific habit IDs to calculate.
  ///              If null, calculates for all active habits.
  /// 
  /// Returns: Map of habitId -> current streak value
  Future<Map<String, int>> getCurrentStreak({
    required DateTime date,
    List<String>? habitIds,
  }) async {
    _logQuery('getCurrentStreak', {
      'date': date.toIso8601String().split('T')[0],
      'habitIds': habitIds?.length ?? 'all',
    });

    return await _withTiming('getCurrentStreak', () async {
      // For current streak, we need data from the calculation date backwards
      final startDate = date.subtract(const Duration(days: 365)); // Look back up to a year
      final habits = await _repository.getActiveHabitsForStreakCalculationWithDateRange(
        startDate: startDate,
        endDate: date,
        habitIds: habitIds,
      );

      final result = <String, int>{};
      for (final habit in habits) {
        result[habit.id] = habit.calculateCurrentStreak(); // Remove the date parameter
      }

      _logDataVolume('getCurrentStreak', result.length, DateTime.now(), DateTime.now());
      return result;
    });
  }

  /// Adds completions for a specific habit and date
  /// 
  /// [habitId] - ID of the habit to add completions to
  /// [date] - Date to add completions for
  /// [count] - Number of completions to add
  Future<void> addCompletions(String habitId, DateTime date, int count) async {
    _logQuery('addCompletions', {
      'habitId': habitId,
      'date': date.toIso8601String().split('T')[0],
      'count': count,
    });

    return await _withTiming('addCompletions', () async {
      await _repository.addMultipleCompletions(habitId, date, count);
      await _cache.updateCompletion(habitId, date, count);
    });
  }

  /// Removes completions for a specific habit and date
  /// 
  /// [habitId] - ID of the habit to remove completions from
  /// [date] - Date to remove completions for
  /// [count] - Number of completions to remove
  Future<void> removeCompletions(String habitId, DateTime date, int count) async {
    _logQuery('removeCompletions', {
      'habitId': habitId,
      'date': date.toIso8601String().split('T')[0],
      'count': count,
    });

    return await _withTiming('removeCompletions', () async {
      await _repository.removeOldestCompletions(habitId, date, count);
      await _cache.updateCompletion(habitId, date, 0); // Remove from cache
    });
  }

  // Private helper methods

  /// Validates that date range is valid and within reasonable limits
  void _validateDateRange(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('startDate cannot be after endDate');
    }
    if (endDate.difference(startDate).inDays > 365) {
      throw ArgumentError('Date range cannot exceed 365 days');
    }
  }

  /// Logs query execution with parameters
  void _logQuery(String method, Map<String, dynamic> params) {
    debugPrint('🔍 [DATA_ACCESS] $method called with params: $params');
    debugPrint('🔍 [DATA_ACCESS] Stack trace: ${StackTrace.current}');
  }

  /// Measures and logs execution time
  Future<T> _withTiming<T>(String operation, Future<T> Function() fn) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await fn();
      debugPrint('⏱️ [PERFORMANCE] $operation completed in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      debugPrint('❌ [ERROR] $operation failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Logs data volume for monitoring
  void _logDataVolume(String method, int recordCount, DateTime startDate, DateTime endDate) {
    final days = endDate.difference(startDate).inDays;
    debugPrint('📊 [DATA_VOLUME] $method loaded $recordCount records for $days days');
    if (recordCount > 100) {
      debugPrint('⚠️ [WARNING] High data volume: $recordCount records');
    }
  }
}
