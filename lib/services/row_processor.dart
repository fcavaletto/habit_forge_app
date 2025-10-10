import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import '../services/habit_metadata_cache_service.dart';
import '../utils/timezone_utils.dart';
import 'atomic_data_service.dart';
import 'caching_service.dart';
import 'data_access_monitor.dart';

/// Configuration for habit loading operations
class HabitLoadConfig {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool convertToLocal;
  final bool loadCompletions;
  final bool loadReminders;
  final bool loadFrequencyDays;

  const HabitLoadConfig({
    this.startDate,
    this.endDate,
    this.convertToLocal = true,
    this.loadCompletions = true,
    this.loadReminders = true,
    this.loadFrequencyDays = true,
  });

  /// Create config for metadata-only loading (fastest)
  const HabitLoadConfig.metadataOnly()
      : startDate = null,
        endDate = null,
        convertToLocal = false,
        loadCompletions = false,
        loadReminders = true,
        loadFrequencyDays = true;

  /// Create config for dashboard loading (last 7 days)
  factory HabitLoadConfig.dashboard() {
    final today = DateTime.now();
    final last7Days = today.subtract(const Duration(days: 6));
    return HabitLoadConfig(
      startDate: last7Days,
      endDate: today,
      convertToLocal: true,
      loadCompletions: true,
      loadReminders: true,
      loadFrequencyDays: true,
    );
  }

  /// Create config for stats loading (last 30 days)
  factory HabitLoadConfig.stats() {
    final today = DateTime.now();
    final last30Days = today.subtract(const Duration(days: 29));
    return HabitLoadConfig(
      startDate: last30Days,
      endDate: today,
      convertToLocal: true,
      loadCompletions: true,
      loadReminders: true,
      loadFrequencyDays: true,
    );
  }

  /// Create config for full data loading (all historical data)
  const HabitLoadConfig.fullData()
      : startDate = null,
        endDate = null,
        convertToLocal = true,
        loadCompletions = true,
        loadReminders = true,
        loadFrequencyDays = true;
}

/// Data structures for intermediate processing
// Using the existing HabitMetadata class from habit_metadata_cache_service.dart
// This provides all the metadata fields we need for processing

class ProcessedCompletions {
  final Map<DateTime, CompletionRecord> completions;

  const ProcessedCompletions(this.completions);
}

class ProcessedReminders {
  final TimeOfDay? reminderTime;
  final bool enableReminders;

  const ProcessedReminders({
    this.reminderTime,
    this.enableReminders = false,
  });
}

class ProcessedFrequency {
  final Map<String, int> frequencyDays;

  const ProcessedFrequency(this.frequencyDays);
}

/// Interface for metadata processing operations
abstract class IMetadataProcessor {
  Future<DataAccessResult<HabitMetadata>> processMetadata({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  });
}

/// Interface for completion processing operations
abstract class ICompletionProcessor {
  Future<DataAccessResult<ProcessedCompletions>> processCompletions({
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  });
}

/// Interface for reminder processing operations
abstract class IReminderProcessor {
  Future<DataAccessResult<ProcessedReminders>> processReminders({
    required String habitId,
    required DataAccessContext context,
  });
}

/// Interface for frequency processing operations
abstract class IFrequencyProcessor {
  Future<DataAccessResult<ProcessedFrequency>> processFrequency({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  });
}

/// Interface for habit assembly operations
abstract class IHabitAssembler {
  Future<DataAccessResult<Habit>> assembleHabit({
    required HabitMetadata metadata,
    ProcessedCompletions? completions,
    ProcessedReminders? reminders,
    ProcessedFrequency? frequency,
    required DataAccessContext context,
  });
}

/// Metadata Processor Implementation
class MetadataProcessor implements IMetadataProcessor {
  @override
  Future<DataAccessResult<HabitMetadata>> processMetadata({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [METADATA_PROCESSOR] Processing habit metadata: ${context.component}.${context.operation}');

      final metadata = HabitMetadata(
        id: row['id'] as String,
        name: row['name'] as String,
        description: (row['description'] as String?) ?? '',
        colorIndex: row['color_index'] as int,
        iconName: row['icon_name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int, isUtc: true),
        isArchived: (row['is_archived'] as int) == 1,
        orderValue: row['order_value'] as double?,
        frequencyDays: Habit.defaultFrequencyDays, // Default frequency
        targetGoal: row['target_goal'] as int,
        allowExceedGoal: (row['allow_exceed_goal'] as int) == 1,
        enableReminders: false, // Default to false
        reminderTime: null, // No reminder by default
      );

      stopwatch.stop();
      debugPrint('✅ [METADATA_PROCESSOR] Metadata processed in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: metadata,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [METADATA_PROCESSOR] Metadata processing failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process habit metadata: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }
}

/// Completion Processor Implementation
class CompletionProcessor implements ICompletionProcessor {
  final DatabaseService _databaseService;

  CompletionProcessor(this._databaseService);

  @override
  Future<DataAccessResult<ProcessedCompletions>> processCompletions({
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (!config.loadCompletions) {
        debugPrint('📅 [COMPLETION_PROCESSOR] Skipping completions (config.loadCompletions = false)');
        return DataAccessResult.success(
          data: ProcessedCompletions({}),
          context: context,
          executionTime: Duration.zero,
        );
      }

      debugPrint('🔍 [COMPLETION_PROCESSOR] Processing completions: ${context.component}.${context.operation}');

      final db = await _databaseService.database;
      final completions = <DateTime, CompletionRecord>{};

      // Build query with optional date filtering
      String whereClause = 'habit_id = ?';
      List<dynamic> whereArgs = [habitId];

      if (config.startDate != null && config.endDate != null) {
        whereClause += ' AND completion_date >= ? AND completion_date <= ?';
        whereArgs.addAll([
          TimezoneUtils.toUtcTimestamp(config.startDate!),
          TimezoneUtils.toUtcTimestamp(config.endDate!),
        ]);
      }

      final completionRows = await RetryUtils.executeWithCircuitBreakerAndRetry(
        operation: () => db.query(
          'habit_completions',
          where: whereClause,
          whereArgs: whereArgs,
        ),
        circuitBreaker: databaseCircuitBreaker,
        operationName: 'loadCompletions',
      );

      debugPrint('📅 [COMPLETION_PROCESSOR] Found ${completionRows.length} completion records for habit $habitId');

      // Use batch conversion for better performance (single log vs N logs)
      if (config.convertToLocal && completionRows.isNotEmpty) {
        final utcTimestamps = completionRows
            .map((row) => row['completion_date'] as int)
            .toList();
        
        final localDates = TimezoneUtils.batchFromUtcTimestamp(
          utcTimestamps,
          context: 'Habit $habitId completion dates',
        );
        
        for (var i = 0; i < completionRows.length; i++) {
          final row = completionRows[i];
          final date = localDates[i];
          final count = row['completion_count'] as int;
          final goalAtCompletion = row['goal_at_completion'] as int;
          completions[date] = CompletionRecord(
            count: count,
            goalAtCompletion: goalAtCompletion,
          );
        }
      } else {
        // Non-local conversion (raw UTC timestamps)
        for (final row in completionRows) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            row['completion_date'] as int,
            isUtc: true,
          );
          final count = row['completion_count'] as int;
          final goalAtCompletion = row['goal_at_completion'] as int;
          completions[date] = CompletionRecord(
            count: count,
            goalAtCompletion: goalAtCompletion,
          );
        }
      }

      stopwatch.stop();
      debugPrint('✅ [COMPLETION_PROCESSOR] Completions processed: ${completions.length} records in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: ProcessedCompletions(completions),
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [COMPLETION_PROCESSOR] Completions processing failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process completions: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }
}

/// Reminder Processor Implementation
class ReminderProcessor implements IReminderProcessor {
  final DatabaseService _databaseService;

  ReminderProcessor(this._databaseService);

  @override
  Future<DataAccessResult<ProcessedReminders>> processReminders({
    required String habitId,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [REMINDER_PROCESSOR] Processing reminders: ${context.component}.${context.operation}');

      final db = await _databaseService.database;

      final reminderRows = await RetryUtils.executeWithCircuitBreakerAndRetry(
        operation: () => db.query(
          'habit_reminders',
          where: 'habit_id = ?',
          whereArgs: [habitId],
        ),
        circuitBreaker: databaseCircuitBreaker,
        operationName: 'loadReminders',
      );

      TimeOfDay? reminderTime;
      bool enableReminders = false;

      if (reminderRows.isNotEmpty) {
        final row = reminderRows.first;
        enableReminders = (row['enable_reminders'] as int) == 1;
        if (enableReminders && row['reminder_time_hour'] != null) {
          reminderTime = TimeOfDay(
            hour: row['reminder_time_hour'] as int,
            minute: row['reminder_time_minute'] as int,
          );
        }
      }

      final processedReminders = ProcessedReminders(
        reminderTime: reminderTime,
        enableReminders: enableReminders,
      );

      stopwatch.stop();
      debugPrint('✅ [REMINDER_PROCESSOR] Reminders processed in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: processedReminders,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [REMINDER_PROCESSOR] Reminders processing failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to process reminders: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }
}

/// Frequency Processor Implementation
class FrequencyProcessor implements IFrequencyProcessor {
  @override
  Future<DataAccessResult<ProcessedFrequency>> processFrequency({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [FREQUENCY_PROCESSOR] Processing frequency days: ${context.component}.${context.operation}');

      // Parse frequency days from JSON
      final frequencyDaysJson = row['frequency_days'] as String;
      final frequencyDays = Map<String, int>.from(jsonDecode(frequencyDaysJson));

      final processedFrequency = ProcessedFrequency(frequencyDays);

      stopwatch.stop();
      debugPrint('✅ [FREQUENCY_PROCESSOR] Frequency days processed in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: processedFrequency,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [FREQUENCY_PROCESSOR] Frequency days processing failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      // Return default frequency days on error
      return DataAccessResult.success(
        data: const ProcessedFrequency(Habit.defaultFrequencyDays),
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }
}

/// Habit Assembler Implementation
class HabitAssembler implements IHabitAssembler {
  @override
  Future<DataAccessResult<Habit>> assembleHabit({
    required HabitMetadata metadata,
    ProcessedCompletions? completions,
    ProcessedReminders? reminders,
    ProcessedFrequency? frequency,
    required DataAccessContext context,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('🔍 [HABIT_ASSEMBLER] Assembling habit: ${context.component}.${context.operation}');

      final habit = Habit(
        id: metadata.id,
        name: metadata.name,
        description: metadata.description,
        colorIndex: metadata.colorIndex,
        createdAt: metadata.createdAt,
        completions: completions?.completions ?? {},
        iconName: metadata.iconName,
        reminderTime: reminders?.reminderTime,
        enableReminders: reminders?.enableReminders ?? false,
        isArchived: metadata.isArchived,
        orderValue: metadata.orderValue,
        frequencyDays: frequency?.frequencyDays ?? Habit.defaultFrequencyDays,
        targetGoal: metadata.targetGoal,
        allowExceedGoal: metadata.allowExceedGoal,
      );

      stopwatch.stop();
      debugPrint('✅ [HABIT_ASSEMBLER] Habit assembled in ${stopwatch.elapsedMilliseconds}ms');

      return DataAccessResult.success(
        data: habit,
        context: context,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [HABIT_ASSEMBLER] Habit assembly failed after ${stopwatch.elapsedMilliseconds}ms: $e');

      return DataAccessResult.failure(
        errorMessage: 'Failed to assemble habit: $e',
        context: context,
        executionTime: stopwatch.elapsed,
      );
    }
  }
}

/// Cached Row Processor Implementation
class CachedRowProcessor implements IRowProcessor {
  final IRowProcessor _processor;
  final ICachingService _cache;

  CachedRowProcessor(this._processor, this._cache);

  @override
  Future<DataAccessResult<HabitMetadata>> processHabitMetadata({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    // Metadata doesn't change often, so cache it
    final habitId = row['id'] as String;
    final cacheKey = 'metadata:$habitId';

    // Try to get from cache first
    final cachedData = await _cache.getCachedMetadata(cacheKey);
    if (cachedData != null && cachedData is Map<String, dynamic>) {
      final metadataData = cachedData['metadata'];
      if (metadataData != null && metadataData is Map<String, dynamic>) {
        final metadata = HabitMetadata(
          id: metadataData['id'] as String,
          name: metadataData['name'] as String,
          description: metadataData['description'] as String,
          colorIndex: metadataData['colorIndex'] as int,
          createdAt: DateTime.parse(metadataData['createdAt'] as String),
          iconName: metadataData['iconName'] as String,
          enableReminders: false, // Default to false
          isArchived: metadataData['isArchived'] as bool,
          orderValue: metadataData['orderValue'] as double?,
          frequencyDays: Habit.defaultFrequencyDays, // Default frequency
          targetGoal: metadataData['targetGoal'] as int,
          allowExceedGoal: metadataData['allowExceedGoal'] as bool,
        );

        DataAccessLogger.logCache(
          operation: 'processHabitMetadata',
          cacheType: 'metadata',
          key: cacheKey,
          hit: true,
        );
        return DataAccessResult.success(
          data: metadata,
          context: context,
          executionTime: Duration.zero,
        );
      }
    }

    DataAccessLogger.logCache(
      operation: 'processHabitMetadata',
      cacheType: 'metadata',
      key: cacheKey,
      hit: false,
    );

    final result = await _processor.processHabitMetadata(row: row, context: context);

    if (result.success) {
      // Cache the processed metadata
      await _cache.cacheMetadata([habitId], {
        'metadata': {
          'id': result.data.id,
          'name': result.data.name,
          'description': result.data.description,
          'colorIndex': result.data.colorIndex,
          'iconName': result.data.iconName,
          'createdAt': result.data.createdAt.toIso8601String(),
          'isArchived': result.data.isArchived,
          'orderValue': result.data.orderValue,
          'targetGoal': result.data.targetGoal,
          'allowExceedGoal': result.data.allowExceedGoal,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return result;
  }

  @override
  Future<DataAccessResult<ProcessedCompletions>> processCompletions({
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    // For simplicity, skip completion caching for now since it's complex with date ranges
    // The base processor will handle the actual processing
    return await _processor.processCompletions(
      habitId: habitId,
      config: config,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<ProcessedReminders>> processReminders({
    required String habitId,
    required DataAccessContext context,
  }) async {
    // Reminder data changes rarely, so cache it
    final cacheKey = 'reminders:$habitId';
    final cached = await _cache.getCachedMetadata(cacheKey);

    if (cached != null && cached is Map<String, dynamic>) {
      final remindersData = cached['reminders'];
      if (remindersData != null) {
        final reminders = ProcessedReminders(
          reminderTime: remindersData['reminderTime'] != null
              ? TimeOfDay(hour: remindersData['reminderTime']['hour'], minute: remindersData['reminderTime']['minute'])
              : null,
          enableReminders: remindersData['enableReminders'] ?? false,
        );

        DataAccessLogger.logCache(
          operation: 'processReminders',
          cacheType: 'reminders',
          key: cacheKey,
          hit: true,
        );
        return DataAccessResult.success(
          data: reminders,
          context: context,
          executionTime: Duration.zero,
        );
      }
    }

    DataAccessLogger.logCache(
      operation: 'processReminders',
      cacheType: 'reminders',
      key: cacheKey,
      hit: false,
    );

    final result = await _processor.processReminders(habitId: habitId, context: context);

    if (result.success) {
      await _cache.cacheMetadata([habitId], {
        'reminders': {
          'reminderTime': result.data.reminderTime != null ? {
            'hour': result.data.reminderTime!.hour,
            'minute': result.data.reminderTime!.minute,
          } : null,
          'enableReminders': result.data.enableReminders,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return result;
  }

  @override
  Future<DataAccessResult<ProcessedFrequency>> processFrequencyDays({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    // Frequency data changes rarely, so cache it
    final habitId = row['id'] as String;
    final cacheKey = 'frequency:$habitId';

    final cached = await _cache.getCachedMetadata(cacheKey);

    if (cached != null && cached is Map<String, dynamic>) {
      final frequencyData = cached['frequency'];
      if (frequencyData != null) {
        final frequency = ProcessedFrequency(frequencyData as Map<String, int>);

        DataAccessLogger.logCache(
          operation: 'processFrequencyDays',
          cacheType: 'frequency',
          key: cacheKey,
          hit: true,
        );
        return DataAccessResult.success(
          data: frequency,
          context: context,
          executionTime: Duration.zero,
        );
      }
    }

    DataAccessLogger.logCache(
      operation: 'processFrequencyDays',
      cacheType: 'frequency',
      key: cacheKey,
      hit: false,
    );

    final result = await _processor.processFrequencyDays(row: row, context: context);

    if (result.success) {
      await _cache.cacheMetadata([habitId], {
        'frequency': result.data.frequencyDays,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return result;
  }

  @override
  Future<DataAccessResult<Habit>> assembleHabit({
    required HabitMetadata metadata,
    ProcessedCompletions? completions,
    ProcessedReminders? reminders,
    ProcessedFrequency? frequency,
    required DataAccessContext context,
  }) async {
    // Assembly doesn't need caching as it's just combining data
    return await _processor.assembleHabit(
      metadata: metadata,
      completions: completions,
      reminders: reminders,
      frequency: frequency,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<Habit>> processHabitFromRow({
    required Map<String, dynamic> row,
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    // For complete habit processing, we could cache the final result
    // but for now, let it go through the normal flow with individual caching
    return await _processor.processHabitFromRow(
      row: row,
      habitId: habitId,
      config: config,
      context: context,
    );
  }
}

/// Row Processor Implementation
class RowProcessor implements IRowProcessor {
  final IMetadataProcessor _metadataProcessor;
  final ICompletionProcessor _completionProcessor;
  final IReminderProcessor _reminderProcessor;
  final IFrequencyProcessor _frequencyProcessor;
  final IHabitAssembler _habitAssembler;

  RowProcessor({
    required IMetadataProcessor metadataProcessor,
    required ICompletionProcessor completionProcessor,
    required IReminderProcessor reminderProcessor,
    required IFrequencyProcessor frequencyProcessor,
    required IHabitAssembler habitAssembler,
  })  : _metadataProcessor = metadataProcessor,
        _completionProcessor = completionProcessor,
        _reminderProcessor = reminderProcessor,
        _frequencyProcessor = frequencyProcessor,
        _habitAssembler = habitAssembler;

  @override
  Future<DataAccessResult<HabitMetadata>> processHabitMetadata({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    return await _metadataProcessor.processMetadata(row: row, context: context);
  }

  @override
  Future<DataAccessResult<ProcessedCompletions>> processCompletions({
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    return await _completionProcessor.processCompletions(
      habitId: habitId,
      config: config,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<ProcessedReminders>> processReminders({
    required String habitId,
    required DataAccessContext context,
  }) async {
    return await _reminderProcessor.processReminders(habitId: habitId, context: context);
  }

  @override
  Future<DataAccessResult<ProcessedFrequency>> processFrequencyDays({
    required Map<String, dynamic> row,
    required DataAccessContext context,
  }) async {
    return await _frequencyProcessor.processFrequency(row: row, context: context);
  }

  @override
  Future<DataAccessResult<Habit>> assembleHabit({
    required HabitMetadata metadata,
    ProcessedCompletions? completions,
    ProcessedReminders? reminders,
    ProcessedFrequency? frequency,
    required DataAccessContext context,
  }) async {
    return await _habitAssembler.assembleHabit(
      metadata: metadata,
      completions: completions,
      reminders: reminders,
      frequency: frequency,
      context: context,
    );
  }

  @override
  Future<DataAccessResult<Habit>> processHabitFromRow({
    required Map<String, dynamic> row,
    required String habitId,
    required HabitLoadConfig config,
    required DataAccessContext context,
  }) async {
    // Process components in parallel for better performance
    final metadataFuture = processHabitMetadata(row: row, context: context);
    final frequencyFuture = config.loadFrequencyDays
        ? processFrequencyDays(row: row, context: context)
        : Future.value(DataAccessResult.success(data: ProcessedFrequency(Habit.defaultFrequencyDays), context: context, executionTime: Duration.zero));

    // Process metadata and frequency in parallel
    final results = await Future.wait([
      metadataFuture,
      frequencyFuture,
    ]);

    final metadataResult = results[0] as DataAccessResult<HabitMetadata>;
    final frequencyResult = results[1] as DataAccessResult<ProcessedFrequency>;

    if (!metadataResult.success) {
      return DataAccessResult.failure(
        errorMessage: 'Failed to process metadata: ${metadataResult.errorMessage}',
        context: context,
        executionTime: Duration.zero,
      );
    }

    // Process completions and reminders in parallel
    final completionFuture = processCompletions(
      habitId: habitId,
      config: config,
      context: context,
    );

    final reminderFuture = config.loadReminders
        ? processReminders(habitId: habitId, context: context)
        : Future.value(DataAccessResult.success(data: ProcessedReminders(), context: context, executionTime: Duration.zero));

    final asyncResults = await Future.wait([
      completionFuture,
      reminderFuture,
    ]);

    final completionResult = asyncResults[0] as DataAccessResult<ProcessedCompletions>;
    final reminderResult = asyncResults[1] as DataAccessResult<ProcessedReminders>;

    if (!completionResult.success) {
      return DataAccessResult.failure(
        errorMessage: 'Failed to process completions: ${completionResult.errorMessage}',
        context: context,
        executionTime: Duration.zero,
      );
    }

    if (!reminderResult.success) {
      return DataAccessResult.failure(
        errorMessage: 'Failed to process reminders: ${reminderResult.errorMessage}',
        context: context,
        executionTime: Duration.zero,
      );
    }

    // Assemble the complete habit
    return await assembleHabit(
      metadata: metadataResult.data,
      completions: completionResult.data,
      reminders: reminderResult.data,
      frequency: frequencyResult.data,
      context: context,
    );
  }
}

/// Factory for creating row processors
class RowProcessorFactory {
  static IRowProcessor create(DatabaseService databaseService, ICachingService cache) {
    // Create smaller processors
    final metadataProcessor = MetadataProcessor();
    final completionProcessor = CompletionProcessor(databaseService);
    final reminderProcessor = ReminderProcessor(databaseService);
    final frequencyProcessor = FrequencyProcessor();
    final habitAssembler = HabitAssembler();

    // Create composed processor
    final baseProcessor = RowProcessor(
      metadataProcessor: metadataProcessor,
      completionProcessor: completionProcessor,
      reminderProcessor: reminderProcessor,
      frequencyProcessor: frequencyProcessor,
      habitAssembler: habitAssembler,
    );

    return CachedRowProcessor(baseProcessor, cache);
  }

  static IRowProcessor createWithMock() {
    // TODO: Create mock implementation for testing
    final metadataProcessor = MetadataProcessor();
    final completionProcessor = CompletionProcessor(DatabaseService());
    final reminderProcessor = ReminderProcessor(DatabaseService());
    final frequencyProcessor = FrequencyProcessor();
    final habitAssembler = HabitAssembler();

    return RowProcessor(
      metadataProcessor: metadataProcessor,
      completionProcessor: completionProcessor,
      reminderProcessor: reminderProcessor,
      frequencyProcessor: frequencyProcessor,
      habitAssembler: habitAssembler,
    );
  }
}
