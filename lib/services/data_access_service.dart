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
  final ICachingService _cache;
  late final AtomicDataService _atomicDataService;

  DataAccessService({
    required SqliteHabitRepository repository,
    required ICachingService cache,
  }) : _cache = cache {
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
}