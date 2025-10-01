import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:habit_forge_app/models/habit.dart';
import 'package:habit_forge_app/providers/habit_provider.dart';
import 'package:habit_forge_app/repositories/sqlite_habit_repository.dart';
import 'package:habit_forge_app/services/database_service.dart';
import 'package:habit_forge_app/services/virtual_date_service.dart';

import 'phase1_optimization_tests.mocks.dart';

@GenerateMocks([SqliteHabitRepository, DatabaseService, VirtualDateService])
void main() {
  group('Phase 1 Optimization Tests', () {
    late MockSqliteHabitRepository mockRepository;
    late MockDatabaseService mockDatabaseService;
    late MockVirtualDateService mockDateService;
    late HabitProvider habitProvider;

    setUp(() {
      mockRepository = MockSqliteHabitRepository();
      mockDatabaseService = MockDatabaseService();
      mockDateService = MockVirtualDateService();
      habitProvider = HabitProvider(mockRepository);
    });

    group('Phase 1.1: Optimistic UI Updates', () {
      test('should update UI immediately before database sync', () async {
        // Arrange
        final habitId = 'test-habit-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository to simulate database delay
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 100)); // Simulate DB delay
        });

        // Act
        final startTime = DateTime.now();
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);
        final endTime = DateTime.now();

        // Assert
        // UI should be updated immediately (within 10ms)
        expect(endTime.difference(startTime).inMilliseconds, lessThan(10));
        
        // Verify habit was updated optimistically
        final updatedHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(updatedHabit.getCompletionCount(testDate), equals(2));
        
        // Verify database sync was called
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 2)).called(1);
      });

      test('should rollback UI changes when database sync fails', () async {
        // Arrange
        final habitId = 'test-habit-2';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
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
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);

        // Assert
        // Habit should be rolled back to original state
        final rolledBackHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(rolledBackHabit.getCompletionCount(testDate), equals(0));
        
        // Error should be set
        expect(habitProvider.error, contains('Failed to sync completion to database'));
      });

      test('should handle rapid consecutive updates correctly', () async {
        // Arrange
        final habitId = 'test-habit-3';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 5,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository with delay
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 50));
        });

        // Act - Rapid consecutive updates
        await habitProvider.updateHabitCompletion(habitId, testDate, 1);
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);
        await habitProvider.updateHabitCompletion(habitId, testDate, 3);

        // Assert
        final finalHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(finalHabit.getCompletionCount(testDate), equals(3));
      });
    });

    group('Phase 1.2: Eliminate Redundant Habit Reloading', () {
      test('should not call getHabitById during completion updates', () async {
        // Arrange
        final habitId = 'test-habit-4';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository methods
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});
        when(mockRepository.getHabitById(any)).thenAnswer((_) async => testHabit);

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);

        // Assert
        // getHabitById should NOT be called during completion update
        verifyNever(mockRepository.getHabitById(habitId));
        
        // Only addMultipleCompletions should be called
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 2)).called(1);
      });

      test('should use cached habit data for completion calculations', () async {
        // Arrange
        final habitId = 'test-habit-5';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {testDate: 1}, // Already has 1 completion
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 3);

        // Assert
        // Should only add 2 more completions (3 - 1 = 2)
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 2)).called(1);
      });
    });

    group('Phase 1.3: Batch Database Operations', () {
      test('should add multiple completions in single database operation', () async {
        // Arrange
        final habitId = 'test-habit-6';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
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
        await habitProvider.updateHabitCompletion(habitId, testDate, 3);

        // Assert
        // Should call addMultipleCompletions with count=3, not 3 separate calls
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 3)).called(1);
        
        // Should NOT call addHabitCompletion multiple times
        verifyNever(mockRepository.addHabitCompletion(any, any));
      });

      test('should handle batch operations for large completion counts', () async {
        // Arrange
        final habitId = 'test-habit-7';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
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

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 8);

        // Assert
        // Should call addMultipleCompletions with count=8 in single operation
        verify(mockRepository.addMultipleCompletions(habitId, testDate, 8)).called(1);
      });

      test('should handle mixed add/remove operations efficiently', () async {
        // Arrange
        final habitId = 'test-habit-8';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 5,
          completions: {testDate: 3}, // Start with 3 completions
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});
        when(mockRepository.removeHabitCompletion(any, any))
            .thenAnswer((_) async {});

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 1); // Remove 2 completions

        // Assert
        // Should call removeHabitCompletion 2 times (not addMultipleCompletions)
        verify(mockRepository.removeHabitCompletion(habitId, testDate)).called(2);
        verifyNever(mockRepository.addMultipleCompletions(any, any, any));
      });
    });

    group('Performance Tests', () {
      test('should complete single completion update in under 10ms', () async {
        // Arrange
        final habitId = 'perf-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Performance Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository with minimal delay
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenAnswer((_) async {});

        // Act
        final stopwatch = Stopwatch()..start();
        await habitProvider.updateHabitCompletion(habitId, testDate, 1);
        stopwatch.stop();

        // Assert
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('should handle 10 rapid updates efficiently', () async {
        // Arrange
        final habitId = 'perf-test-2';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Performance Test Habit',
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

        // Act
        final stopwatch = Stopwatch()..start();
        for (int i = 1; i <= 10; i++) {
          await habitProvider.updateHabitCompletion(habitId, testDate, i);
        }
        stopwatch.stop();

        // Assert
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // All 10 updates in under 100ms
      });
    });

    group('Error Handling Tests', () {
      test('should handle database connection errors gracefully', () async {
        // Arrange
        final habitId = 'error-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Error Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository to throw connection error
        when(mockRepository.addMultipleCompletions(any, any, any))
            .thenThrow(Exception('Database connection lost'));

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 2);

        // Assert
        // Should rollback to original state
        final rolledBackHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(rolledBackHabit.getCompletionCount(testDate), equals(0));
        
        // Should set error message
        expect(habitProvider.error, contains('Failed to sync completion to database'));
      });

      test('should handle invalid habit ID gracefully', () async {
        // Arrange
        final invalidHabitId = 'non-existent-habit';
        final testDate = DateTime(2024, 1, 15);

        // Act
        await habitProvider.updateHabitCompletion(invalidHabitId, testDate, 2);

        // Assert
        // Should not throw exception
        expect(habitProvider.error, isNull);
      });

      test('should handle null/empty completion count gracefully', () async {
        // Arrange
        final habitId = 'error-test-3';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Error Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {},
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Act
        await habitProvider.updateHabitCompletion(habitId, testDate, 0); // No change

        // Assert
        // Should not call repository methods
        verifyNever(mockRepository.addMultipleCompletions(any, any, any));
        verifyNever(mockRepository.removeHabitCompletion(any, any));
      });
    });

    group('Reset Operations Tests', () {
      test('should reset completions with optimistic updates', () async {
        // Arrange
        final habitId = 'reset-test-1';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Reset Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {testDate: 3}, // Start with 3 completions
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository
        when(mockRepository.removeAllCompletionsForDate(any, any))
            .thenAnswer((_) async {});

        // Act
        await habitProvider.resetAllCompletionsForDate(habitId, testDate);

        // Assert
        // Should reset to 0 immediately
        final resetHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(resetHabit.getCompletionCount(testDate), equals(0));
        
        // Should call repository method
        verify(mockRepository.removeAllCompletionsForDate(habitId, testDate)).called(1);
      });

      test('should rollback reset operation on database failure', () async {
        // Arrange
        final habitId = 'reset-test-2';
        final testDate = DateTime(2024, 1, 15);
        final testHabit = Habit(
          id: habitId,
          name: 'Reset Test Habit',
          description: 'Test Description',
          color: 'blue',
          targetGoal: 3,
          completions: {testDate: 2}, // Start with 2 completions
        );

        habitProvider.addHabit(testHabit);
        await habitProvider.loadHabits();

        // Mock repository to throw error
        when(mockRepository.removeAllCompletionsForDate(any, any))
            .thenThrow(Exception('Database error'));

        // Act
        await habitProvider.resetAllCompletionsForDate(habitId, testDate);

        // Assert
        // Should rollback to original state
        final rolledBackHabit = habitProvider.habits.firstWhere((h) => h.id == habitId);
        expect(rolledBackHabit.getCompletionCount(testDate), equals(2));
        
        // Should set error message
        expect(habitProvider.error, contains('Failed to sync completion to database'));
      });
    });
  });
}
