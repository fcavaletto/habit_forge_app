import 'package:flutter/foundation.dart';
import '../services/virtual_date_service.dart';
import '../repositories/settings_repository.dart';

/// Date Provider - Reactive state management for virtual date system
/// 
/// This provider exposes the VirtualDateService state reactively to the UI,
/// allowing widgets to automatically update when the virtual date changes.
/// 
/// Integration:
/// - Works with existing Provider architecture
/// - Notifies all listeners when date changes
/// - Provides easy access to virtual date state
/// - Persists virtual date across app restarts
class DateProvider extends ChangeNotifier {
  final VirtualDateService _dateService = VirtualDateService();
  
  /// Initialize the date provider with settings repository
  Future<void> initialize(SettingsRepository settingsRepository) async {
    await _dateService.initialize(settingsRepository);
    notifyListeners(); // Notify listeners that date state may have changed
  }

  /// Gets the current date for the app (virtual or system)
  DateTime get currentDate => _dateService.currentDate;

  /// Whether the app is currently in virtual date mode
  bool get isVirtualMode => _dateService.isVirtualMode;

  /// The currently set virtual date (null if not in virtual mode)
  DateTime? get virtualDate => _dateService.virtualDate;

  /// Sets a virtual date and notifies all listeners
  Future<void> setVirtualDate(DateTime date) async {
    await _dateService.setVirtualDate(date);
    debugPrint('🔔 DateProvider notifying listeners - Mode: Virtual');
    notifyListeners();
  }

  /// Resets to system date and notifies all listeners
  Future<void> resetToSystemDate() async {
    await _dateService.resetToSystemDate();
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
