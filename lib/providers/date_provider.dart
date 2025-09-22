import 'package:flutter/foundation.dart';
import '../services/virtual_date_service.dart';

/// Date Provider - Reactive state management for virtual date system
/// 
/// This provider exposes the VirtualDateService state reactively to the UI,
/// allowing widgets to automatically update when the virtual date changes.
/// 
/// Integration:
/// - Works with existing Provider architecture
/// - Notifies all listeners when date changes
/// - Provides easy access to virtual date state
class DateProvider extends ChangeNotifier {
  final VirtualDateService _dateService = VirtualDateService();

  /// Gets the current date for the app (virtual or system)
  DateTime get currentDate => _dateService.currentDate;

  /// Whether the app is currently in virtual date mode
  bool get isVirtualMode => _dateService.isVirtualMode;

  /// The currently set virtual date (null if not in virtual mode)
  DateTime? get virtualDate => _dateService.virtualDate;

  /// Sets a virtual date and notifies all listeners
  void setVirtualDate(DateTime date) {
    _dateService.setVirtualDate(date);
    debugPrint('🔔 DateProvider notifying listeners - Mode: Virtual');
    notifyListeners();
  }

  /// Resets to system date and notifies all listeners
  void resetToSystemDate() {
    _dateService.resetToSystemDate();
    debugPrint('🔔 DateProvider notifying listeners - Mode: System');
    notifyListeners();
  }

  /// Checks if a given date is "today" from the app's perspective
  bool isToday(DateTime date) => _dateService.isToday(date);

  /// Gets the start of the current day (virtual or system)
  DateTime get startOfDay => _dateService.startOfDay;

  /// Gets the end of the current day (virtual or system)
  DateTime get endOfDay => _dateService.endOfDay;

  /// Helper method to format the current date for display
  String get formattedCurrentDate {
    final date = currentDate;
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }
}
