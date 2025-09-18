import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../repositories/settings_repository.dart';
import 'habit_provider.dart';
import 'notification_provider.dart';
import 'theme_provider.dart';
import 'completion_count_provider.dart';
import 'extended_color_palette_provider.dart';

/// Combined app state provider that manages all app-wide state
class AppState extends ChangeNotifier {
  final HabitProvider _habitProvider;
  final NotificationProvider _notificationProvider;
  final ThemeProvider _themeProvider;
  final CompletionCountProvider _completionCountProvider;
  final ExtendedColorPaletteProvider _extendedColorPaletteProvider;

  AppState(this._habitProvider, this._notificationProvider, this._themeProvider, this._completionCountProvider, this._extendedColorPaletteProvider) {
    // Listen to changes in child providers
    _habitProvider.addListener(() {
      debugPrint('🔗 AppState received notification from HabitProvider');
      notifyListeners();
    });
    _notificationProvider.addListener(() {
      debugPrint('🔗 AppState received notification from NotificationProvider');
      notifyListeners();
    });
    _themeProvider.addListener(() {
      debugPrint('🔗 AppState received notification from ThemeProvider');
      notifyListeners();
    });
    _completionCountProvider.addListener(() {
      debugPrint('🔗 AppState received notification from CompletionCountProvider');
      notifyListeners();
    });
    _extendedColorPaletteProvider.addListener(() {
      debugPrint('🔗 AppState received notification from ExtendedColorPaletteProvider');
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

  // Theme provider access
  ThemeProvider get themeProvider => _themeProvider;
  ThemeMode get themeMode => _themeProvider.themeMode;

  // Completion count provider access
  CompletionCountProvider get completionCountProvider => _completionCountProvider;
  bool get showCompletionCount => _completionCountProvider.showCompletionCount;

  // Extended color palette provider access
  ExtendedColorPaletteProvider get extendedColorPaletteProvider => _extendedColorPaletteProvider;
  bool get isExtendedColorPalette => _extendedColorPaletteProvider.isExtendedMode;

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
      _themeProvider.loadThemeMode(),
      _completionCountProvider.loadCompletionCountSetting(),
      _extendedColorPaletteProvider.loadExtendedColorPaletteSetting(),
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
    _themeProvider.removeListener(notifyListeners);
    _completionCountProvider.removeListener(notifyListeners);
    _extendedColorPaletteProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Provider for AppState
class AppStateProvider extends AppState {
  AppStateProvider(super.habitProvider, super.notificationProvider, super.themeProvider, super.completionCountProvider, super.extendedColorPaletteProvider);

  // Factory method for easy creation with SQLite repository
  factory AppStateProvider.create() {
    final habitProvider = HabitProvider.create();
    final notificationService = NotificationService();
    final notificationProvider = NotificationProvider(notificationService);
    final settingsRepository = SettingsRepository(databaseService);
    final themeProvider = ThemeProvider(settingsRepository);
    final completionCountProvider = CompletionCountProvider(settingsRepository);
    final extendedColorPaletteProvider = ExtendedColorPaletteProvider(settingsRepository);

    return AppStateProvider(habitProvider, notificationProvider, themeProvider, completionCountProvider, extendedColorPaletteProvider);
  }
}
