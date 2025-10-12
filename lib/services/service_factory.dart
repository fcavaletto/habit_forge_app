import 'package:flutter/foundation.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/database_service.dart';
import 'atomic_data_service.dart';
import 'caching_service.dart';
import 'data_preparation_service.dart';
import 'data_access_monitor.dart';
import 'row_processor.dart';

/// Service Factory for Dependency Injection
///
/// Provides a centralized way to create and configure all services
/// with proper dependency injection and testability support.
class ServiceFactory {
  // Core services (singletons)
  static DatabaseService? _databaseService;
  static SqliteHabitRepository? _habitRepository;
  static ICachingService? _cachingService;
  static IRowProcessor? _rowProcessor;

  // Atomic services
  static IAtomicDataService? _atomicDataService;

  // Data preparation services
  static IDataPreparationService? _dashboardDataService;
  static IDataPreparationService? _statsDataService;
  static IDataPreparationService? _calendarDataService;
  static IDataPreparationService? _reorderDataService;
  static IDataPreparationService? _archiveDataService;

  /// Initialize all core services
  static Future<void> initialize() async {
    debugPrint('🚀 Initializing Service Factory...');

    try {
      // Initialize database service
      _databaseService ??= DatabaseService();

      // Initialize caching service
      _cachingService ??= CachingServiceFactory.createMemoryCache();

      // Initialize repository
      _habitRepository ??= SqliteHabitRepository(_databaseService!);

      // Initialize row processor with caching
      _rowProcessor ??= RowProcessorFactory.create(_databaseService!, _cachingService!);

      // Initialize smaller processors for composition
      final metadataProcessor = MetadataProcessor();
      final completionProcessor = CompletionProcessor(_databaseService!);
      final reminderProcessor = ReminderProcessor(_databaseService!);
      final frequencyProcessor = FrequencyProcessor();
      final habitAssembler = HabitAssembler();

      // Replace with composed processor (keeping cached version for now)
      _rowProcessor ??= CachedRowProcessor(
        RowProcessor(
          metadataProcessor: metadataProcessor,
          completionProcessor: completionProcessor,
          reminderProcessor: reminderProcessor,
          frequencyProcessor: frequencyProcessor,
          habitAssembler: habitAssembler,
        ),
        _cachingService!,
      );

      // Initialize atomic data service
      _atomicDataService ??= AtomicDataService(
        repository: _habitRepository!,
        cache: _cachingService!,
        rowProcessor: _rowProcessor!,
      );

      // Initialize data preparation services
      _dashboardDataService ??= DataPreparationServiceFactory.createDashboardService(_atomicDataService!);
      _statsDataService ??= DataPreparationServiceFactory.createStatsService(_atomicDataService!);
      _calendarDataService ??= DataPreparationServiceFactory.createCalendarService(_atomicDataService!);
      _reorderDataService ??= DataPreparationServiceFactory.createReorderService(_atomicDataService!);
      _archiveDataService ??= DataPreparationServiceFactory.createArchiveService(_atomicDataService!);

      debugPrint('✅ Service Factory initialized successfully');
    } catch (e) {
      debugPrint('❌ Service Factory initialization failed: $e');
      rethrow;
    }
  }

  /// Get the atomic data service
  static IAtomicDataService get atomicDataService {
    if (_atomicDataService == null) {
      throw StateError('Service Factory not initialized. Call initialize() first.');
    }
    return _atomicDataService!;
  }

  /// Get the dashboard data preparation service
  static IDataPreparationService get dashboardDataService {
    if (_dashboardDataService == null) {
      throw StateError('Service Factory not initialized. Call initialize() first.');
    }
    return _dashboardDataService!;
  }

  /// Get the stats data preparation service
  static IDataPreparationService get statsDataService {
    if (_statsDataService == null) {
      throw StateError('Service Factory not initialized. Call initialize() first.');
    }
    return _statsDataService!;
  }

  /// Get the calendar data preparation service
  static IDataPreparationService get calendarDataService {
    if (_calendarDataService == null) {
      throw StateError('Service Factory not initialized. Call initialize() first.');
    }
    return _calendarDataService!;
  }

  /// Get the reorder data preparation service
  static IDataPreparationService get reorderDataService {
    if (_reorderDataService == null) {
      throw StateError('Service Factory not initialized. Call initialize() first.');
    }
    return _reorderDataService!;
  }

  /// Get the archive data preparation service
  static IDataPreparationService get archiveDataService {
    if (_archiveDataService == null) {
      throw StateError('Service Factory not initialized. Call initialize() first.');
    }
    return _archiveDataService!;
  }

  /// Reset all services (useful for testing)
  static void reset() {
    _databaseService = null;
    _habitRepository = null;
    _cachingService = null;
    _rowProcessor = null;
    _atomicDataService = null;
    _dashboardDataService = null;
    _statsDataService = null;
    _calendarDataService = null;
    _reorderDataService = null;
    _archiveDataService = null;

    PerformanceMonitor.resetMetrics();
    debugPrint('🔄 Service Factory reset');
  }

  /// Get service health status
  static Future<Map<String, dynamic>> getHealthStatus() async {
    final health = <String, dynamic>{
      'services_initialized': _atomicDataService != null,
      'performance_stats': PerformanceMonitor.getPerformanceStats(),
    };

    try {
      health['system_health'] = await healthChecker.getSystemHealth();
    } catch (e) {
      health['system_health_error'] = e.toString();
    }

    return health;
  }
}

/// Test-friendly service factory for creating mock services
class TestServiceFactory {
  /// Create a mock atomic data service for testing
  static IAtomicDataService createMockAtomicService() {
    // This would return a mock implementation
    // For now, return the real service but could be extended
    return ServiceFactory.atomicDataService;
  }

  /// Create a mock data preparation service for testing
  static IDataPreparationService createMockDataPreparationService() {
    return ServiceFactory.dashboardDataService;
  }
}
