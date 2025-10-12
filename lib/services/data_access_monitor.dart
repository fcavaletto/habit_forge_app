import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

/// Log levels for controlling logging verbosity
enum LogLevel {
  debug(0),    // Detailed diagnostic information for development
  info(1),     // General informational messages (cache hits, successful operations)
  warning(2),  // Warnings that don't prevent operation (cache misses, retries)
  error(3);    // Errors that require attention (failures, exceptions)

  final int severity;
  const LogLevel(this.severity);

  bool shouldLog(LogLevel configuredLevel) {
    return severity >= configuredLevel.severity;
  }
}

/// Structured logging for data access operations
///
/// Provides context-aware logging with performance metrics and error tracking.
/// Log levels can be configured to control verbosity in different environments:
/// - Development: LogLevel.debug (all logs)
/// - Production: LogLevel.warning or LogLevel.error (reduce noise)
class DataAccessLogger {
  static const String _logPrefix = '[DATA_ACCESS]';
  
  /// Current log level - controls which logs are emitted
  /// Set to LogLevel.warning or LogLevel.error in production for better performance
  static LogLevel _logLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  /// Configure the logging level
  ///
  /// Example:
  /// ```dart
  /// // Production: Only warnings and errors
  /// DataAccessLogger.setLogLevel(LogLevel.warning);
  ///
  /// // Development: All logs including debug
  /// DataAccessLogger.setLogLevel(LogLevel.debug);
  /// ```
  static void setLogLevel(LogLevel level) {
    _logLevel = level;
    debugPrint('📊 $_logPrefix Log level set to: ${level.name}');
  }

  /// Get current log level
  static LogLevel get logLevel => _logLevel;

  /// Log successful operation
  static void logSuccess({
    required String operation,
    required String component,
    required Duration executionTime,
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? metadata,
  }) {
    if (!LogLevel.info.shouldLog(_logLevel)) return;

    final context = _buildContext(operation, component, parameters);
    final message = '✅ $_logPrefix $context - Completed in ${executionTime.inMilliseconds}ms';

    if (metadata != null && metadata.isNotEmpty) {
      debugPrint('$message | Metadata: $metadata');
    } else {
      debugPrint(message);
    }
  }

  /// Log operation start
  static void logStart({
    required String operation,
    required String component,
    Map<String, dynamic>? parameters,
  }) {
    if (!LogLevel.debug.shouldLog(_logLevel)) return;

    final context = _buildContext(operation, component, parameters);
    debugPrint('🔍 $_logPrefix $context - Started');
  }

  /// Log operation failure
  static void logFailure({
    required String operation,
    required String component,
    required Duration executionTime,
    required Object error,
    Map<String, dynamic>? parameters,
    StackTrace? stackTrace,
  }) {
    if (!LogLevel.error.shouldLog(_logLevel)) return;

    final context = _buildContext(operation, component, parameters);
    final message = '❌ $_logPrefix $context - Failed after ${executionTime.inMilliseconds}ms: $error';

    debugPrint(message);

    if (stackTrace != null && kDebugMode) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Log warning
  static void logWarning({
    required String operation,
    required String component,
    required String message,
    Map<String, dynamic>? parameters,
  }) {
    if (!LogLevel.warning.shouldLog(_logLevel)) return;

    final context = _buildContext(operation, component, parameters);
    debugPrint('⚠️ $_logPrefix $context - Warning: $message');
  }

  /// Log performance metrics
  static void logPerformance({
    required String operation,
    required String component,
    required Duration executionTime,
    int? recordCount,
    Map<String, dynamic>? parameters,
  }) {
    if (!LogLevel.debug.shouldLog(_logLevel)) return;

    final context = _buildContext(operation, component, parameters);
    final countInfo = recordCount != null ? ' | Records: $recordCount' : '';
    debugPrint('⏱️ $_logPrefix $context - Performance: ${executionTime.inMilliseconds}ms$countInfo');
  }

  /// Log cache operations
  static void logCache({
    required String operation,
    required String cacheType,
    String? key,
    bool hit = false,
  }) {
    // Cache hits are info level (useful but not critical)
    // Cache misses are debug level (noise in production)
    final level = hit ? LogLevel.info : LogLevel.debug;
    if (!level.shouldLog(_logLevel)) return;

    final status = hit ? 'HIT' : 'MISS';
    final keyInfo = key != null ? ' | Key: $key' : '';
    debugPrint('💾 $_logPrefix CACHE $status - $cacheType$keyInfo | Operation: $operation');
  }

  static String _buildContext(String operation, String component, Map<String, dynamic>? parameters) {
    final paramStr = parameters != null && parameters.isNotEmpty
        ? ' | Params: ${jsonEncode(parameters)}'
        : '';
    return '$component.$operation$paramStr';
  }
}

/// Performance monitoring for data access operations
class PerformanceMonitor {
  static final Map<String, _PerformanceMetrics> _metrics = {};

  /// Monitor an async operation and return its result
  static Future<T> monitorOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    Map<String, dynamic>? parameters,
  }) async {
    final stopwatch = Stopwatch()..start();
    final startTime = DateTime.now();

    try {
      DataAccessLogger.logStart(
        operation: operationName,
        component: 'PerformanceMonitor',
        parameters: parameters,
      );

      final result = await operation();

      stopwatch.stop();
      _recordSuccess(operationName, stopwatch.elapsed, startTime);

      DataAccessLogger.logSuccess(
        operation: operationName,
        component: 'PerformanceMonitor',
        executionTime: stopwatch.elapsed,
        parameters: parameters,
      );

      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      _recordFailure(operationName, stopwatch.elapsed, startTime);

      DataAccessLogger.logFailure(
        operation: operationName,
        component: 'PerformanceMonitor',
        executionTime: stopwatch.elapsed,
        error: error,
        parameters: parameters,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  /// Get performance statistics
  static Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};

    for (final entry in _metrics.entries) {
      final metrics = entry.value;
      stats[entry.key] = {
        'total_calls': metrics.totalCalls,
        'total_time_ms': metrics.totalTime.inMilliseconds,
        'avg_time_ms': metrics.averageTime.inMilliseconds,
        'min_time_ms': metrics.minTime.inMilliseconds,
        'max_time_ms': metrics.maxTime.inMilliseconds,
        'success_rate': metrics.successRate,
        'last_called': metrics.lastCalled?.toIso8601String(),
      };
    }

    return stats;
  }

  /// Reset performance metrics
  static void resetMetrics() {
    _metrics.clear();
    debugPrint('📊 Performance metrics reset');
  }

  static void _recordSuccess(String operation, Duration duration, DateTime timestamp) {
    _metrics[operation] ??= _PerformanceMetrics();
    _metrics[operation]!.recordSuccess(duration, timestamp);
  }

  static void _recordFailure(String operation, Duration duration, DateTime timestamp) {
    _metrics[operation] ??= _PerformanceMetrics();
    _metrics[operation]!.recordFailure(duration, timestamp);
  }
}

/// Performance metrics for operations
class _PerformanceMetrics {
  int totalCalls = 0;
  int successCalls = 0;
  Duration totalTime = Duration.zero;
  Duration minTime = Duration.zero;
  Duration maxTime = Duration.zero;
  DateTime? lastCalled;

  Duration get averageTime {
    if (totalCalls == 0) return Duration.zero;
    return Duration(milliseconds: totalTime.inMilliseconds ~/ totalCalls);
  }

  double get successRate {
    if (totalCalls == 0) return 1.0;
    return successCalls / totalCalls;
  }

  void recordSuccess(Duration duration, DateTime timestamp) {
    totalCalls++;
    successCalls++;
    totalTime += duration;
    lastCalled = timestamp;

    if (minTime == Duration.zero || duration < minTime) {
      minTime = duration;
    }

    if (maxTime == Duration.zero || duration > maxTime) {
      maxTime = duration;
    }
  }

  void recordFailure(Duration duration, DateTime timestamp) {
    totalCalls++;
    totalTime += duration;
    lastCalled = timestamp;

    if (minTime == Duration.zero || duration < minTime) {
      minTime = duration;
    }

    if (maxTime == Duration.zero || duration > maxTime) {
      maxTime = duration;
    }
  }
}

/// Circuit breaker for handling repeated failures
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration recoveryTimeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
    this.recoveryTimeout = const Duration(minutes: 1),
  });

  /// Execute operation with circuit breaker protection
  Future<T> execute<T>(Future<T> Function() operation) async {
    switch (_state) {
      case CircuitBreakerState.closed:
        try {
          final result = await operation();
          _resetFailureCount();
          return result;
        } catch (e) {
          _recordFailure();
          rethrow;
        }

      case CircuitBreakerState.open:
        if (_shouldAttemptReset()) {
          _state = CircuitBreakerState.halfOpen;
          try {
            final result = await operation();
            _resetFailureCount();
            _state = CircuitBreakerState.closed;
            return result;
          } catch (e) {
            _recordFailure();
            _state = CircuitBreakerState.open;
            rethrow;
          }
        } else {
          throw CircuitBreakerException(
            'Circuit breaker is OPEN for $name. Next retry at ${_nextRetryTime()}',
          );
        }

      case CircuitBreakerState.halfOpen:
        try {
          final result = await operation();
          _resetFailureCount();
          _state = CircuitBreakerState.closed;
          return result;
        } catch (e) {
          _recordFailure();
          _state = CircuitBreakerState.open;
          rethrow;
        }
    }
  }

  bool _shouldAttemptReset() {
    final now = DateTime.now();
    final timeSinceLastFailure = _lastFailureTime?.difference(now).abs() ?? Duration.zero;
    return timeSinceLastFailure >= recoveryTimeout;
  }

  DateTime _nextRetryTime() {
    return (_lastFailureTime ?? DateTime.now()).add(recoveryTimeout);
  }

  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      debugPrint('🔌 Circuit breaker OPEN for $name after $_failureCount failures');
    }
  }

  void _resetFailureCount() {
    _failureCount = 0;
    _lastFailureTime = null;
  }

  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;
}

enum CircuitBreakerState {
  closed,    // Normal operation
  open,      // Failing, rejecting calls
  halfOpen,  // Testing if service recovered
}

/// Exception thrown by circuit breaker
class CircuitBreakerException implements Exception {
  final String message;

  const CircuitBreakerException(this.message);

  @override
  String toString() => 'CircuitBreakerException: $message';
}

/// Health checker for data access services
class HealthChecker {
  final Map<String, DateTime> _lastHealthChecks = {};
  final Map<String, bool> _serviceHealth = {};

  /// Check health of a service
  Future<bool> checkServiceHealth(String serviceName) async {
    try {
      // Simple health check - can be extended based on service type
      switch (serviceName) {
        case 'database':
          // TODO: Implement actual database health check
          return true;
        case 'cache':
          // TODO: Implement actual cache health check
          return true;
        default:
          return _serviceHealth[serviceName] ?? true;
      }
    } catch (e) {
      debugPrint('❌ Health check failed for $serviceName: $e');
      _serviceHealth[serviceName] = false;
      return false;
    } finally {
      _lastHealthChecks[serviceName] = DateTime.now();
    }
  }

  /// Get overall system health
  Future<Map<String, dynamic>> getSystemHealth() async {
    final health = <String, dynamic>{
      'overall': 'healthy',
      'services': <String, dynamic>{},
      'last_checks': <String, String>{},
    };

    final services = ['database', 'cache', 'atomic_service'];

    for (final service in services) {
      final isHealthy = await checkServiceHealth(service);
      health['services'][service] = isHealthy;

      if (!isHealthy) {
        health['overall'] = 'unhealthy';
      }

      final lastCheck = _lastHealthChecks[service];
      health['last_checks'][service] = lastCheck?.toIso8601String() ?? 'never';
    }

    return health;
  }

  /// Force update service health status
  void updateServiceHealth(String serviceName, bool isHealthy) {
    _serviceHealth[serviceName] = isHealthy;
    _lastHealthChecks[serviceName] = DateTime.now();
  }
}

/// Retry configuration for database operations
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 5),
    this.backoffMultiplier = 2.0,
  });

  /// Calculate delay for attempt number
  Duration getDelayForAttempt(int attempt) {
    final delay = initialDelay * (backoffMultiplier * (attempt - 1));
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Retry utility for database operations
class RetryUtils {
  /// Execute operation with exponential backoff retry
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    RetryConfig config = const RetryConfig(),
    String operationName = 'unknown',
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e as Exception;

        if (attempt == config.maxAttempts) {
          DataAccessLogger.logFailure(
            operation: operationName,
            component: 'RetryUtils',
            executionTime: Duration.zero,
            error: e,
            parameters: {'attempt': attempt, 'maxAttempts': config.maxAttempts},
          );
          rethrow;
        }

        final delay = config.getDelayForAttempt(attempt);
        DataAccessLogger.logWarning(
          operation: operationName,
          component: 'RetryUtils',
          message: 'Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms',
          parameters: {'attempt': attempt, 'maxAttempts': config.maxAttempts},
        );

        await Future.delayed(delay);
      }
    }

    throw lastException!;
  }

  /// Execute operation with circuit breaker protection and retry
  static Future<T> executeWithCircuitBreakerAndRetry<T>({
    required Future<T> Function() operation,
    required CircuitBreaker circuitBreaker,
    RetryConfig retryConfig = const RetryConfig(),
    String operationName = 'unknown',
  }) async {
    return await circuitBreaker.execute(() =>
      executeWithRetry(
        operation: operation,
        config: retryConfig,
        operationName: operationName,
      )
    );
  }
}

/// Global instances for easy access
final dataAccessLogger = DataAccessLogger();
final performanceMonitor = PerformanceMonitor();
final healthChecker = HealthChecker();

/// Circuit breakers for different services
final databaseCircuitBreaker = CircuitBreaker(name: 'database');
final cacheCircuitBreaker = CircuitBreaker(name: 'cache');
final atomicServiceCircuitBreaker = CircuitBreaker(name: 'atomic_service');
final rowProcessorCircuitBreaker = CircuitBreaker(name: 'row_processor');
