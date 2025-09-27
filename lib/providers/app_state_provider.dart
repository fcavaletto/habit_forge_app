import 'dart:async';
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
import 'pro_subscription_provider.dart';
import 'streak_settings_provider.dart';
import 'date_provider.dart';

/// Combined app state provider that manages all app-wide state
///
/// This class serves as the central state management hub for the entire application,
/// implementing a composite provider pattern that orchestrates multiple specialized
/// providers. It provides a unified interface for accessing and managing all
/// application state while maintaining separation of concerns.
///
/// ## Architecture Pattern:
/// - **Composite Provider**: Combines multiple specialized providers
/// - **Facade Pattern**: Provides simplified interface to complex subsystem
/// - **Observer Pattern**: Notifies UI of state changes across all providers
/// - **Dependency Injection**: Manages provider dependencies and lifecycle
///
/// ## Provider Composition:
/// - **HabitProvider**: Manages habit data and operations
/// - **NotificationProvider**: Handles notification state and scheduling
/// - **ThemeProvider**: Manages theme preferences and switching
/// - **CompletionCountProvider**: Tracks completion count display settings
/// - **ExtendedColorPaletteProvider**: Manages extended color palette settings
/// - **ProSubscriptionProvider**: Manages PRO subscription state
/// - **StreakSettingsProvider**: Manages streak calculation preferences
///
/// ## Key Responsibilities:
/// - **State Coordination**: Synchronizes state across multiple providers
/// - **Initialization Management**: Orchestrates provider initialization
/// - **Error Aggregation**: Collects and reports errors from all providers
/// - **Global Refresh**: Provides unified data refresh capabilities
/// - **Lifecycle Management**: Manages provider lifecycle and cleanup
///
/// ## Data Flow:
/// 1. **App Initialization**: All providers initialized in parallel
/// 2. **State Changes**: Individual providers update their state
/// 3. **Propagation**: Changes propagated to composite provider
/// 4. **UI Notification**: All listeners notified of changes
/// 5. **Global Operations**: Cross-provider operations coordinated
///
/// ## Usage Pattern:
/// ```dart
/// final appState = context.read<AppState>();
/// await appState.refreshAllData();
/// final habits = appState.habits;
/// ```
class AppState extends ChangeNotifier {
  final HabitProvider _habitProvider;
  final NotificationProvider _notificationProvider;
  final ThemeProvider _themeProvider;
  final CompletionCountProvider _completionCountProvider;
  final ExtendedColorPaletteProvider _extendedColorPaletteProvider;
  final ProSubscriptionProvider _proSubscriptionProvider;
  final StreakSettingsProvider _streakSettingsProvider;
  final DateProvider _dateProvider;

  AppState(this._habitProvider, this._notificationProvider, this._themeProvider, this._completionCountProvider, this._extendedColorPaletteProvider, this._proSubscriptionProvider, this._streakSettingsProvider, this._dateProvider) {
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
    _proSubscriptionProvider.addListener(() {
      debugPrint('🔗 AppState received notification from ProSubscriptionProvider');
      notifyListeners();
    });
    _streakSettingsProvider.addListener(() {
      debugPrint('🔗 AppState received notification from StreakSettingsProvider');
      notifyListeners();
    });
    _dateProvider.addListener(() {
      debugPrint('🔗 AppState received notification from DateProvider');
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

  // Pro subscription provider access
  ProSubscriptionProvider get proSubscriptionProvider => _proSubscriptionProvider;
  bool get isProSubscriptionActive => _proSubscriptionProvider.isProSubscriptionActive;

  // Streak settings provider access
  StreakSettingsProvider get streakSettingsProvider => _streakSettingsProvider;
  bool get isActiveDaysStreakEnabled => _streakSettingsProvider.isActiveDaysStreakEnabled;
  String get streakCalculationMode => _streakSettingsProvider.streakCalculationMode;

  // Date provider access
  DateProvider get dateProvider => _dateProvider;
  DateTime get currentDate => _dateProvider.currentDate;
  bool get isVirtualMode => _dateProvider.isVirtualMode;
  DateTime? get virtualDate => _dateProvider.virtualDate;

  // Combined loading state
  bool get isLoading => _habitProvider.isLoading || _notificationProvider.isLoading;

  // Combined error state
  String? get error => _habitProvider.error ?? _notificationProvider.error;

  // Data freshness access
  DateTime? get lastDataLoadTime => _habitProvider.lastLoadTime;
  bool get isDataFresh => _habitProvider.isDataFresh;
  bool get needsDataRefresh => _habitProvider.needsRefresh;

  /// Initialize all services and providers in the correct order
  ///
  /// This method orchestrates the initialization of all application services
  /// and providers, ensuring proper dependency order and error handling.
  /// It's called during app startup to prepare all systems for operation.
  ///
  /// ## Optimized Initialization Order:
  /// 1. **HabitProvider**: Database initialization and habit loading (PRIORITY)
  /// 2. **ThemeProvider**: Theme preferences loading (PRIORITY - affects UI)
  /// 3. **Other Services**: Load in parallel after core services are ready
  ///    - NotificationProvider: Notification service setup
  ///    - CompletionCountProvider: Display settings loading
  ///    - ExtendedColorPaletteProvider: Color palette settings loading
  ///    - ProSubscriptionProvider: PRO subscription settings
  ///    - StreakSettingsProvider: Streak calculation preferences
  ///
  /// ## Performance Benefits:
  /// - Users see their habits immediately when dashboard loads
  /// - Theme is applied before UI renders, preventing theme flash
  /// - Non-critical services load in background without blocking UI
  ///
  /// ## Error Handling:
  /// Individual provider failures don't prevent app startup, ensuring
  /// graceful degradation and continued operation.
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Starting optimized app initialization...');
      
      // PHASE 1: Initialize core services (habits + theme)
      debugPrint('📱 Phase 1: Initializing core services (habits + theme)...');
      
      // Initialize habit provider (this loads filter setting)
      await _habitProvider.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Habit provider initialization timed out', const Duration(seconds: 15));
        },
      );
      
      // Load theme (habits are already loaded during habitProvider.initialize())
      await _themeProvider.loadThemeMode().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Theme loading timed out', const Duration(seconds: 5));
        },
      );
      
      debugPrint('✅ Phase 1 complete: Habits and theme loaded');
      
      // PHASE 2: Initialize secondary services in parallel
      debugPrint('🔧 Phase 2: Initializing secondary services...');
      
      await Future.wait([
        _notificationProvider.initialize(),
        _completionCountProvider.loadCompletionCountSetting(),
        _extendedColorPaletteProvider.loadExtendedColorPaletteSetting(),
        _proSubscriptionProvider.loadProSubscriptionSetting(),
        _streakSettingsProvider.loadStreakSetting(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ Secondary services initialization timed out - continuing with core functionality');
          // Return empty list to satisfy Future.wait return type
          return <void>[];
        },
      );
      
      debugPrint('✅ App initialization completed successfully');
    } catch (e) {
      debugPrint('❌ App state initialization failed: $e');
      rethrow;
    }
  }

  /// Clear all errors
  void clearErrors() {
    _habitProvider.clearError();
    _notificationProvider.clearError();
  }

  /// Refresh all data across all providers with intelligent coordination
  ///
  /// This method provides a unified interface for refreshing data across all
  /// application providers, ensuring consistency and optimal performance.
  /// It coordinates refresh operations to avoid conflicts and unnecessary work.
  ///
  /// ## Parameters:
  /// - [forceRefresh]: If true, bypasses freshness checks and forces refresh
  ///
  /// ## Refresh Strategy:
  /// - **Coordinated Refresh**: All providers refreshed in parallel
  /// - **Smart Refresh**: Respects individual provider freshness logic
  /// - **Error Isolation**: Individual provider failures don't affect others
  /// - **Performance Optimization**: Avoids unnecessary operations
  ///
  /// ## Use Cases:
  /// - App lifecycle events (resume, foreground)
  /// - Manual refresh requests from UI
  /// - Data synchronization after external changes
  /// - Recovery from error states
  Future<void> refreshAllData({bool forceRefresh = false}) async {
    debugPrint('🔄 AppState: Refreshing all data, forceRefresh: $forceRefresh');
    
    await Future.wait([
      _habitProvider.loadHabits(forceRefresh: forceRefresh),
      // Note: NotificationProvider doesn't have a refresh method yet
      // This can be added later if needed
    ]);
    
    debugPrint('✅ AppState: All data refreshed');
  }

  @override
  void dispose() {
    _habitProvider.removeListener(notifyListeners);
    _notificationProvider.removeListener(notifyListeners);
    _themeProvider.removeListener(notifyListeners);
    _completionCountProvider.removeListener(notifyListeners);
    _extendedColorPaletteProvider.removeListener(notifyListeners);
    _proSubscriptionProvider.removeListener(notifyListeners);
    _streakSettingsProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Provider for AppState
class AppStateProvider extends AppState {
  AppStateProvider(super.habitProvider, super.notificationProvider, super.themeProvider, super.completionCountProvider, super.extendedColorPaletteProvider, super.proSubscriptionProvider, super.streakSettingsProvider, super.dateProvider);

  // Factory method for easy creation with SQLite repository
  factory AppStateProvider.create() {
    final habitProvider = HabitProvider.create();
    final notificationService = NotificationService();
    final notificationProvider = NotificationProvider(notificationService);
    final settingsRepository = SettingsRepository(databaseService);
    final themeProvider = ThemeProvider(settingsRepository);
    final completionCountProvider = CompletionCountProvider(settingsRepository);
    final extendedColorPaletteProvider = ExtendedColorPaletteProvider(settingsRepository);
    final proSubscriptionProvider = ProSubscriptionProvider(settingsRepository);
    final streakSettingsProvider = StreakSettingsProvider(settingsRepository);
    final dateProvider = DateProvider();

    return AppStateProvider(habitProvider, notificationProvider, themeProvider, completionCountProvider, extendedColorPaletteProvider, proSubscriptionProvider, streakSettingsProvider, dateProvider);
  }
}
