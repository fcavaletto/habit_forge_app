import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';

/// State class for notification management
class NotificationState extends ChangeNotifier {
  final NotificationService _notificationService;

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  bool _notificationsEnabled = false;

  NotificationState(this._notificationService);

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _notificationService.initialize();
      _isInitialized = true;

      // Check if notifications are enabled
      await checkNotificationStatus();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to initialize notifications: $e';
      notifyListeners();
    }
  }

  /// Check notification permissions status
  Future<void> checkNotificationStatus() async {
    try {
      _notificationsEnabled = await _notificationService.areNotificationsEnabled();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check notification status: $e';
      notifyListeners();
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final granted = await _notificationService.requestPermissions();

      if (granted) {
        _notificationsEnabled = true;
      }

      _isLoading = false;
      notifyListeners();
      return granted;
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to request permissions: $e';
      notifyListeners();
      return false;
    }
  }

  /// Schedule habit reminder
  Future<void> scheduleHabitReminder(Habit habit) async {
    try {
      await _notificationService.scheduleHabitReminder(habit);
    } catch (e) {
      _error = 'Failed to schedule reminder: $e';
      notifyListeners();
    }
  }

  /// Cancel habit reminder
  Future<void> cancelHabitReminder(String habitId) async {
    try {
      await _notificationService.cancelHabitReminder(habitId);
    } catch (e) {
      _error = 'Failed to cancel reminder: $e';
      notifyListeners();
    }
  }

  /// Schedule reminders for all habits
  Future<void> scheduleAllReminders(List<Habit> habits) async {
    try {
      await _notificationService.scheduleAllReminders(habits);
    } catch (e) {
      _error = 'Failed to schedule reminders: $e';
      notifyListeners();
    }
  }

  /// Show test notification
  Future<void> showTestNotification() async {
    try {
      await _notificationService.showTestNotification();
    } catch (e) {
      _error = 'Failed to show test notification: $e';
      notifyListeners();
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Provider for NotificationState
class NotificationProvider extends NotificationState {
  NotificationProvider(NotificationService notificationService) : super(notificationService);

  // Factory method for easy creation
  factory NotificationProvider.create() {
    return NotificationProvider(NotificationService());
  }
}
