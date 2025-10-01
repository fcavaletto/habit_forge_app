import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:habit_forge_app/models/habit.dart';
import 'package:habit_forge_app/providers/habit_provider.dart';
import 'package:habit_forge_app/repositories/sqlite_habit_repository.dart';

import 'phase1_performance_benchmark.mocks.dart';

@GenerateMocks([SqliteHabitRepository])
void main() {
  group('Phase 1 Performance Benchmark Tests', () {
    late MockSqliteHabitRepository mockRepository;
    late HabitProvider habitProvider;

    setUp(() {
      mockRepository = MockSqliteHabitRepository();
      habitProvider = HabitProvider(mockRepository);
    });

    group('Database Query Count Benchmarks', () {
      test('should reduce database queries from 5-15 to 1-2 per completion', () async {
        // Arrange
        final habitId = 'benchmark-habit-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Benchmark Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 5,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository to track calls
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 3);

        // Assert
        // Should only call addMultipleCompletions once (not multiple individual calls)
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 3)).called(1);
        
        // Should NOT call getHabitById (eliminated redundant reloading)
        verifyNever(mockRepository.getHabitById(any));
        
        // Should NOT call addHabitCompletion multiple times
        verifyNever(mockRepository.addHabitCompletion(any, any));
      });

      test('should handle multi-goal habit efficiently (0 to 5 completions)', () async {
        // Arrange
        final habitId = 'benchmark-habit-2';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Multi-Goal Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 5,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 5);

        // Assert
        // Should call addMultipleCompletions once with count=5
        // NOT 5 separate calls to addHabitCompletion
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 5)).called(1);
        verifyNever(mockRepository.addHabitCompletion(any, any));
      });
    });

    group('UI Response Time Benchmarks', () {
      test('should provide instant UI response (under 5ms)', () async {
        // Arrange
        final habitId = 'response-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Response Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository with delay to simulate database operation
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 100)); // Simulate DB delay
        });

        // Act
        final stopwatch = Stopwatch()..start();
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);
        stopwatch.stop();

        // Assert
        // UI should respond instantly (under 5ms) due to optimistic updates
        expect(stopwatch.elapsedMilliseconds, lessThan(5));
        
        // Verify UI was updated immediately
        final updatedHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(updatedHabit.getCompletionCount(testDate), equals(2));
      });

      test('should handle rapid tapping without performance degradation', () async {
        // Arrange
        final habitId = 'rapid-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Rapid Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 10,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act - Simulate rapid tapping
        final stopwatch = Stopwatch()..start();
        for (int i = 1; i <= 10; i++) {
          await habitProvider.updateHabitCompletion(habitId, testDate, i);
        }
        stopwatch.stop();

        // Assert
        // All 10 updates should complete quickly due to optimistic updates
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
        
        // Final state should be correct
        final finalHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(finalHabit.getCompletionCount(testDate), equals(10));
      });
    });

    group('Memory Usage Benchmarks', () {
      test('should not reload full habit objects unnecessarily', () async {
        // Arrange
        final habitId = 'memory-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Memory Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);

        // Assert
        // Should NOT call getHabitById (which would reload full habit)
        verifyNever(mockRepository.getHabitById(habitId));
        
        // Should use existing habit object in memory
        final updatedHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(updatedHabit.getCompletionCount(testDate), equals(2));
      });
    });

    group('Error Recovery Benchmarks', () {
      test('should recover from database errors quickly', () async {
        // Arrange
        final habitId = 'error-recovery-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Error Recovery Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository to throw error
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenThrow(Exception('Database error'));

        // Act
        final stopwatch = Stopwatch()..start();
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);
        stopwatch.stop();

        // Assert
        // Error recovery should be fast (under 10ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
        
        // Should rollback to original state
        final rolledBackHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(rolledBackHabit.getCompletionCount(testDate), equals(0));
        
        // Should set error message
        expect(habitProvider.error, contains('Failed to sync completion to database'));
      });
    });

    group('Concurrent Operations Benchmarks', () {
      test('should handle concurrent completion updates efficiently', () async {
        // Arrange
        final habitId = 'concurrent-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Concurrent Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 10,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act - Simulate concurrent updates
        final stopwatch = Stopwatch()..start();
        final futures = <Future>[];
        for (int i = 1; i <= 5; i++) {
          futures.add(habitProvider.updateHabitCompletion(habitId, testDate, i));
        }
        await Future.wait(futures);
        stopwatch.stop();

        // Assert
        // All concurrent updates should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        
        // Final state should be correct (last update wins)
        final finalHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(finalHabit.getCompletionCount(testDate), equals(5));
      });
    });

    group('Reset Operations Benchmarks', () {
      test('should reset completions efficiently with optimistic updates', () async {
        // Arrange
        final habitId = 'reset-benchmark-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Reset Benchmark Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 5,
          completions: {testDate: 5}, // Start with 5 completions
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.removeAllCompletionsForDate(any, any))
            .thenAnswer((_) async {});

        // Act
        final stopwatch = Stopwatch()..start();
        await habitProvider.resetAllCompletionsForDate(habitId, testDate);
        stopwatch.stop();

        // Assert
        // Reset should be instant due to optimistic updates
        expect(stopwatch.elapsedMilliseconds, lessThan(5));
        
        // Should reset to 0 immediately
        final resetHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(resetHabit.getCompletionCount(testDate), equals(0));
      });
    });
  });
}
