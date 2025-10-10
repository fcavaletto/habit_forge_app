import 'package:flutter/foundation.dart';
import '../services/virtual_date_service.dart';

/// Timezone Utility Service
///
/// Provides centralized timezone handling for consistent UTC storage
/// with local timezone display throughout the app.
///
/// Key Features:
/// - Convert local DateTime to UTC for database storage
/// - Convert UTC timestamps back to local DateTime for display
/// - Ensure consistent timezone handling across the app
class TimezoneUtils {
  /// Convert local DateTime to UTC timestamp for database storage
  ///
  /// @param localDateTime The local DateTime to convert
  /// @return UTC timestamp in milliseconds since epoch
  static int toUtcTimestamp(DateTime localDateTime) {
    final utcTimestamp = localDateTime.toUtc().millisecondsSinceEpoch;
    debugPrint('🌍 [STORAGE] Converting local ${localDateTime.toIso8601String()} to UTC timestamp: $utcTimestamp');
    return utcTimestamp;
  }
  
  /// Convert UTC timestamp to local DateTime for display
  ///
  /// @param utcTimestamp UTC timestamp in milliseconds since epoch
  /// @param context Optional context for debugging (habit ID, field name, etc.)
  /// @param caller Optional caller information for debugging
  /// @return Local DateTime for display
  static DateTime fromUtcTimestamp(int utcTimestamp, {String? context, String? caller}) {
    final localDateTime = DateTime.fromMillisecondsSinceEpoch(utcTimestamp).toLocal();
    
    // Build detailed log message with context
    String logMessage = '🌍 [DISPLAY] Converting UTC timestamp $utcTimestamp to local ${localDateTime.toIso8601String()}';
    if (context != null) {
      logMessage += ' | Context: $context';
    }
    if (caller != null) {
      logMessage += ' | Called by: $caller';
    }
    
    debugPrint(logMessage);
    return localDateTime;
  }
  
  /// Get current UTC timestamp for database storage
  ///
  /// @return Current UTC timestamp in milliseconds since epoch
  static int getCurrentUtcTimestamp() {
    final utcTimestamp = VirtualDateService().currentDate.toUtc().millisecondsSinceEpoch;
    debugPrint('🌍 [CURRENT] Current UTC timestamp: $utcTimestamp');
    return utcTimestamp;
  }
  
  /// Convert local DateTime to UTC timestamp in seconds (for SQLite unixepoch)
  ///
  /// @param localDateTime The local DateTime to convert
  /// @return UTC timestamp in seconds since epoch
  static int toUtcTimestampSeconds(DateTime localDateTime) {
    final utcTimestampSeconds = localDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    debugPrint('🌍 [STORAGE-SECONDS] Converting local ${localDateTime.toIso8601String()} to UTC seconds: $utcTimestampSeconds');
    return utcTimestampSeconds;
  }
  
  /// Convert UTC timestamp in seconds to local DateTime
  ///
  /// @param utcTimestampSeconds UTC timestamp in seconds since epoch
  /// @return Local DateTime for display
  static DateTime fromUtcTimestampSeconds(int utcTimestampSeconds) {
    final localDateTime = DateTime.fromMillisecondsSinceEpoch(utcTimestampSeconds * 1000).toLocal();
    debugPrint('🌍 [DISPLAY-SECONDS] Converting UTC seconds $utcTimestampSeconds to local ${localDateTime.toIso8601String()}');
    return localDateTime;
  }
  
  /// Format DateTime for display in local timezone
  ///
  /// @param dateTime DateTime to format
  /// @return Formatted string in local timezone
  static String formatForDisplay(DateTime dateTime) {
    return dateTime.toLocal().toIso8601String();
  }
  
  /// Format DateTime for storage in UTC
  ///
  /// @param dateTime DateTime to format
  /// @return Formatted string in UTC
  static String formatForStorage(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }
  
  /// Batch convert UTC timestamps to local DateTimes (reduces logging overhead)
  ///
  /// Use this when converting multiple timestamps at once to avoid excessive logging
  /// @param utcTimestamps List of UTC timestamps in milliseconds since epoch
  /// @param context Optional context for debugging (e.g., "habit completions", "creation dates")
  /// @return List of local DateTimes for display
  static List<DateTime> batchFromUtcTimestamp(
    List<int> utcTimestamps, {
    String? context,
  }) {
    if (utcTimestamps.isEmpty) {
      return [];
    }
    
    final localDateTimes = utcTimestamps
        .map((timestamp) => DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal())
        .toList();
    
    // Single log message for the entire batch
    debugPrint(
      '🌍 [BATCH-DISPLAY] Converted ${utcTimestamps.length} UTC timestamps to local'
      '${context != null ? ' | Context: $context' : ''}',
    );
    
    return localDateTimes;
  }
  
  /// Batch convert local DateTimes to UTC timestamps (reduces logging overhead)
  ///
  /// Use this when converting multiple DateTimes at once to avoid excessive logging
  /// @param localDateTimes List of local DateTimes to convert
  /// @param context Optional context for debugging
  /// @return List of UTC timestamps in milliseconds since epoch
  static List<int> batchToUtcTimestamp(
    List<DateTime> localDateTimes, {
    String? context,
  }) {
    if (localDateTimes.isEmpty) {
      return [];
    }
    
    final utcTimestamps = localDateTimes
        .map((dateTime) => dateTime.toUtc().millisecondsSinceEpoch)
        .toList();
    
    // Single log message for the entire batch
    debugPrint(
      '🌍 [BATCH-STORAGE] Converted ${localDateTimes.length} local DateTimes to UTC'
      '${context != null ? ' | Context: $context' : ''}',
    );
    
    return utcTimestamps;
  }
  
  /// Batch convert map of date keys with UTC timestamp values to local dates
  ///
  /// Specifically optimized for completion data: Map<DateTime, int>
  /// @param utcCompletionMap Map with UTC timestamps as keys
  /// @param context Optional context for debugging
  /// @return Map with local DateTimes as keys
  static Map<DateTime, int> batchConvertCompletionMap(
    Map<int, int> utcCompletionMap, {
    String? context,
  }) {
    if (utcCompletionMap.isEmpty) {
      return {};
    }
    
    final localCompletionMap = <DateTime, int>{};
    
    for (final entry in utcCompletionMap.entries) {
      final localDate = DateTime.fromMillisecondsSinceEpoch(entry.key).toLocal();
      localCompletionMap[localDate] = entry.value;
    }
    
    // Single log message for the entire batch
    debugPrint(
      '🌍 [BATCH-COMPLETIONS] Converted ${utcCompletionMap.length} completion timestamps to local'
      '${context != null ? ' | Context: $context' : ''}',
    );
    
    return localCompletionMap;
  }
}
