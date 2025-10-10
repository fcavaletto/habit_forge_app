import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import 'atomic_data_service.dart';

/// Dashboard Data Preparation Service
///
/// Combines atomic data operations to provide UI-ready habit data for the dashboard.
/// Handles the complex logic of combining metadata with completion data for display.
class DashboardDataPreparationService implements IDataPreparationService {
  final IAtomicDataService _atomicService;

  DashboardDataPreparationService(this._atomicService);

  @override
  Future<DataAccessResult<List<Habit>>> getDashboardHabits({
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('📊 [DASHBOARD] Preparing dashboard habits: ${context.component}.${context.operation}');

      // Get habit metadata first (fast operation)
      final metadataResult = await _atomicService.getHabitFeatures(
        context: DataAccessContext(
          component: 'DashboardDataPreparation',
          operation: 'getMetadata',
          parameters: context.parameters,
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

      // Get completion data for the last 7 days (dashboard-optimized)
      final today = DateTime.now();
      final last7Days = today.subtract(const Duration(days: 6));

      final completionsResult = await _atomicService.getCompletionTimestamps(
        startDate: last7Days,
        endDate: today,
        context: DataAccessContext(
          component: 'DashboardDataPreparation',
          operation: 'getCompletions',
          parameters: context.parameters,
        ),
      );

      if (!completionsResult.success || completionsResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get completion data: ${completionsResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      // Combine metadata with completion data
      final dashboardHabits = <Habit>[];

      for (final metadata in metadataResult.data!) {
        // Skip archived habits for dashboard
        if (metadata.isArchived) continue;

        // Get completion data for this habit
        final habitCompletions = completionsResult.data![metadata.id] ?? {};

        // Create habit with combined data
        final habit = Habit(
          id: metadata.id,
          name: metadata.name,
          description: metadata.description,
          colorIndex: metadata.colorIndex,
          createdAt: metadata.createdAt,
          completions: habitCompletions,
          iconName: metadata.iconName,
          reminderTime: metadata.reminderTime,
          enableReminders: metadata.enableReminders,
          isArchived: metadata.isArchived,
          orderValue: metadata.orderValue,
          frequencyDays: metadata.frequencyDays,
          targetGoal: metadata.targetGoal,
          allowExceedGoal: metadata.allowExceedGoal,
        );
        dashboardHabits.add(habit);
      }

      // Sort by display order
      dashboardHabits.sort((a, b) {
        final aOrder = a.orderValue ?? 0.0;
        final bOrder = b.orderValue ?? 0.0;
        return bOrder.compareTo(aOrder); // Descending order (higher values first)
      });

      stopwatch.stop();
      debugPrint('✅ [DASHBOARD] Prepared ${dashboardHabits.length} dashboard habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: dashboardHabits,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [DASHBOARD] Failed to prepare dashboard habits after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to prepare dashboard habits: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<List<Habit>>> getStatsHabits({
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('📊 [STATS] Preparing stats habits: ${context.component}.${context.operation}');

      // Get habit metadata first
      final metadataResult = await _atomicService.getHabitFeatures(
        context: DataAccessContext(
          component: 'StatsDataPreparation',
          operation: 'getMetadata',
          parameters: context.parameters,
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

      // Get completion data for the last 30 days (stats-optimized)
      final today = DateTime.now();
      final last30Days = today.subtract(const Duration(days: 29));

      final completionsResult = await _atomicService.getCompletionTimestamps(
        startDate: last30Days,
        endDate: today,
        context: DataAccessContext(
          component: 'StatsDataPreparation',
          operation: 'getCompletions',
          parameters: context.parameters,
        ),
      );

      if (!completionsResult.success || completionsResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get completion data: ${completionsResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      // Combine metadata with completion data
      final statsHabits = <Habit>[];

      for (final metadata in metadataResult.data!) {
        // Get completion data for this habit
        final habitCompletions = completionsResult.data![metadata.id] ?? {};

        // Create habit with combined data
        final habit = Habit(
          id: metadata.id,
          name: metadata.name,
          description: metadata.description,
          colorIndex: metadata.colorIndex,
          createdAt: metadata.createdAt,
          completions: habitCompletions,
          iconName: metadata.iconName,
          reminderTime: metadata.reminderTime,
          enableReminders: metadata.enableReminders,
          isArchived: metadata.isArchived,
          orderValue: metadata.orderValue,
          frequencyDays: metadata.frequencyDays,
          targetGoal: metadata.targetGoal,
          allowExceedGoal: metadata.allowExceedGoal,
        );
        statsHabits.add(habit);
      }

      // Sort by display order
      statsHabits.sort((a, b) {
        final aOrder = a.orderValue ?? 0.0;
        final bOrder = b.orderValue ?? 0.0;
        return bOrder.compareTo(aOrder);
      });

      stopwatch.stop();
      debugPrint('✅ [STATS] Prepared ${statsHabits.length} stats habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: statsHabits,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [STATS] Failed to prepare stats habits after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to prepare stats habits: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<List<Habit>>> getCalendarHabits({
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('📊 [CALENDAR] Preparing calendar habits: ${context.component}.${context.operation}');

      // Validate date range
      if (startDate.isAfter(endDate)) {
        throw DataValidationException(
          'Start date cannot be after end date',
          DataAccessContext(component: 'CalendarDataPreparation', operation: 'validation'),
        );
      }

      if (endDate.difference(startDate).inDays > 365) {
        throw DataValidationException(
          'Date range cannot exceed 365 days',
          DataAccessContext(component: 'CalendarDataPreparation', operation: 'validation'),
        );
      }

      // Get habit metadata first
      final metadataResult = await _atomicService.getHabitFeatures(
        context: DataAccessContext(
          component: 'CalendarDataPreparation',
          operation: 'getMetadata',
          parameters: context.parameters,
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

      // Get completion data for the specified date range
      final completionsResult = await _atomicService.getCompletionTimestamps(
        startDate: startDate,
        endDate: endDate,
        context: DataAccessContext(
          component: 'CalendarDataPreparation',
          operation: 'getCompletions',
          parameters: context.parameters,
        ),
      );

      if (!completionsResult.success || completionsResult.data == null) {
        stopwatch.stop();
        return DataAccessResult.failure(
          errorMessage: 'Failed to get completion data: ${completionsResult.errorMessage}',
          context: context,
          executionTime: stopwatch.elapsed,
        );
      }

      // Combine metadata with completion data
      final calendarHabits = <Habit>[];

      for (final metadata in metadataResult.data!) {
        // Get completion data for this habit
        final habitCompletions = completionsResult.data![metadata.id] ?? {};

        // Create habit with combined data
        final habit = Habit(
          id: metadata.id,
          name: metadata.name,
          description: metadata.description,
          colorIndex: metadata.colorIndex,
          createdAt: metadata.createdAt,
          completions: habitCompletions,
          iconName: metadata.iconName,
          reminderTime: metadata.reminderTime,
          enableReminders: metadata.enableReminders,
          isArchived: metadata.isArchived,
          orderValue: metadata.orderValue,
          frequencyDays: metadata.frequencyDays,
          targetGoal: metadata.targetGoal,
          allowExceedGoal: metadata.allowExceedGoal,
        );
        calendarHabits.add(habit);
      }

      // Sort by display order
      calendarHabits.sort((a, b) {
        final aOrder = a.orderValue ?? 0.0;
        final bOrder = b.orderValue ?? 0.0;
        return bOrder.compareTo(aOrder);
      });

      stopwatch.stop();
      debugPrint('✅ [CALENDAR] Prepared ${calendarHabits.length} calendar habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: calendarHabits,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [CALENDAR] Failed to prepare calendar habits after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to prepare calendar habits: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<DataAccessResult<List<Habit>>> getReorderableHabits({
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('📊 [REORDER] Preparing reorderable habits: ${context.component}.${context.operation}');

      // Get only metadata (no completion data needed for reordering)
      final metadataResult = await _atomicService.getHabitFeatures(
        context: DataAccessContext(
          component: 'ReorderDataPreparation',
          operation: 'getMetadata',
          parameters: context.parameters,
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

      // Convert metadata to habits (empty completions for reordering)
      final reorderableHabits = metadataResult.data!
          .map((metadata) => Habit(
            id: metadata.id,
            name: metadata.name,
            description: metadata.description,
            colorIndex: metadata.colorIndex,
            createdAt: metadata.createdAt,
            completions: {}, // Empty completions for reordering
            iconName: metadata.iconName,
            reminderTime: metadata.reminderTime,
            enableReminders: metadata.enableReminders,
            isArchived: metadata.isArchived,
            orderValue: metadata.orderValue,
            frequencyDays: metadata.frequencyDays,
            targetGoal: metadata.targetGoal,
            allowExceedGoal: metadata.allowExceedGoal,
          ))
          .toList();

      // Sort by display order
      reorderableHabits.sort((a, b) {
        final aOrder = a.orderValue ?? 0.0;
        final bOrder = b.orderValue ?? 0.0;
        return bOrder.compareTo(aOrder);
      });

      stopwatch.stop();
      debugPrint('✅ [REORDER] Prepared ${reorderableHabits.length} reorderable habits in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: reorderableHabits,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [REORDER] Failed to prepare reorderable habits after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to prepare reorderable habits: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }
}

/// Factory for creating data preparation services
class DataPreparationServiceFactory {
  static IDataPreparationService createDashboardService(IAtomicDataService atomicService) {
    return DashboardDataPreparationService(atomicService);
  }

  static IDataPreparationService createStatsService(IAtomicDataService atomicService) {
    return StatsDataPreparationService(atomicService);
  }

  static IDataPreparationService createCalendarService(IAtomicDataService atomicService) {
    return CalendarDataPreparationService(atomicService);
  }

  static IDataPreparationService createReorderService(IAtomicDataService atomicService) {
    return ReorderDataPreparationService(atomicService);
  }
}

/// Stats-specific data preparation service
class StatsDataPreparationService implements IDataPreparationService {
  final IAtomicDataService _atomicService;

  StatsDataPreparationService(this._atomicService);

  @override
  Future<DataAccessResult<List<Habit>>> getDashboardHabits({required DataAccessContext context}) {
    throw UnimplementedError('Use DashboardDataPreparationService for dashboard data');
  }

  @override
  Future<DataAccessResult<List<Habit>>> getStatsHabits({required DataAccessContext context}) async {
    return DashboardDataPreparationService(_atomicService).getStatsHabits(context: context);
  }

  @override
  Future<DataAccessResult<List<Habit>>> getCalendarHabits({
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  }) async {
    return DashboardDataPreparationService(_atomicService).getCalendarHabits(
      startDate: startDate,
      endDate: endDate,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<List<Habit>>> getReorderableHabits({required DataAccessContext context}) async {
    return DashboardDataPreparationService(_atomicService).getReorderableHabits(context: context);
  }
}

/// Calendar-specific data preparation service
class CalendarDataPreparationService implements IDataPreparationService {
  final IAtomicDataService _atomicService;

  CalendarDataPreparationService(this._atomicService);

  @override
  Future<DataAccessResult<List<Habit>>> getDashboardHabits({required DataAccessContext context}) {
    throw UnimplementedError('Use DashboardDataPreparationService for dashboard data');
  }

  @override
  Future<DataAccessResult<List<Habit>>> getStatsHabits({required DataAccessContext context}) async {
    return DashboardDataPreparationService(_atomicService).getStatsHabits(context: context);
  }

  @override
  Future<DataAccessResult<List<Habit>>> getCalendarHabits({
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  }) async {
    return DashboardDataPreparationService(_atomicService).getCalendarHabits(
      startDate: startDate,
      endDate: endDate,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<List<Habit>>> getReorderableHabits({required DataAccessContext context}) async {
    return DashboardDataPreparationService(_atomicService).getReorderableHabits(context: context);
  }
}

/// Reorder-specific data preparation service
class ReorderDataPreparationService implements IDataPreparationService {
  final IAtomicDataService _atomicService;

  ReorderDataPreparationService(this._atomicService);

  @override
  Future<DataAccessResult<List<Habit>>> getDashboardHabits({required DataAccessContext context}) {
    throw UnimplementedError('Use DashboardDataPreparationService for dashboard data');
  }

  @override
  Future<DataAccessResult<List<Habit>>> getStatsHabits({required DataAccessContext context}) async {
    return DashboardDataPreparationService(_atomicService).getStatsHabits(context: context);
  }

  @override
  Future<DataAccessResult<List<Habit>>> getCalendarHabits({
    required DateTime startDate,
    required DateTime endDate,
    required DataAccessContext context,
  }) async {
    return DashboardDataPreparationService(_atomicService).getCalendarHabits(
      startDate: startDate,
      endDate: endDate,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<List<Habit>>> getReorderableHabits({required DataAccessContext context}) async {
    return DashboardDataPreparationService(_atomicService).getReorderableHabits(context: context);
  }
}
