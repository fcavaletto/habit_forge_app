import 'package:flutter/foundation.dart';

/// Date Range Utility Class
///
/// Provides centralized date range calculations for consistent
/// time period handling throughout the app.
///
/// Key Features:
/// - Consistent date range calculations using virtual date service
/// - Validation of date ranges
/// - Clear separation of date logic from business logic
class DateRangeUtils {
  /// Get date range for "Last 7 Days" analysis
  ///
  /// @param currentDate The current virtual date
  /// @return DateRange with start and end dates
  static DateRange getLast7Days(DateTime currentDate) {
    final startDate = currentDate.subtract(const Duration(days: 6));
    final endDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59);
    
    debugPrint('📅 [DateRange] Last 7 Days: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    return DateRange(startDate, endDate);
  }
  
  /// Get date range for "Last 30 Days" analysis
  ///
  /// @param currentDate The current virtual date
  /// @return DateRange with start and end dates
  static DateRange getLast30Days(DateTime currentDate) {
    final startDate = currentDate.subtract(const Duration(days: 29));
    final endDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59);
    
    debugPrint('📅 [DateRange] Last 30 Days: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    return DateRange(startDate, endDate);
  }
  
  /// Get date range for "Total" analysis (all time)
  ///
  /// @param currentDate The current virtual date
  /// @return DateRange with start and end dates
  static DateRange getTotal(DateTime currentDate) {
    final startDate = DateTime(2020); // Arbitrary early date
    final endDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59);
    
    debugPrint('📅 [DateRange] Total: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    return DateRange(startDate, endDate);
  }
  
  /// Validate that a date range is logical and consistent
  ///
  /// @param startDate The start date of the range
  /// @param endDate The end date of the range
  /// @throws ArgumentError if the date range is invalid
  static void validateDateRange(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('Start date cannot be after end date: ${startDate.toIso8601String()} > ${endDate.toIso8601String()}');
    }
    
    if (endDate.difference(startDate).inDays > 365) {
      throw ArgumentError('Date range cannot exceed 365 days: ${endDate.difference(startDate).inDays} days');
    }
    
    if (startDate.isAfter(DateTime.now())) {
      throw ArgumentError('Start date cannot be in the future: ${startDate.toIso8601String()}');
    }
    
    debugPrint('✅ [DateRange] Validation passed: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
  }
  
  /// Get the number of days in a date range
  ///
  /// @param startDate The start date
  /// @param endDate The end date
  /// @return Number of days in the range
  static int getDaysInRange(DateTime startDate, DateTime endDate) {
    return endDate.difference(startDate).inDays + 1;
  }
  
  /// Check if a date falls within a given range
  ///
  /// @param date The date to check
  /// @param startDate The start of the range
  /// @param endDate The end of the range
  /// @return true if the date is within the range
  static bool isDateInRange(DateTime date, DateTime startDate, DateTime endDate) {
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }
}

/// Immutable class representing a date range
class DateRange {
  final DateTime start;
  final DateTime end;
  
  const DateRange(this.start, this.end);
  
  /// Get the duration of this date range
  Duration get duration => end.difference(start);
  
  /// Get the number of days in this range
  int get days => end.difference(start).inDays + 1;
  
  /// Check if a date falls within this range
  bool contains(DateTime date) {
    return !date.isBefore(start) && !date.isAfter(end);
  }
  
  @override
  String toString() {
    return 'DateRange(${start.toIso8601String()} to ${end.toIso8601String()})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange && 
           other.start == start && 
           other.end == end;
  }
  
  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
