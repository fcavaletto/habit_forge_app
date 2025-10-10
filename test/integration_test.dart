import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/models/habit.dart';
import '../lib/services/atomic_data_service.dart';
import '../lib/services/caching_service.dart';
import '../lib/services/row_processor.dart';
import '../lib/services/data_preparation_service.dart';
import '../lib/services/habit_metadata_cache_service.dart';

void main() {
  group('New Architecture Integration Tests', () {
    test('should create and use the complete architecture', () async {
      // Test that we can create all the services
      final cache = MemoryCachingService();

      // Create a basic test that validates the architecture structure
      expect(cache, isNotNull);
      expect(HabitLoadConfig.metadataOnly().loadCompletions, false);
      expect(HabitLoadConfig.dashboard().loadCompletions, true);
    });

    test('should handle HabitLoadConfig correctly', () {
      // Test different config types
      const metadataOnly = HabitLoadConfig.metadataOnly();
      expect(metadataOnly.loadCompletions, false);
      expect(metadataOnly.loadReminders, true);

      final dashboard = HabitLoadConfig.dashboard();
      expect(dashboard.loadCompletions, true);
      expect(dashboard.convertToLocal, true);

      const fullData = HabitLoadConfig.fullData();
      expect(fullData.loadCompletions, true);
      expect(fullData.loadReminders, true);
    });

    test('should process HabitMetadata correctly', () {
      final metadata = HabitMetadata(
        id: 'test-habit',
        name: 'Test Habit',
        description: 'Test Description',
        colorIndex: 1,
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        enableReminders: false,
        isArchived: false,
        frequencyDays: Habit.defaultFrequencyDays,
        targetGoal: 1,
        allowExceedGoal: false,
      );

      expect(metadata.id, 'test-habit');
      expect(metadata.name, 'Test Habit');
      expect(metadata.colorIndex, 1);
      expect(metadata.isArchived, false);
    });

    test('should convert HabitMetadata to Habit', () {
      final metadata = HabitMetadata(
        id: 'test-habit',
        name: 'Test Habit',
        description: 'Test Description',
        colorIndex: 1,
        iconName: 'fitness_center',
        createdAt: DateTime.now(),
        enableReminders: false,
        isArchived: false,
        frequencyDays: Habit.defaultFrequencyDays,
        targetGoal: 1,
        allowExceedGoal: false,
      );

      final habit = Habit(
        id: metadata.id,
        name: metadata.name,
        description: metadata.description,
        colorIndex: metadata.colorIndex,
        createdAt: metadata.createdAt,
        completions: {},
        iconName: metadata.iconName,
        reminderTime: metadata.reminderTime,
        enableReminders: metadata.enableReminders,
        isArchived: metadata.isArchived,
        orderValue: metadata.orderValue,
        frequencyDays: metadata.frequencyDays,
        targetGoal: metadata.targetGoal,
        allowExceedGoal: metadata.allowExceedGoal,
      );

      expect(habit.id, 'test-habit');
      expect(habit.name, 'Test Habit');
      expect(habit.colorIndex, 1);
      expect(habit.completions, isEmpty);
    });

    test('should handle ProcessedCompletions correctly', () {
      final completions = {
        DateTime(2024, 1, 1): CompletionRecord(count: 1, goalAtCompletion: 1),
        DateTime(2024, 1, 2): CompletionRecord(count: 2, goalAtCompletion: 2),
      };

      final processed = ProcessedCompletions(completions);

      expect(processed.completions, hasLength(2));
      expect(processed.completions[DateTime(2024, 1, 1)]?.count, 1);
    });

    test('should handle ProcessedReminders correctly', () {
      final reminders = ProcessedReminders(
        reminderTime: TimeOfDay(hour: 8, minute: 30),
        enableReminders: true,
      );

      expect(reminders.enableReminders, true);
      expect(reminders.reminderTime?.hour, 8);
      expect(reminders.reminderTime?.minute, 30);
    });

    test('should handle ProcessedFrequency correctly', () {
      final frequency = ProcessedFrequency({
        'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 0, 'sun': 0,
      });

      expect(frequency.frequencyDays['mon'], 1);
      expect(frequency.frequencyDays['sat'], 0);
    });

    test('should create HabitData for testing', () {
      final habitData = HabitData(
        name: 'Test Habit',
        description: 'Test Description',
        colorIndex: 1,
        targetGoal: 2,
      );

      expect(habitData.name, 'Test Habit');
      expect(habitData.targetGoal, 2);
      expect(habitData.colorIndex, 1);
    });

    test('should validate HabitData correctly', () {
      // Valid data
      final validData = HabitData(name: 'Valid Habit');
      expect(() => validData.validate(), returnsNormally);

      // Invalid data
      final invalidData = HabitData(name: '');
      expect(() => invalidData.validate(), throwsA(isA<DataValidationException>()));

      final invalidColorData = HabitData(name: 'Test', colorIndex: -1);
      expect(() => invalidColorData.validate(), throwsA(isA<DataValidationException>()));
    });

    test('should handle DataAccessContext correctly', () {
      final context = DataAccessContext(
        component: 'TestComponent',
        operation: 'testOperation',
        parameters: {'key': 'value'},
      );

      expect(context.component, 'TestComponent');
      expect(context.operation, 'testOperation');
      expect(context.parameters['key'], 'value');
    });

    test('should handle DataAccessResult correctly', () {
      final context = DataAccessContext(
        component: 'Test',
        operation: 'test',
      );

      final successResult = DataAccessResult.success(
        data: 'test data',
        context: context,
        executionTime: const Duration(milliseconds: 100),
      );

      expect(successResult.success, true);
      expect(successResult.data, 'test data');
      expect(successResult.executionTime, const Duration(milliseconds: 100));

      final failureResult = DataAccessResult.failure(
        errorMessage: 'Test error',
        context: context,
        executionTime: const Duration(milliseconds: 50),
      );

      expect(failureResult.success, false);
      expect(failureResult.errorMessage, 'Test error');
    });

    test('should create basic Habit objects for testing', () {
      final habit = Habit.createWithUuid(
        name: 'Test Habit',
        description: 'Test Description',
        colorIndex: 1,
        targetGoal: 2,
      );

      expect(habit.name, 'Test Habit');
      expect(habit.targetGoal, 2);
      expect(habit.colorIndex, 1);
      expect(habit.completions, isEmpty);
    });

    test('should handle Habit operations correctly', () {
      final habit = Habit.createWithUuid(
        name: 'Test Habit',
        targetGoal: 2,
      );

      // Mark as completed
      final completedHabit = habit.markCompleted(DateTime.now(), 2);
      expect(completedHabit.getCompletionCount(DateTime.now()), 2);
      expect(completedHabit.isGoalAchieved(DateTime.now()), true);

      // Test streak calculation
      expect(completedHabit.currentStreak, 1);
    });

    test('should handle HabitMetadata operations', () {
      final habit = Habit.createWithUuid(name: 'Test Habit');
      final metadata = HabitMetadata(
        id: habit.id,
        name: habit.name,
        description: habit.description,
        colorIndex: habit.colorIndex,
        createdAt: habit.createdAt,
        iconName: habit.iconName,
        enableReminders: habit.enableReminders,
        isArchived: habit.isArchived,
        orderValue: habit.orderValue,
        frequencyDays: habit.frequencyDays,
        targetGoal: habit.targetGoal,
        allowExceedGoal: habit.allowExceedGoal,
      );

      expect(metadata.name, 'Test Habit');
      expect(metadata.id, habit.id);
      expect(metadata.targetGoal, habit.targetGoal);

      final restoredHabit = Habit(
        id: metadata.id,
        name: metadata.name,
        description: metadata.description,
        colorIndex: metadata.colorIndex,
        createdAt: metadata.createdAt,
        completions: {},
        iconName: metadata.iconName,
        reminderTime: metadata.reminderTime,
        enableReminders: metadata.enableReminders,
        isArchived: metadata.isArchived,
        orderValue: metadata.orderValue,
        frequencyDays: metadata.frequencyDays,
        targetGoal: metadata.targetGoal,
        allowExceedGoal: metadata.allowExceedGoal,
      );
      expect(restoredHabit.name, 'Test Habit');
      expect(restoredHabit.completions, isEmpty);
    });
  });
}
