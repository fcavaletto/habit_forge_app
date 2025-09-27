import 'package:flutter/foundation.dart';

/// Performance Monitoring Utility
///
/// Provides performance monitoring for date calculations and other operations
/// to ensure the app remains efficient and responsive.
///
/// Key Features:
/// - Monitor operation duration
/// - Log slow operations
/// - Track performance metrics
class PerformanceMonitor {
  static const int _slowOperationThresholdMs = 100;
  
  /// Monitor the duration of an operation and log if it's slow
  ///
  /// @param operationName The name of the operation being monitored
  /// @param operation The operation to execute and monitor
  /// @return The result of the operation
  static Future<T> monitorOperation<T>(String operationName, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      final duration = stopwatch.elapsedMilliseconds;
      if (duration > _slowOperationThresholdMs) {
        debugPrint('⚠️ [Performance] Slow operation: $operationName took ${duration}ms');
      } else {
        debugPrint('✅ [Performance] Operation: $operationName completed in ${duration}ms');
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [Performance] Operation failed: $operationName took ${stopwatch.elapsedMilliseconds}ms - Error: $e');
      rethrow;
    }
  }
  
  /// Monitor a synchronous operation
  ///
  /// @param operationName The name of the operation being monitored
  /// @param operation The operation to execute and monitor
  /// @return The result of the operation
  static T monitorSyncOperation<T>(String operationName, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = operation();
      stopwatch.stop();
      
      final duration = stopwatch.elapsedMilliseconds;
      if (duration > _slowOperationThresholdMs) {
        debugPrint('⚠️ [Performance] Slow sync operation: $operationName took ${duration}ms');
      } else {
        debugPrint('✅ [Performance] Sync operation: $operationName completed in ${duration}ms');
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ [Performance] Sync operation failed: $operationName took ${stopwatch.elapsedMilliseconds}ms - Error: $e');
      rethrow;
    }
  }
  
  /// Log a performance metric
  ///
  /// @param metricName The name of the metric
  /// @param value The value of the metric
  /// @param unit The unit of measurement (e.g., 'ms', 'bytes', 'count')
  static void logMetric(String metricName, num value, String unit) {
    debugPrint('📊 [Performance] $metricName: $value $unit');
  }
  
  /// Log a performance warning
  ///
  /// @param warning The warning message
  static void logWarning(String warning) {
    debugPrint('⚠️ [Performance] $warning');
  }
  
  /// Log a performance error
  ///
  /// @param error The error message
  static void logError(String error) {
    debugPrint('❌ [Performance] $error');
  }
}
