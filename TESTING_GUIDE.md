# Testing Guide - New Architecture

This guide explains how to test the new centralized data service architecture that replaces the `_rowToHabit` spaghetti code.

## 🏗️ Architecture Overview

The new architecture consists of:

- **Atomic Operations**: Single-purpose functions for data access
- **Row Processing**: Modular processing of database rows
- **Caching**: Multi-level caching for performance
- **Error Handling**: Circuit breakers and retry logic
- **Monitoring**: Performance tracking and health checks

## 🧪 Testing Strategy

### 1. Unit Tests (`test/services/atomic_data_service_test.dart`)

Test individual atomic operations in isolation.

```bash
# Run all atomic service tests
flutter test test/services/atomic_data_service_test.dart

# Run specific test group
flutter test test/services/atomic_data_service_test.dart --name="getHabitFeatures"
```

**Key Test Areas:**
- ✅ Successful operations return correct data
- ✅ Error handling for invalid inputs
- ✅ Performance monitoring (execution time tracking)
- ✅ Context preservation in results

### 2. Row Processor Tests (`test/services/row_processor_test.dart`)

Test the modular row processing components.

```bash
# Run row processor tests
flutter test test/services/row_processor_test.dart
```

**Test Coverage:**
- **MetadataProcessor**: Database row → ProcessedHabitMetadata
- **CompletionProcessor**: Habit ID + date range → completion data
- **ReminderProcessor**: Habit ID → reminder settings
- **FrequencyProcessor**: JSON frequency data → parsed structure
- **HabitAssembler**: Components → complete Habit object

### 3. Performance Tests (`test/services/performance_tests.dart`)

Test caching and performance optimizations.

```bash
# Run performance tests
flutter test test/services/performance_tests.dart
```

**Performance Metrics:**
- Cache hit/miss ratios
- Parallel processing efficiency
- Circuit breaker effectiveness
- Memory usage under load

### 4. End-to-End Tests (`test/services/e2e_tests.dart`)

Test complete workflows from UI to database.

```bash
# Run end-to-end tests
flutter test test/services/e2e_tests.dart
```

**E2E Scenarios:**
- Dashboard data loading with completions
- Habit creation and immediate retrieval
- Error recovery and data consistency
- Large dataset performance

## 🛠️ Running Tests

### Basic Commands

```bash
# Run all tests
flutter test test/

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/atomic_data_service_test.dart

# Run tests matching pattern
flutter test test/ --name="getHabitFeatures"

# Run tests with verbose output
flutter test test/ -v

# Run tests in specific group
flutter test test/services/row_processor_test.dart --name="MetadataProcessor"
```

### Test Configuration

Add to `pubspec.yaml` for testing dependencies:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

Generate mocks:

```bash
# Generate mocks for all test files
flutter pub run build_runner build
```

## 📊 Test Categories

### Unit Tests (Fast, Isolated)
- **Purpose**: Test individual components in isolation
- **Speed**: Very fast (< 1 second)
- **Coverage**: Individual functions and classes
- **Mocking**: Heavy use of mocks and stubs

### Integration Tests (Medium Speed)
- **Purpose**: Test component interactions
- **Speed**: Medium (1-5 seconds)
- **Coverage**: Service boundaries and data flow
- **Mocking**: Some mocks, real database connections

### Performance Tests (Variable Speed)
- **Purpose**: Test performance characteristics
- **Speed**: Variable (depends on test complexity)
- **Coverage**: Caching, parallel processing, memory usage
- **Mocking**: Minimal, focuses on real performance

### End-to-End Tests (Slowest)
- **Purpose**: Test complete user workflows
- **Speed**: Slow (5-30 seconds)
- **Coverage**: Full application stack
- **Mocking**: Minimal, real database and UI interactions

## 🔧 Writing New Tests

### Test Structure

```dart
void main() {
  group('Component Name', () {
    late MockDependency mockDependency;
    late SystemUnderTest system;

    setUp(() {
      mockDependency = MockDependency();
      system = SystemUnderTest(mockDependency);
    });

    group('Feature Name', () {
      test('should handle successful case', () async {
        // Arrange
        when(mockDependency.method()).thenAnswer((_) async => expectedData);

        // Act
        final result = await system.method(context);

        // Assert
        expect(result.success, true);
        expect(result.data, expectedData);
        verify(mockDependency.method()).called(1);
      });

      test('should handle error case', () async {
        // Arrange
        when(mockDependency.method()).thenThrow(Exception('Error'));

        // Act
        final result = await system.method(context);

        // Assert
        expect(result.success, false);
        expect(result.errorMessage, contains('Error'));
      });
    });
  });
}
```

### Testing Best Practices

1. **Arrange-Act-Assert**: Clear test structure
2. **Descriptive Names**: Tests should read like documentation
3. **Single Responsibility**: One test per behavior
4. **Mock Dependencies**: Use interfaces for easy mocking
5. **Error Testing**: Always test error conditions
6. **Performance Awareness**: Test execution time where relevant

### Common Testing Patterns

**Atomic Operation Testing:**
```dart
test('should validate input parameters', () async {
  expect(
    () async => await service.invalidOperation(),
    throwsA(isA<DataValidationException>()),
  );
});
```

**Caching Testing:**
```dart
test('should cache results and return faster on second call', () async {
  // First call
  final result1 = await service.getData(context);
  expect(result1.executionTime, greaterThan(Duration.zero));

  // Second call (should be cached)
  final result2 = await service.getData(context);
  expect(result2.executionTime, Duration.zero);
});
```

**Error Recovery Testing:**
```dart
test('should retry on transient failures', () async {
  var callCount = 0;
  when(mockDatabase.query(any)).thenAnswer((_) async {
    callCount++;
    if (callCount < 3) throw Exception('Temporary failure');
    return mockData;
  });

  final result = await service.getData(context);
  expect(result.success, true);
  expect(callCount, 3); // Should have retried
});
```

## 📈 Performance Testing

### Cache Performance Testing

```dart
test('should improve performance with caching', () async {
  // Measure first call (cache miss)
  final stopwatch1 = Stopwatch()..start();
  await service.getExpensiveData(context);
  stopwatch1.stop();

  // Measure second call (cache hit)
  final stopwatch2 = Stopwatch()..start();
  await service.getExpensiveData(context);
  stopwatch2.stop();

  expect(stopwatch2.elapsedMilliseconds, lessThan(stopwatch1.elapsedMilliseconds ~/ 2));
});
```

### Memory Usage Testing

```dart
test('should not leak memory with large datasets', () async {
  final largeDataset = List.generate(10000, (i) => createTestData(i));

  // Measure memory before
  final memoryBefore = await getMemoryUsage();

  // Process large dataset
  await service.processLargeDataset(largeDataset, context);

  // Measure memory after
  final memoryAfter = await getMemoryUsage();

  // Should not have significant memory increase
  expect(memoryAfter - memoryBefore, lessThan(50 * 1024 * 1024)); // 50MB limit
});
```

## 🚨 Error Handling Testing

### Exception Testing

```dart
test('should throw DataValidationException for invalid input', () async {
  expect(
    () async => await service.processData(invalidInput, context),
    throwsA(isA<DataValidationException>()),
  );
});

test('should throw DatabaseConnectionException on connection failure', () async {
  when(mockDatabase.connect()).thenThrow(DatabaseConnectionException('Connection failed', context));

  expect(
    () async => await service.getData(context),
    throwsA(isA<DatabaseConnectionException>()),
  );
});
```

### Circuit Breaker Testing

```dart
test('should open circuit breaker after repeated failures', () async {
  // Cause multiple failures
  for (int i = 0; i < 5; i++) {
    try {
      await service.getData(context);
    } catch (e) {
      // Expected failures
    }
  }

  // Circuit should be open now
  expect(circuitBreaker.state, CircuitBreakerState.open);

  // Next call should fail immediately without retry
  expect(
    () async => await service.getData(context),
    throwsA(isA<CircuitBreakerException>()),
  );
});
```

## 🔍 Debugging Tests

### Detailed Logging

All operations include detailed logging:

```
🔍 [ATOMIC] getHabitFeatures called: DashboardScreen.loadHabits
✅ [ATOMIC] getHabitFeatures completed: 5 habits in 15ms
📅 [COMPLETION_PROCESSOR] Found 12 completion records for habit abc123
💾 CACHE HIT - metadata:abc123 | Operation: processHabitMetadata
```

### Performance Monitoring

```dart
test('should track performance metrics', () async {
  final statsBefore = await service.getPerformanceStats();

  await service.getData(context);

  final statsAfter = await service.getPerformanceStats();

  expect(statsAfter['total_calls'], statsBefore['total_calls'] + 1);
  expect(statsAfter['total_time_ms'], greaterThan(statsBefore['total_time_ms']));
});
```

## 🎯 Testing Goals

1. **95%+ Code Coverage**: All critical paths tested
2. **Performance Validation**: Caching and optimization verified
3. **Error Handling**: All error conditions properly handled
4. **Integration**: Components work together correctly
5. **Regression Prevention**: Changes don't break existing functionality

## 📋 Test Maintenance

### Adding New Tests

1. **Identify the component** to test (AtomicDataService, RowProcessor, etc.)
2. **Determine test type** (unit, integration, performance, e2e)
3. **Set up mocks** using the appropriate interfaces
4. **Write Arrange-Act-Assert** structure
5. **Add performance assertions** where relevant
6. **Include error case testing**

### Test Organization

```
test/
├── services/
│   ├── atomic_data_service_test.dart    # Unit tests for atomic operations
│   ├── row_processor_test.dart          # Unit tests for row processing
│   ├── performance_tests.dart          # Performance and caching tests
│   └── e2e_tests.dart                  # End-to-end workflow tests
└── run_tests.dart                      # Test runner and utilities
```

This testing framework ensures the new architecture is robust, performant, and maintainable while providing comprehensive coverage of all functionality.
