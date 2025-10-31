import 'package:flutter/foundation.dart';

/// Week Calculation Utility Class
///
/// Provides centralized week calculation functions for consistent
/// week handling throughout the app, with support for Monday or Sunday week start.
///
/// Key Features:
/// - Calculate week start date (Monday or Sunday)
/// - Get day labels for week display
/// - Calculate dates for a given week range
class WeekUtils {
  /// Get the start of the week for a given date
  ///
  /// @param date The date to find the week start for
  /// @param weekStartsOnMonday If true, week starts on Monday; if false, on Sunday
  /// @return DateTime representing the start of the week (midnight)
  static DateTime getWeekStart(DateTime date, bool weekStartsOnMonday) {
    final normalized = DateTime(date.year, date.month, date.day);
    
    if (weekStartsOnMonday) {
      // Monday = weekday 1, Sunday = weekday 7
      // Calculate days to subtract to get to Monday
      final daysFromMonday = (normalized.weekday - 1) % 7;
      return normalized.subtract(Duration(days: daysFromMonday));
    } else {
      // Sunday = weekday 7, Monday = weekday 1
      // Calculate days to subtract to get to Sunday
      // Sunday (7) → 0 days, Monday (1) → 1 day, Tuesday (2) → 2 days, etc.
      final daysFromSunday = normalized.weekday == 7 ? 0 : normalized.weekday;
      return normalized.subtract(Duration(days: daysFromSunday));
    }
  }

  /// Get the end of the week for a given date
  ///
  /// @param date The date to find the week end for
  /// @param weekStartsOnMonday If true, week starts on Monday; if false, on Sunday
  /// @return DateTime representing the end of the week (23:59:59)
  static DateTime getWeekEnd(DateTime date, bool weekStartsOnMonday) {
    final weekStart = getWeekStart(date, weekStartsOnMonday);
    final weekEnd = weekStart.add(const Duration(days: 6));
    return DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
  }

  /// Get day labels for week display
  ///
  /// @param weekStartsOnMonday If true, returns [M, T, W, T, F, S, S]; if false, [S, M, T, W, T, F, S]
  /// @return List of 7 day label strings
  static List<String> getDayLabels(bool weekStartsOnMonday) {
    if (weekStartsOnMonday) {
      return ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    } else {
      return ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    }
  }

  /// Get dates for the current week (week 0) and previous weeks
  ///
  /// Returns a list of dates representing 4 weeks, where:
  /// - Week 0 = current week (today's week)
  /// - Week 1-3 = previous weeks
  ///
  /// @param currentDate The current date (usually VirtualDateService().currentDate)
  /// @param weekStartsOnMonday If true, week starts on Monday; if false, on Sunday
  /// @param numberOfWeeks Number of weeks to return (default: 4)
  /// @return List of lists: outer list = weeks, inner list = 7 dates for that week
  static List<List<DateTime>> getWeeksData(
    DateTime currentDate,
    bool weekStartsOnMonday, {
    int numberOfWeeks = 4,
  }) {
    final weeks = <List<DateTime>>[];
    
    for (int weekIndex = 0; weekIndex < numberOfWeeks; weekIndex++) {
      // Calculate the reference date for this week
      // Week 0 = current week, so we go back by (weekIndex * 7) days
      final weekReferenceDate = currentDate.subtract(
        Duration(days: weekIndex * 7),
      );
      
      // Get the start of this week
      final weekStart = getWeekStart(weekReferenceDate, weekStartsOnMonday);
      
      // Generate 7 dates for this week
      final weekDates = List.generate(7, (dayIndex) {
        return weekStart.add(Duration(days: dayIndex));
      });
      
      weeks.add(weekDates);
    }
    
    debugPrint('📅 [WeekUtils] Generated $numberOfWeeks weeks starting from ${weeks[0][0].toIso8601String()}');
    return weeks;
  }

  /// Check if a date is in the current week
  ///
  /// @param date The date to check
  /// @param currentDate The current reference date
  /// @param weekStartsOnMonday If true, week starts on Monday; if false, on Sunday
  /// @return true if the date is in the current week
  static bool isInCurrentWeek(
    DateTime date,
    DateTime currentDate,
    bool weekStartsOnMonday,
  ) {
    final dateWeekStart = getWeekStart(date, weekStartsOnMonday);
    final currentWeekStart = getWeekStart(currentDate, weekStartsOnMonday);
    return dateWeekStart == currentWeekStart;
  }
}

