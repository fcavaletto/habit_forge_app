import 'dart:async';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../services/virtual_time_service.dart';
import '../repositories/settings_repository.dart';
import 'habit_provider.dart';
import 'notification_provider.dart';
import 'theme_provider.dart';
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
  final ProSubscriptionProvider _proSubscriptionProvider;
  final StreakSettingsProvider _streakSettingsProvider;
  final DateProvider _dateProvider;
  final VirtualTimeService _virtualTimeService = VirtualTimeService();
  final SettingsRepository _settingsRepository;

  // Smart cache notification system
  Timer? _notificationDebounce;
  bool _hasNotificationPending = false;
  int _lastHabitCount = 0;
  ThemeMode? _lastThemeMode;
  
  AppState(
    this._habitProvider,
    this._notificationProvider,
    this._themeProvider,
    this._proSubscriptionProvider,
    this._streakSettingsProvider,
    this._dateProvider,
    this._settingsRepository,
  ) {
    // Initialize last known states
    _lastHabitCount = _habitProvider.habits.length;
    _lastThemeMode = _themeProvider.themeMode;
    
    // Listen to changes in child providers with smart cache notification
    _habitProvider.addListener(() {
      debugPrint('🔗 AppState received notification from HabitProvider');
      _smartCacheNotify('HabitProvider');
    });
    _themeProvider.addListener(() {
      debugPrint('🔗 AppState received notification from ThemeProvider');
      _smartCacheNotify('ThemeProvider');
    });
    _dateProvider.addListener(() async {
      debugPrint('🔗 AppState received notification from DateProvider');
      // Handle date changes with cache invalidation and data reloading
      await _handleDateChange();
      _smartCacheNotify('DateProvider');
    });
  }

  /// Handle date changes with cache invalidation and data reloading
  Future<void> _handleDateChange() async {
    final wasInOverrideMode = _dateProvider.isVirtualMode;
    final isNowInOverrideMode = _dateProvider.isVirtualMode;

    debugPrint('🔍 Date change handling:');
    debugPrint('  - wasInOverrideMode: $wasInOverrideMode');
    debugPrint('  - isNowInOverrideMode: $isNowInOverrideMode');

    // NEW: Simple cache invalidation logic based on override mode changes
    if (!wasInOverrideMode && isNowInOverrideMode) {
      // Entering override mode - invalidate cache and reload data
      debugPrint(
        '🗑️ Entering date override mode - invalidating persistent cache',
      );
      try {
        await _habitProvider.invalidatePersistentCache();
        debugPrint('✅ Cleared persistent cache');
      } catch (e) {
        debugPrint('❌ Error invalidating cache: $e');
        // Continue operation even if cache invalidation fails
      }
      // CRITICAL: Reload habits from database with new virtual date
      debugPrint('🔄 Reloading habits from database for new virtual date');
      await _habitProvider.refreshDataSilently();
    } else if (wasInOverrideMode && !isNowInOverrideMode) {
      // Exiting override mode - allow cache recreation
      debugPrint(
        '🔄 Exiting date override mode - cache will be recreated on next interaction',
      );
      // Don't recreate cache here - let Dashboard interactions handle it
    } else if (wasInOverrideMode && isNowInOverrideMode) {
      // Date changed within override mode - invalidate cached data and reload
      debugPrint(
        '🗑️ Date changed within override mode - invalidating cached data',
      );
      _habitProvider.invalidateCachedData();
      // CRITICAL: Reload habits from database for new virtual date
      debugPrint('🔄 Reloading habits from database for new virtual date');
      await _habitProvider.refreshDataSilently();
    }
  }

  /// Smart cache notification with change detection and selective debouncing
  /// 
  /// Prevents unnecessary cache invalidations by:
  /// 1. Detecting actual state changes
  /// 2. Immediate notification for theme changes (user expects instant feedback)
  /// 3. Debouncing rapid successive notifications (300ms window) for other changes
  /// 4. Batching multiple notifications into one
  void _smartCacheNotify(String source) {
    // Check if anything actually changed
    final habitCountChanged = _habitProvider.habits.length != _lastHabitCount;
    final themeChanged = _themeProvider.themeMode != _lastThemeMode;
    
    final hasActualChanges = habitCountChanged || themeChanged;
    
    if (!hasActualChanges && source != 'HabitProvider') {
      // For non-HabitProvider sources, skip if no tracked changes detected
      // Note: HabitProvider always notifies because completions may have changed
      debugPrint('⏭️ AppState: No cache-relevant changes detected from $source, skipping notification');
      return;
    }
    
    // Update last known states
    _lastHabitCount = _habitProvider.habits.length;
    _lastThemeMode = _themeProvider.themeMode;
    
    // Handle theme changes immediately without debouncing
    if (source == 'ThemeProvider' && themeChanged) {
      debugPrint('🎨 AppState: Theme change detected, notifying immediately');
      notifyListeners();
      return;
    }
    
    // For other changes, use debouncing
    // Mark that we have a pending notification
    _hasNotificationPending = true;
    
    // Cancel existing debounce timer
    _notificationDebounce?.cancel();
    
    // Set up new debounce timer (300ms window)
    _notificationDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_hasNotificationPending) {
        debugPrint('🔔 AppState: Notifying listeners (debounced from $source)');
        _hasNotificationPending = false;
        notifyListeners();
      }
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


  // Pro subscription provider access
  ProSubscriptionProvider get proSubscriptionProvider =>
      _proSubscriptionProvider;
  bool get isProSubscriptionActive =>
      _proSubscriptionProvider.isProSubscriptionActive;

  // Streak settings provider access
  StreakSettingsProvider get streakSettingsProvider => _streakSettingsProvider;
  bool get isActiveDaysStreakEnabled =>
      _streakSettingsProvider.isActiveDaysStreakEnabled;
  String get streakCalculationMode =>
      _streakSettingsProvider.streakCalculationMode;

  // Date provider access
  DateProvider get dateProvider => _dateProvider;
  DateTime get currentDate => _dateProvider.currentDate;
  bool get isVirtualMode => _dateProvider.isVirtualMode;
  bool get isDateOverridden => _dateProvider.isDateOverridden;
  DateTime? get virtualDate => _dateProvider.virtualDate;

  // Time provider access
  VirtualTimeService get virtualTimeService => _virtualTimeService;
  TimeOfDay get currentTime => _virtualTimeService.currentTime;
  bool get isTimeOverridden => _virtualTimeService.isTimeOverridden;
  TimeOfDay? get virtualTime => _virtualTimeService.virtualTime;

  // Settings access
  bool _showTimeOverride = false;
  bool get showTimeOverride => _showTimeOverride;

  bool _weekStartsOnMonday = true; // Default: Monday
  bool get weekStartsOnMonday => _weekStartsOnMonday;

  // Combined loading state
  bool get isLoading =>
      _habitProvider.isLoading || _notificationProvider.isLoading;

  // Combined error state
  String? get error => _habitProvider.error ?? _notificationProvider.error;

  // Initialization state tracking
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// Force set initialization state (for emergency bypass)
  void setInitialized(bool value) {
    _isInitialized = value;
    notifyListeners();
  }

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
      debugPrint(
        '🚀 Starting optimized app initialization with shorter timeouts...',
      );

      // PHASE 1: Initialize core services (habits + theme) with shorter timeouts
      debugPrint('📱 Phase 1: Initializing core services (habits + theme)...');

      // Initialize habit provider with reduced timeout
      await _habitProvider.initialize().timeout(
        const Duration(seconds: 8), // Reduced from 15 seconds
        onTimeout: () {
          debugPrint(
            '⚠️ Habit provider initialization timed out - continuing with empty state',
          );
          throw TimeoutException(
            'Habit provider initialization timed out',
            const Duration(seconds: 8),
          );
        },
      );

      // Load theme with shorter timeout
      await _themeProvider.loadThemeMode().timeout(
        const Duration(seconds: 3), // Reduced from 5 seconds
        onTimeout: () {
          debugPrint('⚠️ Theme loading timed out - using default theme');
          throw TimeoutException(
            'Theme loading timed out',
            const Duration(seconds: 3),
          );
        },
      );

      debugPrint('✅ Phase 1 complete: Habits and theme loaded');

      // PHASE 2: Initialize secondary services in parallel with shorter timeout
      debugPrint('🔧 Phase 2: Initializing secondary services...');

      try {
        await Future.wait([
          _notificationProvider.initialize(),
          _proSubscriptionProvider.loadProSubscriptionSetting(),
          _streakSettingsProvider.loadStreakSetting(),
          loadTimeOverrideSetting(),
          loadWeekStartDaySetting(),
          _dateProvider.initialize(), // Initialize DateProvider (no longer needs settings repo)
        ]).timeout(
          const Duration(seconds: 8), // Reduced from 15 seconds
          onTimeout: () {
            debugPrint(
              '⚠️ Secondary services initialization timed out - continuing with core functionality',
            );
            return <void>[];
          },
        );

        debugPrint('✅ Phase 2 complete: Secondary services loaded');
      } catch (e) {
        debugPrint('⚠️ Secondary services failed to load: $e');
        debugPrint('🔄 Continuing with core functionality only');
        // Don't rethrow - continue with core services
      }

      debugPrint('✅ App initialization completed successfully');
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ App state initialization failed: $e');

      // Log specific error types for better debugging
      if (e is TimeoutException) {
        debugPrint(
          '⏰ Initialization timeout detected - services may be slow to respond',
        );
        debugPrint(
          '💡 This often happens after the app has been backgrounded for extended periods',
        );
      } else if (e.toString().contains('database')) {
        debugPrint('🗄️ Database-related error during initialization');
        debugPrint('💡 Database may be locked or corrupted');
      } else if (e.toString().contains('permission')) {
        debugPrint('🔐 Permission-related error during initialization');
        debugPrint('💡 App may need to request permissions again');
      } else if (e.toString().contains('network')) {
        debugPrint('🌐 Network-related error during initialization');
        debugPrint('💡 Check network connectivity');
      }

      _isInitialized = false;
      notifyListeners();

      // Don't rethrow - let app continue with minimal state
      debugPrint('🔄 App will continue with minimal functionality');
    }
  }

  /// Clear all errors
  void clearErrors() {
    _habitProvider.clearError();
    _notificationProvider.clearError();
  }

  /// Load time override setting from storage
  Future<void> loadTimeOverrideSetting() async {
    try {
      _showTimeOverride = await _settingsRepository.getShowTimeOverride();
      debugPrint('🕐 Loaded time override setting: $_showTimeOverride');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading time override setting: $e');
      _showTimeOverride = false; // Default to false on error
    }
  }

  /// Save time override setting to storage
  Future<void> saveTimeOverrideSetting(bool show) async {
    try {
      await _settingsRepository.saveShowTimeOverride(show);
      _showTimeOverride = show;
      debugPrint('🕐 Saved time override setting: $show');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving time override setting: $e');
    }
  }

  /// Load week start day setting from storage
  Future<void> loadWeekStartDaySetting() async {
    try {
      _weekStartsOnMonday = await _settingsRepository.getWeekStartDay();
      debugPrint('📅 Loaded week start day setting: ${_weekStartsOnMonday ? "Monday" : "Sunday"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading week start day setting: $e');
      _weekStartsOnMonday = true; // Default to Monday on error
    }
  }

  /// Save week start day setting to storage
  Future<void> saveWeekStartDaySetting(bool isMonday) async {
    try {
      await _settingsRepository.saveWeekStartDay(isMonday);
      _weekStartsOnMonday = isMonday;
      debugPrint('📅 Saved week start day setting: ${isMonday ? "Monday" : "Sunday"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving week start day setting: $e');
    }
  }

  /// Toggle PRO subscription with error handling and rollback
  /// 
  /// This method provides optimistic UI updates with automatic rollback
  /// if the database operation fails. It includes proper error handling
  /// and user feedback mechanisms.
  Future<bool> toggleProSubscription() async {
    try {
      // Store original state for potential rollback
      final originalState = _proSubscriptionProvider.isProSubscriptionActive;
      final newState = !originalState;
      
      debugPrint('💎 PRO subscription toggle: $originalState → $newState');
      
      // Optimistic UI update - update provider state immediately
      _proSubscriptionProvider.setProSubscriptionActive(newState);
      notifyListeners(); // Direct notification to bypass _smartCacheNotify
      
      // Attempt to save to storage
      final success = await _settingsRepository.saveSetting(
        'pro_subscription', 
        newState.toString()
      );
      
      if (success) {
        debugPrint('💎 PRO subscription toggle successful: $newState');
        return true;
      } else {
        // ROLLBACK: Restore original state
        debugPrint('❌ PRO subscription save failed, rolling back to: $originalState');
        _proSubscriptionProvider.setProSubscriptionActive(originalState);
        notifyListeners();
        return false;
      }
    } catch (e) {
      // ROLLBACK: Restore original state on any error
      final originalState = _proSubscriptionProvider.isProSubscriptionActive;
      debugPrint('❌ PRO subscription toggle error: $e, rolling back to: $originalState');
      _proSubscriptionProvider.setProSubscriptionActive(originalState);
      notifyListeners();
      return false;
    }
  }


  /// Toggle streak calculation mode with error handling and rollback
  /// 
  /// This method provides optimistic UI updates with automatic rollback
  /// if the database operation fails. It includes proper error handling
  /// and user feedback mechanisms.
  Future<bool> toggleStreakCalculation() async {
    try {
      // Store original state for potential rollback
      final originalState = _streakSettingsProvider.isActiveDaysStreakEnabled;
      final newState = !originalState;
      
      debugPrint('🔥 Streak calculation toggle: $originalState → $newState');
      
      // Optimistic UI update - update provider state immediately
      _streakSettingsProvider.setStreakCalculationState(newState);
      notifyListeners(); // Direct notification to bypass _smartCacheNotify
      
      // Attempt to save to storage
      final success = await _settingsRepository.saveSetting(
        'active_days_streak_enabled', 
        newState.toString()
      );
      
      if (success) {
        debugPrint('🔥 Streak calculation toggle successful: $newState');
        return true;
      } else {
        // ROLLBACK: Restore original state
        debugPrint('❌ Streak calculation save failed, rolling back to: $originalState');
        _streakSettingsProvider.setStreakCalculationState(originalState);
        notifyListeners();
        return false;
      }
    } catch (e) {
      // ROLLBACK: Restore original state on any error
      final originalState = _streakSettingsProvider.isActiveDaysStreakEnabled;
      debugPrint('❌ Streak calculation toggle error: $e, rolling back to: $originalState');
      _streakSettingsProvider.setStreakCalculationState(originalState);
      notifyListeners();
      return false;
    }
  }

  /// Set time override
  void setTimeOverride(TimeOfDay time) {
    _virtualTimeService.setTimeOverride(time);
    notifyListeners();
  }

  /// Reset time override to system time
  void resetTimeOverride() {
    _virtualTimeService.resetToSystemTime();
    notifyListeners();
  }

  /// Reset date override to today's date
  Future<void> resetDateOverride() async {
    await _dateProvider.resetToSystemDate();
    // No need to notifyListeners here as DateProvider will notify its listeners
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
  /// - **Cache Management**: Only updates persistent cache if NOT in date override mode
  ///
  /// ## Use Cases:
  /// - App lifecycle events (resume, foreground)
  /// - Manual refresh requests from UI
  /// - Data synchronization after external changes
  /// - Recovery from error states
  Future<void> refreshAllData({bool forceRefresh = false}) async {
    // Only update persistent cache if NOT in date override mode
    if (!isDateOverridden) {
      // Normal refresh with cache updates
      await _habitProvider.loadHabitsForDashboard(forceRefresh: forceRefresh);
    } else {
      // Silent refresh without cache updates
      await _habitProvider.refreshDataSilently();
    }
  }

  /// Refresh all data without updating persistent cache
  ///
  /// This method refreshes data from the database but does not update the
  /// persistent cache. Used when in date override mode to avoid cache pollution.
  ///
  /// ## Parameters:
  /// - [forceRefresh]: If true, bypasses freshness checks and forces refresh
  Future<void> refreshAllDataSilently({bool forceRefresh = false}) async {
    // Refresh all providers but skip persistent cache updates
    await _habitProvider.refreshDataSilently();
    // Don't update persistent cache
  }

  @override
  void dispose() {
    // Cancel any pending debounce timer
    _notificationDebounce?.cancel();
    
    _habitProvider.removeListener(notifyListeners);
    _notificationProvider.removeListener(notifyListeners);
    _themeProvider.removeListener(notifyListeners);
    _proSubscriptionProvider.removeListener(notifyListeners);
    _streakSettingsProvider.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Provider for AppState
class AppStateProvider extends AppState {
  AppStateProvider(
    super.habitProvider,
    super.notificationProvider,
    super.themeProvider,
    super.proSubscriptionProvider,
    super.streakSettingsProvider,
    super.dateProvider,
    super.settingsRepository,
  );

  // Factory method for easy creation with SQLite repository
  factory AppStateProvider.create() {
    final databaseService = DatabaseService();
    final habitProvider = HabitProvider.create();
    final notificationService = NotificationService();
    final notificationProvider = NotificationProvider(notificationService);
    final settingsRepository = SettingsRepository(databaseService);
    final themeProvider = ThemeProvider(settingsRepository);
    final proSubscriptionProvider = ProSubscriptionProvider(settingsRepository);
    final streakSettingsProvider = StreakSettingsProvider(settingsRepository);
    final dateProvider = DateProvider();

    return AppStateProvider(
      habitProvider,
      notificationProvider,
      themeProvider,
      proSubscriptionProvider,
      streakSettingsProvider,
      dateProvider,
      settingsRepository,
    );
  }

  static Future<AppStateProvider> preload() async {
    final appStateProvider = AppStateProvider.create();
    await appStateProvider.preloadCore();
    return appStateProvider;
  }

  Future<void> preloadCore() async {
    try {
      await _habitProvider.initialize();
      await _themeProvider.loadThemeMode();
      await loadTimeOverrideSetting();
      await loadWeekStartDaySetting();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Core preload failed: $e');
      _isInitialized = false;
      notifyListeners();
      // Don't rethrow - let app continue with minimal state
    }
  }
}
