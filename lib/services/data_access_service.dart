import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/atomic_data_service.dart';
import '../services/caching_service.dart';
import '../services/database_service.dart';
import '../services/row_processor.dart';

/// Centralized service for all database queries with mandatory date ranges
/// and comprehensive logging to prevent data access issues.
class DataAccessService {
  final SqliteHabitRepository _repository;
  final ICachingService _cache;
  late final AtomicDataService _atomicDataService;

  DataAccessService({
    required SqliteHabitRepository repository,
    required ICachingService cache,
  }) : _repository = repository, _cache = cache {
    // Initialize the atomic data service with dependencies
    _atomicDataService = AtomicDataService(
      repository: repository,
      cache: cache,
      rowProcessor: RowProcessor(
        metadataProcessor: MetadataProcessor(),
        completionProcessor: CompletionProcessor(DatabaseService()),
        reminderProcessor: ReminderProcessor(DatabaseService()),
        frequencyProcessor: FrequencyProcessor(),
        habitAssembler: HabitAssembler(),
      ),
    );
  }

  /// Get the atomic data service for new architecture operations
  AtomicDataService get atomicDataService => _atomicDataService;

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
      // Get habit metadata only (no completion data)
      final habits = await _repository.getActiveHabitsForReordering();
      
      // Filter by IDs if provided
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

      final result = <String, Map<DateTime, int>>{};
      int totalCompletions = 0;

      // Load completion data directly from database for each habit
      for (final habit in filteredHabits) {
        final completionRecords = await _repository.getCompletionDataForHabit(
          habit.id, 
          startDate, 
          endDate
        );
        
        // Extract just the counts for getCompletionDays
        final completions = <DateTime, int>{};
        for (final entry in completionRecords.entries) {
          completions[entry.key] = entry.value.count;
        }
        
        result[habit.id] = completions;
        totalCompletions += completions.length;
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
      // Get habit metadata only (no completion data)
      final habits = await _repository.getActiveHabitsForReordering();
      
      // Filter by IDs if provided
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

      final result = <String, Map<DateTime, CompletionRecord>>{};
      int totalCompletions = 0;

      // Load completion data directly from database for each habit
      for (final habit in filteredHabits) {
        final completionRecords = await _repository.getCompletionDataForHabit(
          habit.id, 
          startDate, 
          endDate
        );
        
        result[habit.id] = completionRecords;
        totalCompletions += completionRecords.length;
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
      // Get habit metadata only (no completion data)
      final habits = await _repository.getActiveHabitsForReordering();
      
      // Filter by IDs if provided
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

      final result = <String, int>{};
      
      // Calculate max streak using SQL for each habit
      for (final habit in filteredHabits) {
        final maxStreak = await _repository.calculateMaxStreak(habit.id);
        result[habit.id] = maxStreak;
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
      // Get habit metadata only (no completion data)
      final habits = await _repository.getActiveHabitsForReordering();
      
      // Filter by IDs if provided
      final filteredHabits = habitIds != null && habitIds.isNotEmpty
          ? habits.where((h) => habitIds.contains(h.id)).toList()
          : habits;

      final result = <String, int>{};
      
      // Calculate current streak using SQL for each habit
      for (final habit in filteredHabits) {
        final currentStreak = await _repository.calculateCurrentStreak(habit.id, date);
        result[habit.id] = currentStreak;
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
      await _cache.cacheCompletion(habitId, date, count);
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
      await _cache.cacheCompletion(habitId, date, 0); // Remove from cache
    });
  }

  /// Saves a new habit to the database
  /// 
  /// [habit] - The habit to save
  /// 
  /// Returns: HabitSaveResult indicating success/failure
  Future<HabitSaveResult> saveHabit(Habit habit) async {
    _logQuery('saveHabit', {
      'habitId': habit.id,
      'name': habit.name,
      'targetGoal': habit.targetGoal,
    });

    return await _withTiming('saveHabit', () async {
      return await _repository.saveHabit(habit);
    });
  }

  /// Archives a habit
  /// 
  /// [habitId] - ID of the habit to archive
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> archiveHabit(String habitId) async {
    _logQuery('archiveHabit', {'habitId': habitId});

    return await _withTiming('archiveHabit', () async {
      return await _repository.archiveHabit(habitId);
    });
  }

  /// Unarchives a habit
  /// 
  /// [habitId] - ID of the habit to unarchive
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> unarchiveHabit(String habitId) async {
    _logQuery('unarchiveHabit', {'habitId': habitId});

    return await _withTiming('unarchiveHabit', () async {
      return await _repository.unarchiveHabit(habitId);
    });
  }

  /// Deletes a habit permanently
  /// 
  /// [habitId] - ID of the habit to delete
  Future<void> deleteHabit(String habitId) async {
    _logQuery('deleteHabit', {'habitId': habitId});

    return await _withTiming('deleteHabit', () async {
      await _repository.deleteHabit(habitId);
    });
  }

  /// Gets archived habits
  /// 
  /// Returns: List of archived habits
  Future<List<Habit>> getArchivedHabits() async {
    _logQuery('getArchivedHabits', {});

    return await _withTiming('getArchivedHabits', () async {
      return await _repository.getArchivedHabits();
    });
  }

  /// Gets all habits (including archived)
  /// 
  /// Returns: List of all habits
  Future<List<Habit>> getAllHabits() async {
    _logQuery('getAllHabits', {});

    return await _withTiming('getAllHabits', () async {
      return await _repository.getAllHabits();
    });
  }

  /// Gets a specific habit by ID
  /// 
  /// [habitId] - ID of the habit to retrieve
  /// 
  /// Returns: The habit if found, null otherwise
  Future<Habit?> getHabitById(String habitId) async {
    _logQuery('getHabitById', {'habitId': habitId});

    return await _withTiming('getHabitById', () async {
      return await _repository.getHabitById(habitId);
    });
  }

  /// Checks if a habit name and icon combination already exists
  /// 
  /// [name] - Habit name to check
  /// [iconName] - Icon name to check
  /// [excludeHabitId] - Optional habit ID to exclude from check
  /// 
  /// Returns: true if duplicate exists, false otherwise
  Future<bool> hasDuplicateHabit(String name, String iconName, {String? excludeHabitId}) async {
    _logQuery('hasDuplicateHabit', {
      'name': name,
      'iconName': iconName,
      'excludeHabitId': excludeHabitId,
    });

    return await _withTiming('hasDuplicateHabit', () async {
      return await _repository.hasDuplicateHabit(name, iconName, excludeHabitId: excludeHabitId);
    });
  }

  /// Checks if a habit can be updated without conflicts
  /// 
  /// [habitId] - ID of the habit to update
  /// [newName] - New name for the habit
  /// [newIconName] - New icon name for the habit
  /// 
  /// Returns: true if update is allowed, false otherwise
  Future<bool> canUpdateHabit(String habitId, String newName, String newIconName) async {
    _logQuery('canUpdateHabit', {
      'habitId': habitId,
      'newName': newName,
      'newIconName': newIconName,
    });

    return await _withTiming('canUpdateHabit', () async {
      return await _repository.canUpdateHabit(habitId, newName, newIconName);
    });
  }

  /// Gets habits that need attention (low completion rate or no recent completions)
  /// 
  /// Returns: List of habits needing attention
  Future<List<Habit>> getHabitsNeedingAttention() async {
    _logQuery('getHabitsNeedingAttention', {});

    return await _withTiming('getHabitsNeedingAttention', () async {
      return await _repository.getHabitsNeedingAttention();
    });
  }

  /// Reorders habits in the database
  /// 
  /// [draggedId] - ID of the habit being dragged
  /// [newPosition] - New position for the habit
  Future<void> reorderHabits(String draggedId, int newPosition) async {
    _logQuery('reorderHabits', {
      'draggedId': draggedId,
      'newPosition': newPosition,
    });

    return await _withTiming('reorderHabits', () async {
      await _repository.reorderHabits(draggedId, newPosition);
    });
  }

  /// Reorders habits in a specific context
  /// 
  /// [draggedId] - ID of the habit being dragged
  /// [newPosition] - New position for the habit
  /// [visibleHabitIds] - List of visible habit IDs in the context
  Future<void> reorderHabitsInContext(String draggedId, int newPosition, List<String> visibleHabitIds) async {
    _logQuery('reorderHabitsInContext', {
      'draggedId': draggedId,
      'newPosition': newPosition,
      'visibleHabitIds': visibleHabitIds.length,
    });

    return await _withTiming('reorderHabitsInContext', () async {
      await _repository.reorderHabitsInContext(draggedId, newPosition, visibleHabitIds);
    });
  }

  /// Normalizes order values in the database
  Future<void> normalizeOrderValues() async {
    _logQuery('normalizeOrderValues', {});

    return await _withTiming('normalizeOrderValues', () async {
      await _repository.normalizeOrderValues();
    });
  }

  /// Gets hourly completion data for a habit
  /// 
  /// [habitId] - ID of the habit
  /// [startDate] - Start date for the data
  /// [endDate] - End date for the data
  /// 
  /// Returns: Map of hour -> completion count
  Future<Map<int, int>> getHourlyCompletions(String habitId, DateTime startDate, DateTime endDate) async {
    _logQuery('getHourlyCompletions', {
      'habitId': habitId,
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
    });

    return await _withTiming('getHourlyCompletions', () async {
      return await _repository.getHourlyCompletions(habitId, startDate, endDate);
    });
  }

  /// Imports sample habits
  /// 
  /// [sampleHabits] - List of sample habits to import
  /// [clearExisting] - Whether to clear existing habits first
  /// [onProgress] - Optional progress callback
  /// 
  /// Returns: Number of habits imported
  Future<int> importSampleHabits(List<Habit> sampleHabits, {bool clearExisting = false, Function(String habitName, double progress)? onProgress}) async {
    _logQuery('importSampleHabits', {
      'sampleHabitsCount': sampleHabits.length,
      'clearExisting': clearExisting,
    });

    return await _withTiming('importSampleHabits', () async {
      if (clearExisting) {
        return await _repository.clearAndImportHabits(sampleHabits);
      } else {
        return await _repository.importHabits(sampleHabits, onProgress: onProgress);
      }
    });
  }

  /// Overwrites an archived habit with new data
  /// 
  /// [archivedHabitId] - ID of the archived habit to overwrite
  /// [newHabit] - New habit data
  /// 
  /// Returns: HabitSaveResult indicating success/failure
  Future<HabitSaveResult> overwriteArchivedHabit(String archivedHabitId, Habit newHabit) async {
    _logQuery('overwriteArchivedHabit', {
      'archivedHabitId': archivedHabitId,
      'newHabitId': newHabit.id,
    });

    return await _withTiming('overwriteArchivedHabit', () async {
      return await _repository.overwriteArchivedHabit(archivedHabitId, newHabit);
    });
  }

  /// Gets completion timestamps for a specific day
  /// 
  /// [habitId] - ID of the habit
  /// [date] - Date to get timestamps for
  /// 
  /// Returns: List of completion timestamps
  Future<List<DateTime>> getCompletionTimestampsForDay(String habitId, DateTime date) async {
    _logQuery('getCompletionTimestampsForDay', {
      'habitId': habitId,
      'date': date.toIso8601String().split('T')[0],
    });

    return await _withTiming('getCompletionTimestampsForDay', () async {
      return await _repository.getCompletionTimestampsForDay(habitId, date);
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
