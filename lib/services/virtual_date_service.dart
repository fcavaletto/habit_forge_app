import 'package:flutter/foundation.dart';
import '../repositories/settings_repository.dart';

/// Virtual Date Service - Provides centralized date management for the app
/// 
/// This service allows the app to operate on a virtual date instead of the system date.
/// When a virtual date is set, all date-dependent functionality throughout the app
/// will use this virtual date instead of DateTime.now().
/// 
/// Key Features:
/// - Singleton pattern ensures single source of truth
/// - Seamless fallback to system date when no virtual date is set
/// - Persistent virtual date across app restarts
/// - Easy integration with existing HabitProvider.selectedDate
/// - Non-breaking changes to existing functionality
class VirtualDateService {
  static final VirtualDateService _instance = VirtualDateService._internal();
  factory VirtualDateService() => _instance;
  VirtualDateService._internal();

  DateTime? _virtualDate;
  bool _isVirtualMode = false;
  SettingsRepository? _settingsRepository;
  
  // Settings keys for persistence
  static const String _virtualDateKey = 'virtual_date';
  static const String _virtualModeKey = 'virtual_mode';

  /// Gets the current date for the app
  /// Returns virtual date if set, otherwise returns system date
  DateTime get currentDate => _isVirtualMode && _virtualDate != null 
      ? _virtualDate! 
      : DateTime.now();

  /// Whether the app is currently in virtual date mode
  bool get isVirtualMode => _isVirtualMode;

  /// Whether the user has overridden the date (set to non-today)
  bool get isDateOverridden {
    if (!_isVirtualMode || _virtualDate == null) return false;
    
    final today = DateTime.now();
    final virtual = _virtualDate!;
    
    return !(virtual.year == today.year && 
             virtual.month == today.month && 
             virtual.day == today.day);
  }

  /// The currently set virtual date (null if not in virtual mode)
  DateTime? get virtualDate => _isVirtualMode ? _virtualDate : null;

  /// Initialize the service with settings repository for persistence
  Future<void> initialize(SettingsRepository settingsRepository) async {
    _settingsRepository = settingsRepository;
    await _loadVirtualDateFromStorage();
  }

  /// Sets a virtual date for the app
  /// All date-dependent functionality will use this date instead of system date
  Future<void> setVirtualDate(DateTime date) async {
    _virtualDate = DateTime(date.year, date.month, date.day); // Normalize to start of day
    _isVirtualMode = true;
    
    // Persist to storage
    if (_settingsRepository != null) {
      await _settingsRepository!.saveSetting(_virtualDateKey, _virtualDate!.toIso8601String());
      await _settingsRepository!.saveSetting(_virtualModeKey, 'true');
    }
    
    debugPrint('🕒 Virtual date set to: ${_formatDate(_virtualDate!)}');
  }

  /// Resets to system date mode
  /// All date-dependent functionality will use DateTime.now() again
  Future<void> resetToSystemDate() async {
    _virtualDate = null;
    _isVirtualMode = false;
    
    // Persist to storage
    if (_settingsRepository != null) {
      await _settingsRepository!.deleteSetting(_virtualDateKey);
      await _settingsRepository!.saveSetting(_virtualModeKey, 'false');
    }
    
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

  /// Load virtual date from persistent storage
  Future<void> _loadVirtualDateFromStorage() async {
    if (_settingsRepository == null) return;
    
    try {
      // Load virtual mode setting
      final virtualModeString = await _settingsRepository!.getSetting(_virtualModeKey);
      final isVirtualMode = virtualModeString?.toLowerCase() == 'true';
      
      if (isVirtualMode) {
        // Load virtual date
        final virtualDateString = await _settingsRepository!.getSetting(_virtualDateKey);
        if (virtualDateString != null) {
          final parsedDate = DateTime.parse(virtualDateString);
          _virtualDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
          _isVirtualMode = true;
          debugPrint('🕒 Virtual date restored from storage: ${_formatDate(_virtualDate!)}');
        } else {
          // Virtual mode was enabled but no date found, reset to system date
          await resetToSystemDate();
        }
      } else {
        // Virtual mode is disabled
        _isVirtualMode = false;
        _virtualDate = null;
        debugPrint('🕒 Virtual date mode disabled, using system date');
      }
    } catch (e) {
      debugPrint('❌ Error loading virtual date from storage: $e');
      // Reset to system date on error
      _isVirtualMode = false;
      _virtualDate = null;
    }
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
