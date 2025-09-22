import 'package:flutter/foundation.dart';

/// Virtual Date Service - Provides centralized date management for the app
/// 
/// This service allows the app to operate on a virtual date instead of the system date.
/// When a virtual date is set, all date-dependent functionality throughout the app
/// will use this virtual date instead of DateTime.now().
/// 
/// Key Features:
/// - Singleton pattern ensures single source of truth
/// - Seamless fallback to system date when no virtual date is set
/// - Easy integration with existing HabitProvider.selectedDate
/// - Non-breaking changes to existing functionality
class VirtualDateService {
  static final VirtualDateService _instance = VirtualDateService._internal();
  factory VirtualDateService() => _instance;
  VirtualDateService._internal();

  DateTime? _virtualDate;
  bool _isVirtualMode = false;

  /// Gets the current date for the app
  /// Returns virtual date if set, otherwise returns system date
  DateTime get currentDate => _isVirtualMode && _virtualDate != null 
      ? _virtualDate! 
      : DateTime.now();

  /// Whether the app is currently in virtual date mode
  bool get isVirtualMode => _isVirtualMode;

  /// The currently set virtual date (null if not in virtual mode)
  DateTime? get virtualDate => _isVirtualMode ? _virtualDate : null;

  /// Sets a virtual date for the app
  /// All date-dependent functionality will use this date instead of system date
  void setVirtualDate(DateTime date) {
    _virtualDate = DateTime(date.year, date.month, date.day); // Normalize to start of day
    _isVirtualMode = true;
    debugPrint('🕒 Virtual date set to: ${_formatDate(_virtualDate!)}');
  }

  /// Resets to system date mode
  /// All date-dependent functionality will use DateTime.now() again
  void resetToSystemDate() {
    _virtualDate = null;
    _isVirtualMode = false;
    debugPrint('🕒 Virtual date reset to system date');
  }

  /// Checks if a given date is "today" from the app's perspective
  bool isToday(DateTime date) {
    final current = currentDate;
    return date.year == current.year && 
           date.month == current.month && 
           date.day == current.day;
  }

  /// Gets the start of the current day (virtual or system)
  DateTime get startOfDay {
    final current = currentDate;
    return DateTime(current.year, current.month, current.day);
  }

  /// Gets the end of the current day (virtual or system)
  DateTime get endOfDay {
    final current = currentDate;
    return DateTime(current.year, current.month, current.day, 23, 59, 59, 999);
  }

  /// Helper method to format dates for logging
  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }
}
