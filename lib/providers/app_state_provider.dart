import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import 'habit_provider.dart';
import 'notification_provider.dart';

/// Combined app state provider that manages all app-wide state
class AppState extends ChangeNotifier {
  final HabitProvider _habitProvider;
  final NotificationProvider _notificationProvider;

  AppState(this._habitProvider, this._notificationProvider) {
    // Listen to changes in child providers
    _habitProvider.addListener(() {
      debugPrint('🔗 AppState received notification from HabitProvider');
      notifyListeners();
    });
    _notificationProvider.addListener(() {
      debugPrint('🔗 AppState received notification from NotificationProvider');
      notifyListeners();
    });
  }

  // Habit provider access
  HabitProvider get habitProvider => _habitProvider;
  List<Habit> get habits => _habitProvider.habits;
  bool get isLoadingHabits => _habitProvider.isLoading;
  String? get habitError => _habitProvider.error;

  // Notification provider access
  NotificationProvider get notificationProvider => _notificationProvider;
  bool get isNotificationInitialized => _notificationProvider.isInitialized;
  bool get notificationsEnabled => _notificationProvider.notificationsEnabled;
  String? get notificationError => _notificationProvider.error;

  // Combined loading state
  bool get isLoading => _habitProvider.isLoading || _notificationProvider.isLoading;

  // Combined error state
  String? get error => _habitProvider.error ?? _notificationProvider.error;

  /// Initialize all services
  Future<void> initialize() async {
    // Initialize habit provider
    await _habitProvider.initialize();
    
    await Future.wait([
      _habitProvider.loadHabits(),
      _notificationProvider.initialize(),
    ]);
  }

  /// Clear all errors
  void clearErrors() {
    _habitProvider.clearError();
    _notificationProvider.clearError();
  }

  @override
  void dispose() {
    _habitProvider.removeListener(notifyListeners);
    _notificationProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Provider for AppState
class AppStateProvider extends AppState {
  AppStateProvider(super.habitProvider, super.notificationProvider);

  // Factory method for easy creation with SQLite repository
  factory AppStateProvider.create() {
    final habitProvider = HabitProvider.create();
    final notificationService = NotificationService();
    final notificationProvider = NotificationProvider(notificationService);

    return AppStateProvider(habitProvider, notificationProvider);
  }
}
