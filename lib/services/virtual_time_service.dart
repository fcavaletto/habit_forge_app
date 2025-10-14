import 'package:flutter/material.dart';

/// Virtual Time Service - Provides centralized time management for the app
/// 
/// This service allows the app to operate on a virtual time instead of the system time.
/// When a virtual time is set, all time-dependent functionality throughout the app
/// will use this virtual time instead of TimeOfDay.now().
/// 
/// Key Features:
/// - Singleton pattern ensures single source of truth
/// - Seamless fallback to system time when no virtual time is set
/// - Session-based (resets on app restart)
/// - Easy integration with existing HabitProvider.selectedTime
class VirtualTimeService {
  static final VirtualTimeService _instance = VirtualTimeService._internal();
  factory VirtualTimeService() => _instance;
  VirtualTimeService._internal();

  TimeOfDay? _virtualTime;
  bool _isTimeOverridden = false;

  /// Gets the current time for the app
  /// Returns virtual time if set, otherwise returns system time
  TimeOfDay get currentTime => _isTimeOverridden && _virtualTime != null 
      ? _virtualTime! 
      : TimeOfDay.now();

  /// Whether the user has overridden the time (set to non-current time)
  bool get isTimeOverridden {
    if (!_isTimeOverridden || _virtualTime == null) return false;
    
    final now = TimeOfDay.now();
    return !(_virtualTime!.hour == now.hour && 
             _virtualTime!.minute == now.minute);
  }

  /// The currently set virtual time (null if not in virtual time mode)
  TimeOfDay? get virtualTime => _isTimeOverridden ? _virtualTime : null;

  /// Sets a virtual time for the app
  /// All time-dependent functionality will use this time instead of system time
  void setTimeOverride(TimeOfDay time) {
    _virtualTime = time;
    _isTimeOverridden = true;
    debugPrint('🕐 Virtual time set to: ${_formatTime(_virtualTime!)}');
  }

  /// Resets to system time mode
  /// All time-dependent functionality will use TimeOfDay.now() again
  void resetToSystemTime() {
    _virtualTime = null;
    _isTimeOverridden = false;
    debugPrint('🕐 Virtual time reset to system time');
  }

  /// Helper method to format times for logging
  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
