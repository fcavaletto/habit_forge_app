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

  // ============================================================================
  // DATE STRING UTILITIES (for completion_date TEXT storage)
  // ============================================================================

  /// Convert DateTime to 'YYYY-MM-DD' string format
  ///
  /// @param date The DateTime to convert
  /// @return Date string in 'YYYY-MM-DD' format
  static String toDateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Convert 'YYYY-MM-DD' string to DateTime (start of day)
  ///
  /// @param dateString Date string in 'YYYY-MM-DD' format
  /// @return DateTime representing the start of the day
  static DateTime fromDateString(String dateString) {
    final parts = dateString.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date string format: $dateString. Expected YYYY-MM-DD');
    }
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Get date string for today in 'YYYY-MM-DD' format
  ///
  /// @return Today's date as 'YYYY-MM-DD' string
  static String getTodayDateString() {
    return toDateString(DateTime.now());
  }

  /// Get date string for a specific date in 'YYYY-MM-DD' format
  ///
  /// @param date The DateTime to convert
  /// @return Date string in 'YYYY-MM-DD' format
  static String getDateString(DateTime date) {
    return toDateString(date);
  }

  /// Validate that a string is in 'YYYY-MM-DD' format
  ///
  /// @param dateString The string to validate
  /// @return true if the string is in valid 'YYYY-MM-DD' format
  static bool isValidDateString(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length != 3) return false;
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      
      // Basic validation
      if (year < 1900 || year > 2100) return false;
      if (month < 1 || month > 12) return false;
      if (day < 1 || day > 31) return false;
      
      // Try to create a DateTime to validate the date
      DateTime(year, month, day);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // NEW TEXT TIMESTAMP METHODS (Phase 2 Migration)
  // ============================================================================

  /// Convert DateTime to TEXT timestamp string for database storage
  ///
  /// @param dateTime The DateTime to convert
  /// @return Timestamp string in 'YYYY-MM-DD HH:MM' format
  static String toTimestampString(DateTime dateTime) {
    final timestampString = '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    debugPrint('🕒 [TEXT-STORAGE] Converting ${dateTime.toIso8601String()} to timestamp string: $timestampString');
    return timestampString;
  }

  /// Extract hour (0-23) from DateTime for database storage
  ///
  /// @param dateTime The DateTime to extract hour from
  /// @return Hour as integer (0-23)
  static int extractHour(DateTime dateTime) {
    return dateTime.hour;
  }

  /// Convert DateTime to all three formats for database storage
  ///
  /// @param dateTime The DateTime to convert
  /// @return Map with 'text', 'int', and 'hour' keys
  static Map<String, dynamic> toTripleFormat(DateTime dateTime) {
    return {
      'text': toTimestampString(dateTime),
      'int': dateTime.millisecondsSinceEpoch,
      'hour': dateTime.hour,
    };
  }

  /// Convert TEXT timestamp string to DateTime
  ///
  /// @param timestampString Timestamp string in 'YYYY-MM-DD HH:MM' format
  /// @param context Optional context for debugging
  /// @param caller Optional caller information for debugging
  /// @return DateTime object
  static DateTime fromTimestampString(String timestampString, {String? context, String? caller}) {
    try {
      // Parse 'YYYY-MM-DD HH:MM' format
      final parts = timestampString.split(' ');
      if (parts.length != 2) {
        throw FormatException('Invalid timestamp format: $timestampString');
      }

      final datePart = parts[0];
      final timePart = parts[1];

      final dateParts = datePart.split('-');
      final timeParts = timePart.split(':');

      if (dateParts.length != 3 || timeParts.length != 2) {
        throw FormatException('Invalid timestamp format: $timestampString');
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final dateTime = DateTime(year, month, day, hour, minute);

      // Build detailed log message with context
      String logMessage = '🕒 [TEXT-DISPLAY] Converting timestamp string $timestampString to ${dateTime.toIso8601String()}';
      if (context != null) {
        logMessage += ' | Context: $context';
      }
      if (caller != null) {
        logMessage += ' | Called by: $caller';
      }

      debugPrint(logMessage);
      return dateTime;
    } catch (e) {
      debugPrint('❌ Error parsing timestamp string $timestampString: $e');
      rethrow;
    }
  }

  /// Get current timestamp as TEXT string
  ///
  /// @return Current timestamp in 'YYYY-MM-DD HH:MM' format
  static String getCurrentTimestampString() {
    return toTimestampString(DateTime.now());
  }

  /// Validate that a string is in 'YYYY-MM-DD HH:MM' format
  ///
  /// @param timestampString The string to validate
  /// @return true if the string is in valid 'YYYY-MM-DD HH:MM' format
  static bool isValidTimestampString(String timestampString) {
    try {
      final parts = timestampString.split(' ');
      if (parts.length != 2) return false;

      final datePart = parts[0];
      final timePart = parts[1];

      // Validate date part
      if (!isValidDateString(datePart)) return false;

      // Validate time part
      final timeParts = timePart.split(':');
      if (timeParts.length != 2) return false;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (hour < 0 || hour > 23) return false;
      if (minute < 0 || minute > 59) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Batch convert TEXT timestamp strings to DateTimes (reduces logging overhead)
  ///
  /// Use this when converting multiple timestamps at once to avoid excessive logging
  /// @param timestampStrings List of timestamp strings in 'YYYY-MM-DD HH:MM' format
  /// @param context Optional context for debugging (e.g., "completion timestamps", "creation dates")
  /// @return List of DateTime objects
  static List<DateTime> batchFromTimestampStrings(List<String> timestampStrings, {String? context}) {
    final dateTimes = <DateTime>[];
    
    for (int i = 0; i < timestampStrings.length; i++) {
      try {
        final dateTime = fromTimestampString(timestampStrings[i], context: context, caller: 'batch_$i');
        dateTimes.add(dateTime);
      } catch (e) {
        debugPrint('❌ Error in batch conversion at index $i: ${timestampStrings[i]} - $e');
        // Continue with other timestamps
      }
    }
    
    debugPrint('🕒 [BATCH-TEXT] Converted ${dateTimes.length}/${timestampStrings.length} timestamp strings');
    return dateTimes;
  }
}
