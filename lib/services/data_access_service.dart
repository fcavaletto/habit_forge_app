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
///
/// ✅ ATOMIC ARCHITECTURE COMPLETE:
/// This service now provides access to the fully implemented Atomic Data Service
/// architecture. All new code should use the atomic service for optimal performance
/// and maintainability.
///
/// RECOMMENDED USAGE:
/// - `atomicDataService` for fine-grained data operations (preferred)
/// - `IDataPreparationService` implementations for UI-specific data preparation
///
/// Legacy methods remain for backward compatibility but are now fully atomic.
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
  ///
  /// ✅ RECOMMENDED: Use this for all new data access code
  AtomicDataService get atomicDataService => _atomicDataService;
  
  /// Get the caching service for cache operations
  ICachingService get cache => _cache;

























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
  /// Stack traces are only logged on errors, not on every query
  void _logQuery(String method, Map<String, dynamic> params) {
    debugPrint('🔍 [DATA_ACCESS] $method called with params: $params');
    // Stack trace removed - only log on errors for better performance
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
