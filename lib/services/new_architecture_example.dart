import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import 'atomic_data_service.dart';
import 'service_factory.dart';

/// Example of how to use the new centralized data service architecture
///
/// This demonstrates the clean, testable API that replaces the spaghetti code
class NewArchitectureExample {
  /// Example: Initialize the new architecture
  static Future<void> initializeNewArchitecture() async {
    await ServiceFactory.initialize();
    debugPrint('✅ New architecture initialized');
  }

  /// Example: Get dashboard habits using the new system
  static Future<List<Habit>> getDashboardHabits() async {
    try {
      final result = await ServiceFactory.dashboardDataService.getDashboardHabits(
        context: DataAccessContext(
          component: 'DashboardScreen',
          operation: 'loadHabits',
          parameters: {'screen': 'dashboard'},
        ),
      );

      if (result.success) {
        debugPrint('✅ Loaded ${result.data.length} dashboard habits');
        return result.data;
      } else {
        debugPrint('❌ Failed to load dashboard habits: ${result.errorMessage}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error in getDashboardHabits: $e');
      return [];
    }
  }

  /// Example: Add a completion using atomic operations
  static Future<void> addCompletion(String habitId, DateTime date, int count) async {
    try {
      final result = await ServiceFactory.atomicDataService.addCompletions(
        habitId: habitId,
        date: date,
        count: count,
        context: DataAccessContext(
          component: 'CompletionButton',
          operation: 'addCompletion',
          parameters: {'count': count},
        ),
      );

      if (result.success) {
        debugPrint('✅ Added $count completions for habit $habitId');
      } else {
        debugPrint('❌ Failed to add completions: ${result.errorMessage}');
      }
    } catch (e) {
      debugPrint('❌ Error adding completion: $e');
    }
  }

  /// Example: Create a new habit
  static Future<Habit?> createNewHabit() async {
    try {
      final habitData = HabitData(
        name: 'Morning Exercise',
        description: 'Daily morning workout routine',
        colorIndex: 1,
        iconName: 'fitness_center',
        targetGoal: 1,
        frequencyDays: {
          'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 0, 'sun': 0
        },
      );

      final result = await ServiceFactory.atomicDataService.createHabit(
        habitData: habitData,
        context: DataAccessContext(
          component: 'AddHabitScreen',
          operation: 'createHabit',
          parameters: {'name': 'Morning Exercise'},
        ),
      );

      if (result.success) {
        debugPrint('✅ Created habit: ${result.data.name}');
        return result.data;
      } else {
        debugPrint('❌ Failed to create habit: ${result.errorMessage}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error creating habit: $e');
      return null;
    }
  }

  /// Example: Get performance statistics
  static Future<void> checkPerformance() async {
    final stats = await ServiceFactory.getHealthStatus();
    debugPrint('📊 System Health: $stats');

    final atomicStats = await ServiceFactory.atomicDataService.getPerformanceStats();
    debugPrint('⚡ Atomic Service Performance: $atomicStats');
  }

  /// Example: Get stats data for statistics screen
  static Future<List<Habit>> getStatsData() async {
    try {
      final result = await ServiceFactory.statsDataService.getStatsHabits(
        context: DataAccessContext(
          component: 'StatsScreen',
          operation: 'loadStatsData',
          parameters: {'timeRange': 'last_30_days'},
        ),
      );

      if (result.success) {
        debugPrint('✅ Loaded ${result.data.length} habits for stats');
        return result.data;
      } else {
        debugPrint('❌ Failed to load stats data: ${result.errorMessage}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error loading stats data: $e');
      return [];
    }
  }

  /// Example: Get habits for calendar view
  static Future<List<Habit>> getCalendarData(DateTime startDate, DateTime endDate) async {
    try {
      final result = await ServiceFactory.calendarDataService.getCalendarHabits(
        startDate: startDate,
        endDate: endDate,
        context: DataAccessContext(
          component: 'CalendarScreen',
          operation: 'loadCalendarData',
          parameters: {
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
          },
        ),
      );

      if (result.success) {
        debugPrint('✅ Loaded ${result.data.length} habits for calendar');
        return result.data;
      } else {
        debugPrint('❌ Failed to load calendar data: ${result.errorMessage}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error loading calendar data: $e');
      return [];
    }
  }
}

/// Migration Guide: How to transition from old to new architecture
///
/// This provides step-by-step guidance for migrating existing code
class MigrationGuide {
  /// Step 1: Replace direct repository calls with atomic service
  static Future<void> exampleReplaceRepositoryCalls() async {
    // OLD WAY (spaghetti code):
    /*
    final habits = await _repository.getActiveHabitsForDashboard();
    final completions = <DateTime, CompletionRecord>{};
    for (final habit in habits) {
      // Complex logic to combine data...
    }
    */

    // NEW WAY (clean architecture):
    final result = await ServiceFactory.dashboardDataService.getDashboardHabits(
      context: DataAccessContext(
        component: 'DashboardScreen',
        operation: 'loadHabits',
      ),
    );

    if (result.success) {
      // Ready-to-use data - variable used to avoid warning
      final habits = result.data;
      debugPrint('Loaded ${habits.length} habits');
    }
  }

  /// Step 2: Replace complex habit operations with atomic operations
  static void exampleReplaceComplexOperations() {
    // OLD WAY (mixed concerns):
    /*
    final habit = await _repository.getHabitById(habitId);
    if (habit != null) {
      habit.completions[date] = CompletionRecord(count: count, goalAtCompletion: habit.targetGoal);
      await _repository.saveHabit(habit);
      await _cache.updateCompletion(habitId, date, count);
      // Mixed UI logic with data logic...
    }
    */

    // NEW WAY (atomic operations):
    _exampleAddCompletions('habit123', DateTime.now(), 3);
  }

  static Future<void> _exampleAddCompletions(String habitId, DateTime date, int count) async {
    final result = await ServiceFactory.atomicDataService.addCompletions(
      habitId: habitId,
      date: date,
      count: count,
      context: DataAccessContext(
        component: 'CompletionWidget',
        operation: 'addCompletion',
      ),
    );

    if (result.success) {
      // Operation completed successfully
    }
  }

  /// Step 3: Use data preparation services for UI-specific data
  static void exampleUseDataPreparation() {
    // Instead of complex data transformation in UI:
    /*
    final rawHabits = await _repository.getActiveHabits();
    final dashboardHabits = <Habit>[];
    for (final habit in rawHabits) {
      // Complex transformation logic...
      final completions = await _repository.getCompletionDataForHabit(habit.id, start, end);
      habit.completions.addAll(completions);
      if (!habit.isArchived) dashboardHabits.add(habit);
    }
    */

    // Use data preparation service:
    _exampleGetDashboardHabits();
  }

  static Future<List<Habit>> _exampleGetDashboardHabits() async {
    final result = await ServiceFactory.dashboardDataService.getDashboardHabits(
      context: DataAccessContext(
        component: 'DashboardScreen',
        operation: 'prepareDashboardData',
      ),
    );

    final dashboardHabits = result.success ? result.data : <Habit>[];
    return dashboardHabits;
  }

  /// Step 4: Add comprehensive logging
  static void exampleAddLogging() {
    // The new architecture automatically logs all operations with context:
    /*
    🔍 [DATA_ACCESS] DashboardScreen.loadHabits | Params: {screen: dashboard} - Started
    🔍 [DATA_ACCESS] DashboardDataPreparation.getMetadata | Params: {screen: dashboard} - Started
    ✅ [DATA_ACCESS] DashboardDataPreparation.getMetadata | Params: {screen: dashboard} - Completed in 15ms
    🔍 [DATA_ACCESS] DashboardDataPreparation.getCompletions | Params: {screen: dashboard} - Started
    ✅ [DATA_ACCESS] DashboardDataPreparation.getCompletions | Params: {screen: dashboard} - Completed in 45ms
    ✅ [DATA_ACCESS] DashboardScreen.loadHabits | Params: {screen: dashboard} - Completed in 60ms
    */
  }

  /// Migration Checklist:
  static const List<String> migrationSteps = [
    '✅ Phase 1: Foundation - Atomic service, interfaces, error handling',
    '🔄 Phase 2: Caching - Multi-level caching strategy',
    '⏳ Phase 3: UI Integration - Replace controllers one by one',
    '⏳ Phase 4: Migration Complete - Remove old code',
  ];

  /// Benefits of the new architecture:
  static const Map<String, String> benefits = {
    'testability': 'Easy mocking with interfaces for comprehensive unit tests',
    'maintainability': 'Single-purpose methods vs 1,800-line spaghetti code',
    'debugging': 'Structured logging shows exactly what data is accessed and why',
    'performance': 'Fine-grained caching and performance monitoring',
    'reliability': 'Circuit breakers and health checks prevent cascading failures',
    'extensibility': 'Clean interfaces make it easy to add new features',
  };
}
