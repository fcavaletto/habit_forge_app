import 'package:flutter/foundation.dart';
import 'timezone_utils.dart';
import 'date_range_utils.dart';

/// Timezone Consistency Checker
///
/// Provides validation to ensure timezone conversions are working correctly
/// and consistently throughout the app.
///
/// Key Features:
/// - Validate UTC to local conversions
/// - Check for timezone inconsistencies
/// - Detect potential timezone bugs
class TimezoneConsistencyChecker {
  /// Validate that a UTC to local conversion is consistent
  ///
  /// @param localDate The original local date
  /// @param utcTimestamp The UTC timestamp
  /// @throws StateError if conversion is inconsistent
  static void validateUtcToLocalConversion(DateTime localDate, int utcTimestamp) {
    final convertedBack = TimezoneUtils.fromUtcTimestamp(utcTimestamp);
    final difference = convertedBack.difference(localDate).abs();
    
    // Allow up to 1 second difference for rounding
    if (difference.inSeconds > 1) {
      throw StateError('UTC to local conversion inconsistency: '
          'Original: ${localDate.toIso8601String()}, '
          'UTC: $utcTimestamp, '
          'Converted back: ${convertedBack.toIso8601String()}, '
          'Difference: ${difference.inSeconds}s');
    }
    
    debugPrint('✅ [TimezoneCheck] UTC to local conversion validated: ${localDate.toIso8601String()} ↔ $utcTimestamp');
  }
  
  /// Validate that a local to UTC conversion is consistent
  ///
  /// @param localDate The original local date
  /// @param utcTimestamp The UTC timestamp
  /// @throws StateError if conversion is inconsistent
  static void validateLocalToUtcConversion(DateTime localDate, int utcTimestamp) {
    final expectedUtc = TimezoneUtils.toUtcTimestamp(localDate);
    final difference = (expectedUtc - utcTimestamp).abs();
    
    // Allow up to 1 second difference for rounding
    if (difference > 1000) {
      throw StateError('Local to UTC conversion inconsistency: '
          'Original: ${localDate.toIso8601String()}, '
          'Expected UTC: $expectedUtc, '
          'Actual UTC: $utcTimestamp, '
          'Difference: ${difference}ms');
    }
    
    debugPrint('✅ [TimezoneCheck] Local to UTC conversion validated: ${localDate.toIso8601String()} → $utcTimestamp');
  }
  
  /// Validate that a date range maintains timezone consistency
  ///
  /// @param startDate The start date of the range
  /// @param endDate The end date of the range
  /// @param startUtc The UTC timestamp for start date
  /// @param endUtc The UTC timestamp for end date
  /// @throws StateError if timezone consistency is violated
  static void validateDateRangeTimezoneConsistency(
    DateTime startDate, 
    DateTime endDate, 
    int startUtc, 
    int endUtc
  ) {
    // Validate individual conversions
    validateLocalToUtcConversion(startDate, startUtc);
    validateLocalToUtcConversion(endDate, endUtc);
    
    // Validate that the UTC range maintains the same order as local range
    if (startDate.isBefore(endDate) && startUtc >= endUtc) {
      throw StateError('Date range timezone consistency violation: '
          'Local range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}, '
          'UTC range: $startUtc to $endUtc');
    }
    
    debugPrint('✅ [TimezoneCheck] Date range timezone consistency validated');
  }
  
  /// Check if a timestamp is reasonable (not in the far future or past)
  ///
  /// @param timestamp The timestamp to check
  /// @param context Description of what this timestamp represents
  /// @throws StateError if timestamp is unreasonable
  static void validateTimestampReasonableness(int timestamp, String context) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final year2000 = DateTime(2000);
    final year2100 = DateTime(2100);
    
    if (date.isBefore(year2000)) {
      throw StateError('Timestamp too old: $context timestamp $timestamp (${date.toIso8601String()}) is before year 2000');
    }
    
    if (date.isAfter(year2100)) {
      throw StateError('Timestamp too far in future: $context timestamp $timestamp (${date.toIso8601String()}) is after year 2100');
    }
    
    debugPrint('✅ [TimezoneCheck] Timestamp reasonableness validated: $context - ${date.toIso8601String()}');
  }
  
  /// Validate that a completion timestamp is within a reasonable range
  ///
  /// @param completionTimestamp The completion timestamp
  /// @param dateRange The expected date range
  /// @throws StateError if completion is outside expected range
  static void validateCompletionTimestampRange(int completionTimestamp, DateRange dateRange) {
    final completionDate = DateTime.fromMillisecondsSinceEpoch(completionTimestamp);
    
    if (!dateRange.contains(completionDate)) {
      throw StateError('Completion timestamp outside expected range: '
          'Completion: ${completionDate.toIso8601String()}, '
          'Expected range: ${dateRange.start.toIso8601String()} to ${dateRange.end.toIso8601String()}');
    }
    
    debugPrint('✅ [TimezoneCheck] Completion timestamp range validated: ${completionDate.toIso8601String()}');
  }
  
  /// Log timezone information for debugging
  ///
  /// @param operation The operation being performed
  /// @param localDate The local date
  /// @param utcTimestamp The UTC timestamp
  static void logTimezoneInfo(String operation, DateTime localDate, int utcTimestamp) {
    final utcDate = DateTime.fromMillisecondsSinceEpoch(utcTimestamp, isUtc: true);
    final convertedBack = DateTime.fromMillisecondsSinceEpoch(utcTimestamp);
    
    debugPrint('🌍 [TimezoneInfo] $operation:');
    debugPrint('   Local: ${localDate.toIso8601String()}');
    debugPrint('   UTC: ${utcDate.toIso8601String()}');
    debugPrint('   Converted back: ${convertedBack.toIso8601String()}');
    debugPrint('   Timestamp: $utcTimestamp');
  }
}
