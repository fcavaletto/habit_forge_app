import 'package:flutter/foundation.dart';

/// Timezone Utility Service
///
/// Provides centralized timezone handling for consistent UTC storage
/// with local timezone display throughout the app.
///
/// Key Features:
/// - Convert local DateTime to UTC for database storage
/// - Convert UTC timestamps back to local DateTime for display
/// - Handle legacy data compatibility
/// - Ensure consistent timezone handling across the app
class TimezoneUtils {
  static bool _isLegacyData = false;
  
  /// Set whether the app is using legacy data (stored in local timezone)
  /// or new data (stored in UTC)
  static void setLegacyDataMode(bool isLegacy) {
    _isLegacyData = isLegacy;
    debugPrint('🌍 TimezoneUtils: Legacy data mode = $isLegacy');
  }
  
  /// Check if app is currently using legacy data format
  static bool get isLegacyData => _isLegacyData;
  
  /// Convert local DateTime to UTC timestamp for database storage
  ///
  /// @param localDateTime The local DateTime to convert
  /// @return UTC timestamp in milliseconds since epoch
  static int toUtcTimestamp(DateTime localDateTime) {
    final utcTimestamp = localDateTime.toUtc().millisecondsSinceEpoch;
    debugPrint('🌍 Converting local ${localDateTime.toIso8601String()} to UTC timestamp: $utcTimestamp');
    return utcTimestamp;
  }
  
  /// Convert UTC timestamp to local DateTime for display
  ///
  /// @param utcTimestamp UTC timestamp in milliseconds since epoch
  /// @return Local DateTime for display
  static DateTime fromUtcTimestamp(int utcTimestamp) {
    final localDateTime = DateTime.fromMillisecondsSinceEpoch(utcTimestamp).toLocal();
    debugPrint('🌍 Converting UTC timestamp $utcTimestamp to local ${localDateTime.toIso8601String()}');
    return localDateTime;
  }
  
  /// Convert timestamp to local DateTime, handling both legacy and new formats
  ///
  /// @param timestamp Timestamp in milliseconds since epoch
  /// @return Local DateTime for display
  static DateTime fromTimestamp(int timestamp) {
    if (_isLegacyData) {
      // Legacy data was stored in local timezone
      final localDateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      debugPrint('🌍 Legacy: Converting timestamp $timestamp to local ${localDateTime.toIso8601String()}');
      return localDateTime;
    } else {
      // New data is stored in UTC
      final localDateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
      debugPrint('🌍 New: Converting UTC timestamp $timestamp to local ${localDateTime.toIso8601String()}');
      return localDateTime;
    }
  }
  
  /// Get current UTC timestamp for database storage
  ///
  /// @return Current UTC timestamp in milliseconds since epoch
  static int getCurrentUtcTimestamp() {
    final utcTimestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    debugPrint('🌍 Current UTC timestamp: $utcTimestamp');
    return utcTimestamp;
  }
  
  /// Convert local DateTime to UTC timestamp in seconds (for SQLite unixepoch)
  ///
  /// @param localDateTime The local DateTime to convert
  /// @return UTC timestamp in seconds since epoch
  static int toUtcTimestampSeconds(DateTime localDateTime) {
    final utcTimestampSeconds = localDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    debugPrint('🌍 Converting local ${localDateTime.toIso8601String()} to UTC seconds: $utcTimestampSeconds');
    return utcTimestampSeconds;
  }
  
  /// Convert UTC timestamp in seconds to local DateTime
  ///
  /// @param utcTimestampSeconds UTC timestamp in seconds since epoch
  /// @return Local DateTime for display
  static DateTime fromUtcTimestampSeconds(int utcTimestampSeconds) {
    final localDateTime = DateTime.fromMillisecondsSinceEpoch(utcTimestampSeconds * 1000).toLocal();
    debugPrint('🌍 Converting UTC seconds $utcTimestampSeconds to local ${localDateTime.toIso8601String()}');
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
}
