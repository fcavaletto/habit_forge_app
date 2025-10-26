import 'package:flutter/material.dart';
import 'dart:async';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/database_service.dart';
import '../services/virtual_date_service.dart';
import '../services/virtual_time_service.dart';
import '../services/completion_cache_service.dart';
import '../services/habit_metadata_cache_service.dart';
import '../services/persistent_cache_service.dart';
import '../services/data_access_service.dart';
import '../services/atomic_data_service.dart';
import '../services/sample_data_generator_service.dart';
import '../services/service_factory.dart';
import '../utils/data_freshness.dart';
import '../utils/date_range_utils.dart';
import '../utils/performance_monitor.dart';

/// State management class for habit-related data and operations
///
/// This class implements the Provider pattern for state management, providing
/// a reactive data layer for habit operations. It manages local state caching,
/// data persistence, and UI notifications through the ChangeNotifier pattern.
///
/// ## Architecture Pattern:
/// - **Provider Pattern**: Implements reactive state management
/// - **Repository Pattern**: Delegates data operations to repository layer
/// - **Observer Pattern**: Notifies UI components of state changes
/// - **Singleton Pattern**: Ensures single instance per app lifecycle
///
/// ## Key Responsibilities:
/// - **State Management**: Maintains local habit data and loading states
/// - **Data Persistence**: Handles CRUD operations through repository
/// - **Performance Optimization**: Implements caching and debouncing
/// - **Error Handling**: Manages and reports operation errors
/// - **UI Integration**: Notifies listeners of state changes
///
/// ## Data Flow:
/// 1. **UI Request**: Controller calls provider method
/// 2. **State Update**: Provider updates loading state
/// 3. **Repository Call**: Data operation delegated to repository
/// 4. **State Update**: Provider updates data and loading state
/// 5. **UI Notification**: Listeners notified of changes
///
/// ## Performance Features:
/// - **Smart Caching**: Avoids unnecessary data reloads
/// - **Debounced Operations**: Prevents rapid successive calls
/// - **Timestamp Tracking**: Monitors data freshness
/// - **Selective Updates**: Only notifies when listeners exist
///
/// ## Error Handling Strategy:
/// - **Graceful Degradation**: Continues operation on non-critical errors
/// - **User Feedback**: Provides meaningful error messages
/// - **Logging**: Comprehensive debug logging for troubleshooting
/// - **Recovery**: Automatic retry mechanisms where appropriate
class HabitState extends ChangeNotifier {
  final SqliteHabitRepository _habitRepository;
  final SettingsRepository _settingsRepository;
  late final DataAccessService _dataAccessService;
  final CompletionCacheService _completionCache = CompletionCacheService();
  final HabitMetadataCacheService _metadataCache = HabitMetadataCacheService();
  final PersistentCacheService _persistentCache = PersistentCacheService();

  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;
  bool _isSortingMode = false;
  int _reorderCount = 0; // Track reorder operations for normalization
  late DateTime _selectedDate; // Selected date for filtering
  late TimeOfDay _selectedTime; // Selected time for completion timestamps
  bool _showAllHabits =
      false; // Whether to show all habits or just today's habits
  bool _loadedFromCache = false; // Track if last load was from cache (to skip redundant refresh)

  HabitState(this._habitRepository, this._settingsRepository) {
    // Initialize DataAccessService with repository and cache
    _dataAccessService = DataAccessService(
      repository: _habitRepository,
      cache: _persistentCache,
    );
    
    // Initialize with current date and time from global providers
    _selectedDate = VirtualDateService().currentDate;
    _selectedTime = VirtualTimeService().currentTime;
  }

  // Getters
  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastLoadTime => _lastLoadTime;
  DataAccessService get dataAccessService => _dataAccessService;
  bool get isDataFresh =>
      _lastLoadTime != null && !DataFreshness.isDataStale(_lastLoadTime!);
  bool get needsRefresh =>
      _lastLoadTime == null ||
      DataFreshness.shouldRefreshOnResume(_lastLoadTime!);
  bool get isSortingMode => _isSortingMode;
  bool get loadedFromCache => _loadedFromCache;
  DateTime get selectedDate => _selectedDate;
  TimeOfDay get selectedTime => _selectedTime;
  bool get isShowingAllHabits => _showAllHabits;

  /// Get habits filtered based on current filter mode (all habits or date-filtered)
  List<Habit> get filteredHabits =>
      _showAllHabits ? _habits : getHabitsForDate(_selectedDate);

  /// Get habits filtered by completion status for a specific date
  List<Habit> getHabitsForDate(DateTime date) {
    return _habits.where((habit) => _isHabitActiveOnDate(habit, date)).toList();
  }

  /// Get habit IDs that should be visible based on current filter
  List<String> getVisibleHabitIds() {
    return getHabitsForDate(_selectedDate).map((h) => h.id).toList();
  }

  /// Get last 30 days completion data for all habits
  /// 
  /// Extracts the last 30 days of completion data from dashboard habits.
  /// This data is already loaded by the dashboard and can be reused by stats screen.
  Map<String, Map<DateTime, CompletionRecord>> getLast30DaysCompletions() {
    final result = <String, Map<DateTime, CompletionRecord>>{};
    
    for (final habit in _habits) {
      // Extract last 30 days from habit.completions
      final last30Days = _extractLast30DaysFromCompletions(habit.completions);
      result[habit.id] = last30Days;
    }
    
    return result;
  }

  /// Extract last 30 days of completion data from habit completions
  /// 
  /// Filters completion records to include only the last 30 days relative to current date.
  Map<DateTime, CompletionRecord> _extractLast30DaysFromCompletions(
    Map<DateTime, CompletionRecord> completions
  ) {
    final today = VirtualDateService().currentDate;
    final last30Days = today.subtract(const Duration(days: 29));
    
    return Map.fromEntries(
      completions.entries.where((entry) {
        final date = entry.key;
        return date.isAfter(last30Days.subtract(const Duration(days: 1))) &&
               date.isBefore(today.add(const Duration(days: 1)));
      })
    );
  }

  /// Invalidate cached data when date override changes
  /// 
  /// This ensures that stats screen gets fresh data when the user changes
  /// the date through the central date provider.
  void invalidateCachedData() {
    debugPrint('🗑️ Invalidating cached data due to date override change');
    // The cached data will be regenerated on next access via getLast30DaysCompletions()
    // This is handled by the fact that we extract data from current _habits state
  }

  /// Get day abbreviation from DateTime (mon, tue, wed, etc.)
  String _getDayAbbreviation(DateTime date) {
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return days[date.weekday - 1]; // Monday = 1, Sunday = 7
  }

  /// Check if a habit is active on a specific date based on its frequency
  bool _isHabitActiveOnDate(Habit habit, DateTime date) {
    final dayAbbr = _getDayAbbreviation(date);
    return habit.frequencyDays[dayAbbr] == 1;
  }

  /// Load habits optimized for dashboard display (last 30 days only)
  Future<void> loadHabitsForDashboard({bool forceRefresh = false}) async {
    // Debounce rapid refresh calls
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performDashboardLoad(forceRefresh);
    });
  }

  /// Refresh data from database silently without showing loading UI
  ///
  /// This method updates data from the database in the background without
  /// setting loading states. The UI remains responsive and doesn't show
  /// loading spinners. Used for background refresh after cache preload.
  Future<void> refreshDataSilently() async {
    try {
      debugPrint('🔄 Silently refreshing data from database...');
      
      // Load fresh data using DataPreparationService (NO _isLoading = true)
      final result = await ServiceFactory.dashboardDataService.getDashboardHabits(
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'silentRefresh',
        ),
      );
      
      if (result.success && result.data != null) {
        // Update local state silently
        _habits = result.data!;
        _lastLoadTime = VirtualDateService().currentDate;
        
        // Update persistent cache with fresh data
        await _persistentCache.saveHabits(_habits);
        
        // Warm in-memory caches
        await _warmCompletionCache();
      await _warmMetadataCache();

        // Notify listeners of updated data (smooth transition, no loading state)
      notifyListeners();
        
        debugPrint('✅ Silent refresh completed with ${_habits.length} habits');
      } else {
        debugPrint('⚠️ Silent refresh failed: ${result.errorMessage}');
      }
    } catch (e) {
      debugPrint('❌ Silent refresh error: $e');
      // Don't throw - app continues with cached data
    }
  }

  /// Internal method to perform dashboard-optimized load operation
  Future<void> _performDashboardLoad(bool forceRefresh) async {
    // Skip reload if data is fresh and not forcing refresh
    if (!forceRefresh && isDataFresh) {
      debugPrint('📱 HabitProvider: Dashboard data is fresh, skipping reload');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 HabitProvider: Loading habits using DataPreparationService...');
      
      // Use DataPreparationService for optimized dashboard loading
      final result = await ServiceFactory.dashboardDataService.getDashboardHabits(
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'loadDashboardHabits',
        ),
      );
      
      if (!result.success || result.data == null) {
        throw Exception(result.errorMessage ?? 'Failed to load dashboard habits');
      }
      
      // Update local state with prepared data
      _habits = result.data!;  // Safe now - we checked for null above

      // Warm cache with completion data for current date
      await _warmCompletionCache();

      // Warm cache with metadata for all habits
      await _warmMetadataCache();

      // Update timestamp for freshness tracking
      _lastLoadTime = VirtualDateService().currentDate;

      _isLoading = false;
      notifyListeners();
      debugPrint(
        '✅ HabitProvider: Loaded ${_habits.length} habits for dashboard using DataPreparationService',
      );
    } catch (e) {
      _isLoading = false;
      
      // Check if this is a ServiceFactory initialization error - if so, fall back to old method temporarily
      if (e.toString().contains('Service Factory not initialized')) {
        debugPrint('⚠️ HabitProvider: ServiceFactory not ready, falling back to legacy load method');
        _error = null;  // Clear error since we're retrying with fallback
        
        try {
          // Fallback to dashboard loading method if ServiceFactory isn't ready yet
          await _performDashboardLoad(forceRefresh);
          return;
        } catch (fallbackError) {
          _error = 'Failed to load habits: $fallbackError';
          debugPrint('❌ HabitProvider: Fallback load also failed: $fallbackError');
        }
      } else {
      _error = 'Failed to load habits for dashboard: $e';
      }
      
      notifyListeners();
      debugPrint('❌ HabitProvider: Failed to load habits for dashboard: $e');
    }
  }

  /// Add a new habit with incremental update (no full reload)
  Future<HabitSaveResult> addHabit(Habit habit) async {
    try {
      debugPrint('🎯 [ADD_HABIT] Starting incremental habit creation');
      
      // Step 1: Convert Habit to HabitData for the atomic service
      final habitData = HabitData(
        name: habit.name,
        description: habit.description,
        lightColorValue: habit.lightColorValue,
        darkColorValue: habit.darkColorValue,
        iconName: habit.iconName,
        reminderTime: habit.reminderTime,
        enableReminders: habit.enableReminders,
        frequencyDays: habit.frequencyDays,
        targetGoal: habit.targetGoal,
        allowExceedGoal: habit.allowExceedGoal,
      );

      // Step 2: Create habit in database (atomic operation)
      final result = await _dataAccessService.atomicDataService.createHabit(
        habitData: habitData,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'addHabit',
          parameters: {'name': habit.name},
        ),
      );

      if (!result.success || result.data == null) {
        return HabitSaveResult.error(result.errorMessage ?? 'Unknown error');
      }
      
      final newHabit = result.data!;
      debugPrint('✅ [ADD_HABIT] Habit created in database: ${newHabit.id}');

      // Step 3: Add to local state (incremental - no reload)
      _habits.insert(0, newHabit);
      debugPrint('✅ [ADD_HABIT] Habit added to local state');

      // Step 4: Update cache using additive method (no clear!)
      final metadata = HabitMetadata.fromHabit(newHabit);
      await _dataAccessService.cache.addHabitToMetadata(newHabit.id, {
        'id': metadata.id,
        'name': metadata.name,
        'description': metadata.description,
        'lightColorValue': metadata.lightColorValue,
        'darkColorValue': metadata.darkColorValue,
        'iconName': metadata.iconName,
        'createdAt': metadata.createdAt.toIso8601String(),
        'reminderTime': metadata.reminderTime != null 
            ? '${metadata.reminderTime!.hour}:${metadata.reminderTime!.minute}'
            : null,
        'enableReminders': metadata.enableReminders,
        'isArchived': metadata.isArchived,
        'orderValue': metadata.orderValue,
        'frequencyDays': metadata.frequencyDays,
        'targetGoal': metadata.targetGoal,
        'allowExceedGoal': metadata.allowExceedGoal,
      });
      _metadataCache.cacheHabitMetadata(newHabit.id, metadata);
      debugPrint('✅ [ADD_HABIT] Habit added to cache (additive)');

      // Step 5: Load ONLY new habit's completions (last 30 days for dashboard)
      final today = VirtualDateService().currentDate;
      final last30Days = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 29));
      
      debugPrint('🔍 [ADD_HABIT] Loading completions for new habit only (last 30 days)');
      
      final completionResult = await _dataAccessService.atomicDataService.getCompletions(
        startDate: last30Days,
        endDate: today,
        habitIds: [newHabit.id], // ← ONLY the new habit!
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'loadNewHabitCompletions',
        ),
      );

      if (completionResult.success && completionResult.data != null) {
        final completions = completionResult.data![newHabit.id] ?? {};
        
        // Update habit with completion data
        final habitWithCompletions = newHabit.copyWith(completions: completions);
        _habits[0] = habitWithCompletions;
        
        // Cache completions in persistent cache
        for (final entry in completions.entries) {
          await _persistentCache.updateCompletion(
            newHabit.id,
            entry.key,
            entry.value.count,
          );
        }
        
        debugPrint('✅ [ADD_HABIT] Loaded ${completions.length} completion records for new habit');
      }

      // Step 6: Update persistent cache incrementally
      try {
        await _persistentCache.updateHabit(_habits[0]);
        debugPrint('✅ [ADD_HABIT] Persistent cache updated');
    } catch (e) {
        debugPrint('⚠️ [ADD_HABIT] Failed to update persistent cache: $e');
        // Non-fatal - app continues with in-memory data
      }

      // Step 7: Single notification (no cascade)
      notifyListeners();
      
      debugPrint('🎯 [ADD_HABIT] Completed successfully - NO full reload!');
      debugPrint('📊 [ADD_HABIT] Total habits in state: ${_habits.length}');
      
      return HabitSaveResult.success(_habits[0]);
      
    } catch (e, stackTrace) {
      debugPrint('❌ [ADD_HABIT] Failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return HabitSaveResult.error('Failed to add habit: $e');
    }
  }

  /// Update habit completion count with optimistic UI updates
  ///
  /// This method updates the UI immediately (optimistic) and then syncs
  /// to the database in the background. If the database sync fails,
  /// the UI will be rolled back to the previous state.
  Future<void> updateHabitCompletion(
    String habitId,
    DateTime date,
    int count,
  ) async {
    try {
      // Get current habit to check existing completion count
      final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
      if (habitIndex < 0) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }

      final originalHabit = _habits[habitIndex];
      final currentCount = originalHabit.getCompletionCount(date);

      // Calculate the difference
      final difference = count - currentCount;

      if (difference == 0) {
        debugPrint(
          '📝 No change needed for habit $habitId on ${date.toIso8601String().split('T')[0]}',
        );
        return;
      }

      // OPTIMISTIC UI UPDATE: Update UI immediately
      final optimisticHabit = originalHabit.markCompleted(date, count);
      _habits[habitIndex] = optimisticHabit;
      notifyListeners(); // Instant UI update

      debugPrint(
        '⚡ Optimistic update: $habitId on ${date.toIso8601String().split('T')[0]} = $count',
      );

      // BACKGROUND DATABASE SYNC: Perform database operations in background
      _syncCompletionToDatabase(
        habitId,
        date,
        count,
        originalHabit,
        habitIndex,
      );
    } catch (e) {
      _error = 'Failed to update habit completion: $e';
      notifyListeners();
      debugPrint('❌ Error updating habit completion: $e');
    }
  }

  /// Sync completion changes to database in background
  ///
  /// This method handles the actual database operations after the optimistic UI update.
  /// If the database operation fails, it will rollback the UI changes.
  /// 
  /// Behavior depends on allowExceedGoal flag:
  /// - allowExceedGoal = false: Simple increment/decrement with reset functionality
  /// - allowExceedGoal = true: Uses LIFO approach for timestamp management
  Future<void> _syncCompletionToDatabase(
    String habitId,
    DateTime date,
    int count,
    Habit originalHabit,
    int habitIndex,
  ) async {
    try {
      final currentCount = originalHabit.getCompletionCount(date);
      final difference = count - currentCount;

      if (difference == 0) {
        debugPrint('📝 No database sync needed - count unchanged');
        return;
      }

      if (difference > 0) {
        // Add completions using AtomicDataService
        await _dataAccessService.atomicDataService.addCompletions(
          habitId: habitId,
          date: date,
          count: difference,
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'addCompletions',
          ),
        );
        debugPrint(
          '📈 Added $difference completions for habit $habitId (${originalHabit.allowExceedGoal ? 'exceedable' : 'standard'})',
        );
      } else if (difference < 0) {
        // Remove completions using AtomicDataService
        final countToRemove = -difference;
        
        if (originalHabit.allowExceedGoal) {
          // For exceedable habits: Use LIFO approach (remove newest timestamps)
          await _dataAccessService.atomicDataService.removeCompletions(
            habitId: habitId,
            date: date,
            count: countToRemove,
            context: DataAccessContext(
              component: 'HabitProvider',
              operation: 'removeCompletions',
            ),
          );
          debugPrint(
            '📉 Removed $countToRemove newest completions for exceedable habit $habitId (LIFO)',
          );
        } else {
          // For standard habits: Reset all completions (remove all timestamps)
          await _dataAccessService.atomicDataService.removeCompletions(
            habitId: habitId,
            date: date,
            count: currentCount, // Remove all existing completions
            context: DataAccessContext(
              component: 'HabitProvider',
              operation: 'removeCompletions',
            ),
          );
          debugPrint(
            '🔄 Reset all $currentCount completions for standard habit $habitId (full reset)',
          );
        }
      }

      // Update persistent cache for this habit and date
      await _persistentCache.updateCompletion(habitId, date, count);

      debugPrint(
        '✅ Database sync successful: $habitId on ${date.toIso8601String().split('T')[0]} = $count',
      );
    } catch (e) {
      debugPrint('❌ Database sync failed for $habitId: $e');
      _rollbackOptimisticUpdate(habitId, originalHabit, habitIndex);
    }
  }

  /// Rollback optimistic UI update when database sync fails
  ///
  /// This method reverts the UI changes if the database operation failed.
  void _rollbackOptimisticUpdate(
    String habitId,
    Habit originalHabit,
    int habitIndex,
  ) {
    try {
      _habits[habitIndex] = originalHabit;
      notifyListeners();
      _error =
          'Failed to sync completion to database. Changes have been reverted.';
      debugPrint('🔄 Rolled back optimistic update for habit $habitId');
    } catch (e) {
      debugPrint('❌ Error during rollback for habit $habitId: $e');
    }
  }

  /// Reset all completions for a habit on a specific date with optimistic updates
  /// This completely removes all completion records for that day
  Future<void> resetAllCompletionsForDate(String habitId, DateTime date) async {
    try {
      // Get current habit to verify it exists
      final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
      if (habitIndex < 0) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }

      final originalHabit = _habits[habitIndex];
      final currentCount = originalHabit.getCompletionCount(date);

      if (currentCount == 0) {
        debugPrint(
          '📝 No completions to reset for habit $habitId on ${date.toIso8601String().split('T')[0]}',
        );
        return;
      }

      // OPTIMISTIC UI UPDATE: Update UI immediately
      final optimisticHabit = originalHabit.markCompleted(date, 0);
      _habits[habitIndex] = optimisticHabit;
      notifyListeners(); // Instant UI update

      debugPrint(
        '⚡ Optimistic reset: $habitId on ${date.toIso8601String().split('T')[0]} = 0',
      );

      // BACKGROUND DATABASE SYNC: Perform database operations in background
      _syncResetToDatabase(habitId, date, originalHabit, habitIndex);
    } catch (e) {
      _error = 'Failed to reset habit completions: $e';
      notifyListeners();
      debugPrint('❌ Error resetting habit completions: $e');
    }
  }

  /// Set custom completion count for a habit on a specific date
  /// This method allows setting an exact completion count (including values above goal)
  Future<void> setCustomCompletionCount(
    String habitId,
    DateTime date,
    int newCount,
  ) async {
    try {
      // Get current habit to verify it exists
      final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
      if (habitIndex < 0) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }

      final originalHabit = _habits[habitIndex];
      final currentCount = originalHabit.getCompletionCount(date);

      if (currentCount == newCount) {
        debugPrint(
          '📝 Completion count already set to $newCount for habit $habitId on ${date.toIso8601String().split('T')[0]}',
        );
        return;
      }

      // OPTIMISTIC UI UPDATE: Update UI immediately
      final optimisticHabit = originalHabit.markCompleted(date, newCount);
      _habits[habitIndex] = optimisticHabit;
      notifyListeners(); // Instant UI update

      debugPrint(
        '⚡ Optimistic custom completion: $habitId on ${date.toIso8601String().split('T')[0]} = $newCount',
      );

      // BACKGROUND DATABASE SYNC: Perform database operations in background
      _syncCustomCompletionToDatabase(
        habitId,
        date,
        newCount,
        originalHabit,
        habitIndex,
      );
    } catch (e) {
      _error = 'Failed to set custom completion count: $e';
      notifyListeners();
      debugPrint('❌ Error setting custom completion count: $e');
    }
  }

  /// Sync custom completion operation to database in background
  /// 
  /// This method handles custom completion counts for habits with allowExceedGoal = true.
  /// It uses LIFO approach for timestamp management (remove newest timestamps first).
  Future<void> _syncCustomCompletionToDatabase(
    String habitId,
    DateTime date,
    int newCount,
    Habit originalHabit,
    int habitIndex,
  ) async {
    try {
      final currentCount = originalHabit.getCompletionCount(date);

      if (newCount > currentCount) {
        // INCREASE: Add additional completions using AtomicDataService
        final additionalCount = newCount - currentCount;
        await _dataAccessService.atomicDataService.addCompletions(
          habitId: habitId,
          date: date,
          count: additionalCount,
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'addCompletions',
          ),
        );
        debugPrint(
          '📈 Custom completion increase: Added $additionalCount completions ($currentCount → $newCount)',
        );
      } else if (newCount < currentCount) {
        // DECREASE: Remove completions using LIFO approach (newest timestamps first)
        final countToRemove = currentCount - newCount;
        await _dataAccessService.atomicDataService.removeCompletions(
          habitId: habitId,
          date: date,
          count: countToRemove,
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'removeCompletions',
          ),
        );
        debugPrint(
          '📉 Custom completion decrease: Removed $countToRemove newest completions ($currentCount → $newCount)',
        );
      }
      // If newCount == currentCount, no database operation needed

      // Update persistent cache for this habit and date
      await _persistentCache.updateCompletion(habitId, date, newCount);

      debugPrint(
        '✅ Database custom completion successful: $habitId on ${date.toIso8601String().split('T')[0]} = $newCount',
      );
    } catch (e) {
      // ROLLBACK: Revert optimistic update on database failure
      _rollbackOptimisticUpdate(habitId, originalHabit, habitIndex);
      debugPrint('❌ Database custom completion failed, rolled back: $e');
    }
  }

  /// Sync reset operation to database in background
  Future<void> _syncResetToDatabase(
    String habitId,
    DateTime date,
    Habit originalHabit,
    int habitIndex,
  ) async {
    try {
      // Get current completion count to determine how many to remove
      final currentCount = originalHabit.getCompletionCount(date);
      
      if (currentCount <= 0) {
        debugPrint('📝 No completions to reset for habit $habitId on ${date.toIso8601String().split('T')[0]}');
        return;
      }

      // Remove all completions using AtomicDataService
      await _dataAccessService.atomicDataService.removeCompletions(
        habitId: habitId,
        date: date,
        count: currentCount, // Remove actual completion count
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'removeCompletions',
        ),
      );

      // Update persistent cache for this habit and date
      await _persistentCache.updateCompletion(habitId, date, 0);

      debugPrint(
        '✅ Database reset successful: $habitId on ${date.toIso8601String().split('T')[0]} (removed $currentCount completions)',
      );
    } catch (e) {
      debugPrint('❌ Database reset failed for $habitId: $e');
      _rollbackOptimisticUpdate(habitId, originalHabit, habitIndex);
    }
  }

  /// Get completion count synchronously from cache
  ///
  /// This method provides synchronous access to cached completion data.
  /// Returns null if not cached, allowing the caller to handle cache misses.
  int? getCachedCompletionCountSync(String habitId, DateTime date) {
    return _completionCache.getCompletionCount(habitId, date);
  }

  /// Get completion count with intelligent caching
  ///
  /// This method first checks the cache for completion data. If not found,
  /// it loads from the database and caches the result for future use.
  /// This dramatically reduces database queries for completion data.
  Future<int> getCachedCompletionCount(String habitId, DateTime date) async {
    // First, try to get from cache
    final cachedCount = _completionCache.getCompletionCount(habitId, date);
    if (cachedCount != null) {
      return cachedCount;
    }

    // Cache miss - load from database
    debugPrint(
      '📅 Cache miss - loading completion count from database for habit $habitId on ${date.toIso8601String().split('T')[0]}',
    );

    try {
      // Get the habit to access its completion data
      final habit = _habits.firstWhere((h) => h.id == habitId);
      final count = habit.getCompletionCount(date);

      // Cache the result for future use
      _completionCache.cacheCompletionCount(habitId, date, count);

      return count;
    } catch (e) {
      debugPrint('❌ Error getting cached completion count: $e');
      return 0;
    }
  }

  /// Warm completion cache with current date data
  ///
  /// This method pre-loads completion data for all habits on the current date
  /// to improve performance and reduce database queries.
  Future<void> _warmCompletionCache() async {
    try {
      final currentDate = _selectedDate;
      debugPrint(
        '🔥 Warming completion cache for ${_habits.length} habits on ${currentDate.toIso8601String().split('T')[0]}',
      );

      for (final habit in _habits) {
        final count = habit.getCompletionCount(currentDate);
        _completionCache.cacheCompletionCount(habit.id, currentDate, count);
      }

      debugPrint('🔥 Cache warmed with ${_habits.length} completion records');
    } catch (e) {
      debugPrint('❌ Error warming completion cache: $e');
    }
  }

  /// Get habit metadata with intelligent caching
  ///
  /// This method first checks the cache for habit metadata. If not found,
  /// it loads from the database and caches the result for future use.
  /// This dramatically reduces database queries for habit properties.
  Future<HabitMetadata?> getCachedHabitMetadata(String habitId) async {
    // First, try to get from cache
    final cachedMetadata = _metadataCache.getHabitMetadata(habitId);
    if (cachedMetadata != null) {
      return cachedMetadata;
    }

    // Cache miss - load from database
    debugPrint(
      '📅 Metadata cache miss - loading habit metadata from database for habit $habitId',
    );

    try {
      // Get the habit from local state (which should have all metadata)
      final habit = _habits.firstWhere((h) => h.id == habitId);
      final metadata = HabitMetadata.fromHabit(habit);

      // Cache the result for future use
      _metadataCache.cacheHabitMetadata(habitId, metadata);

      return metadata;
    } catch (e) {
      debugPrint('❌ Error getting cached habit metadata: $e');
      return null;
    }
  }

  /// Warm metadata cache with all habit metadata
  ///
  /// This method pre-loads metadata for all habits to improve performance
  /// and reduce database queries for habit properties.
  Future<void> _warmMetadataCache() async {
    try {
      debugPrint('🔥 Warming metadata cache for ${_habits.length} habits');

      await _metadataCache.warmCacheWithHabits(_habits);

      debugPrint(
        '🔥 Metadata cache warmed with ${_habits.length} habit metadata entries',
      );
    } catch (e) {
      debugPrint('❌ Error warming metadata cache: $e');
    }
  }

  /// Get completion cache statistics for monitoring
  Map<String, dynamic> getCompletionCacheStats() {
    return _completionCache.getCacheStats();
  }

  /// Get metadata cache statistics for monitoring
  Map<String, dynamic> getMetadataCacheStats() {
    return _metadataCache.getCacheStats();
  }

  /// Get combined cache statistics for monitoring
  Map<String, dynamic> getAllCacheStats() {
    final completionStats = _completionCache.getCacheStats();
    final metadataStats = _metadataCache.getCacheStats();

    return {
      'completionCache': completionStats,
      'metadataCache': metadataStats,
      'totalCacheSize':
          (completionStats['cacheSize'] as int) +
          (metadataStats['cacheSize'] as int),
      'totalCacheHits':
          (completionStats['cacheHits'] as int) +
          (metadataStats['cacheHits'] as int),
      'totalCacheMisses':
          (completionStats['cacheMisses'] as int) +
          (metadataStats['cacheMisses'] as int),
    };
  }

  /// Clear completion cache (useful for debugging or memory management)
  void clearCompletionCache() {
    _completionCache.clearCache();
    debugPrint('🗑️ Completion cache cleared');
  }

  /// Clear metadata cache (useful for debugging or memory management)
  void clearMetadataCache() {
    _metadataCache.clearCache();
    debugPrint('🗑️ Metadata cache cleared');
  }

  /// Clean up expired cache entries
  void cleanupExpiredCacheEntries() {
    _completionCache.cleanupExpiredEntries();
    _metadataCache.cleanupExpiredEntries();
  }

  /// Load hourly completion data for histogram analysis
  ///
  /// @param habitId The ID of the habit to analyze
  /// @param timeRange The time range for analysis ("Last 7 Days", "Last 30 Days", "Total")
  /// @param currentDate The current virtual date for calculations (deprecated - now uses VirtualDateService)
  /// @return HourlyHistogramData with completion distribution
  Future<HourlyHistogramData> loadHourlyData(
    String habitId,
    String timeRange,
    DateTime currentDate,
  ) async {
    return await PerformanceMonitor.monitorOperation(
      'loadHourlyData($timeRange)',
      () async {
        try {
          // Always use virtual date service for consistency
          final virtualDate = VirtualDateService().currentDate;
          debugPrint(
            '📅 [HabitProvider] Loading hourly data for $timeRange using virtual date: ${virtualDate.toIso8601String()}',
          );

          Map<int, int> hourlyCompletions;
          DateRange dateRange;

          switch (timeRange) {
            case 'Last 7 Days':
              dateRange = DateRangeUtils.getLast7Days(virtualDate);
              DateRangeUtils.validateDateRange(dateRange.start, dateRange.end);
              final result = await _dataAccessService.atomicDataService.getHourlyCompletions(
                habitId: habitId,
                startDate: dateRange.start,
                endDate: dateRange.end,
                context: DataAccessContext(
                  component: 'HabitProvider',
                  operation: 'loadHourlyData',
                  parameters: {'timeRange': timeRange, 'habitId': habitId},
                ),
              );
              
              if (result.success && result.data != null) {
                hourlyCompletions = result.data!;
              } else {
                debugPrint('❌ Failed to get hourly completions: ${result.errorMessage}');
                hourlyCompletions = <int, int>{};
              }
              break;
            case 'Last 30 Days':
              dateRange = DateRangeUtils.getLast30Days(virtualDate);
              DateRangeUtils.validateDateRange(dateRange.start, dateRange.end);
              final result = await _dataAccessService.atomicDataService.getHourlyCompletions(
                habitId: habitId,
                startDate: dateRange.start,
                endDate: dateRange.end,
                context: DataAccessContext(
                  component: 'HabitProvider',
                  operation: 'loadHourlyData',
                  parameters: {'timeRange': timeRange, 'habitId': habitId},
                ),
              );
              
              if (result.success && result.data != null) {
                hourlyCompletions = result.data!;
              } else {
                debugPrint('❌ Failed to get hourly completions: ${result.errorMessage}');
                hourlyCompletions = <int, int>{};
              }
              break;
            case 'Total':
              dateRange = DateRangeUtils.getTotal(virtualDate);
              DateRangeUtils.validateDateRange(dateRange.start, dateRange.end);
              final result = await _dataAccessService.atomicDataService.getHourlyCompletions(
                habitId: habitId,
                startDate: dateRange.start,
                endDate: dateRange.end,
                context: DataAccessContext(
                  component: 'HabitProvider',
                  operation: 'loadHourlyData',
                  parameters: {'timeRange': timeRange, 'habitId': habitId},
                ),
              );
              
              if (result.success && result.data != null) {
                hourlyCompletions = result.data!;
              } else {
                debugPrint('❌ Failed to get hourly completions: ${result.errorMessage}');
                hourlyCompletions = <int, int>{};
              }
              break;
            default:
              throw ArgumentError('Invalid time range: $timeRange');
          }

          final totalCompletions = hourlyCompletions.values.fold(
            0,
            (sum, count) => sum + count,
          );

          final data = HourlyHistogramData(
            hourlyCompletions: hourlyCompletions,
            totalCompletions: totalCompletions,
            startDate: dateRange.start,
            endDate: dateRange.end,
            timeRange: timeRange,
          );

          debugPrint(
            '📊 [HabitProvider] Loaded hourly data for $habitId: $totalCompletions total completions across ${data.activeHours.length} hours',
          );
          return data;
        } catch (e) {
          debugPrint('❌ [HabitProvider] Error loading hourly data: $e');
          rethrow;
        }
      },
    );
  }

  /// Archive a habit
  /// Archive a habit with optimistic UI update and rollback on failure
  Future<bool> archiveHabit(String habitId) async {
    debugPrint('🗄️ [ARCHIVE] Starting optimistic archive for habit $habitId');
    
    // Find habit in local state
    final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
    if (habitIndex < 0) {
      debugPrint('❌ [ARCHIVE] Habit not found: $habitId');
      return false;
    }
    
    final originalHabit = _habits[habitIndex];
    
    try {
      // OPTIMISTIC UPDATE: Remove from UI immediately
      _habits.removeAt(habitIndex);
      notifyListeners(); // Instant UI update
      
      debugPrint('⚡ [ARCHIVE] Optimistic update: Removed habit $habitId from UI');
      
      // BACKGROUND DATABASE SYNC: Archive in database
      final result = await _dataAccessService.atomicDataService.archiveHabit(
        habitId: habitId,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'archiveHabit',
        ),
      );

      if (result.success) {
        // Update cache using selective method (no full rebuild)
        await _dataAccessService.cache.removeHabitFromMetadata(habitId);
        
        // Update persistent cache (remove archived habit)
        try {
          await _persistentCache.removeHabit(habitId);
          debugPrint('✅ [ARCHIVE] Persistent cache updated');
        } catch (e) {
          debugPrint('⚠️ [ARCHIVE] Failed to update persistent cache: $e');
        }
        
        debugPrint('✅ [ARCHIVE] Database sync successful for habit $habitId');
        return true;
      } else {
        // ROLLBACK: Database operation failed, restore habit
        debugPrint('❌ [ARCHIVE] Database sync failed, rolling back');
        _habits.insert(habitIndex, originalHabit);
          notifyListeners();
        
        _error = 'Failed to archive habit: ${result.errorMessage}';
        return false;
      }

    } catch (e) {
      // ROLLBACK: Exception occurred, restore habit
      debugPrint('❌ [ARCHIVE] Exception occurred, rolling back: $e');
      _habits.insert(habitIndex, originalHabit);
      notifyListeners();
      
      _error = 'Failed to archive habit: $e';
      return false;
    }
  }

  /// Unarchive a habit with incremental update (no full reload)
  Future<bool> unarchiveHabit(String habitId) async {
    debugPrint('📤 [UNARCHIVE] Starting incremental unarchive for habit $habitId');
    
    try {
      // Step 1: Unarchive in database
      final result = await _dataAccessService.atomicDataService.unarchiveHabit(
        habitId: habitId,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'unarchiveHabit',
        ),
      );

      if (!result.success) {
        _error = 'Failed to unarchive habit: ${result.errorMessage}';
        notifyListeners();
        return false;
      }
      
      debugPrint('✅ [UNARCHIVE] Habit unarchived in database: $habitId');

      // Step 2: Fetch the unarchived habit's metadata
      final metadataResult = await _dataAccessService.atomicDataService.getHabitMetadata(
        habitIds: [habitId],
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'fetchUnarchivedHabitMetadata',
        ),
      );
      
      if (!metadataResult.success || metadataResult.data == null || metadataResult.data!.isEmpty) {
        _error = 'Failed to fetch unarchived habit metadata';
        notifyListeners();
        return false;
      }
      
      final habitMetadata = metadataResult.data!.first;

      // Step 3: Load completions for the unarchived habit (last 30 days)
      final today = VirtualDateService().currentDate;
      final last30Days = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 29));
      
      final completionResult = await _dataAccessService.atomicDataService.getCompletions(
        startDate: last30Days,
        endDate: today,
        habitIds: [habitId],
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'loadUnarchivedHabitCompletions',
        ),
      );

      Map<DateTime, CompletionRecord> completions = {};
      if (completionResult.success && completionResult.data != null) {
        completions = completionResult.data![habitId] ?? {};
      }
      
      // Build full habit with metadata + completions
      final habitWithCompletions = Habit(
        id: habitMetadata.id,
        name: habitMetadata.name,
        description: habitMetadata.description,
        lightColorValue: habitMetadata.lightColorValue,
        darkColorValue: habitMetadata.darkColorValue,
        createdAt: habitMetadata.createdAt,
        completions: completions,
        iconName: habitMetadata.iconName,
        reminderTime: habitMetadata.reminderTime,
        enableReminders: habitMetadata.enableReminders,
        isArchived: habitMetadata.isArchived,
        orderValue: habitMetadata.orderValue,
        frequencyDays: habitMetadata.frequencyDays,
        targetGoal: habitMetadata.targetGoal,
        allowExceedGoal: habitMetadata.allowExceedGoal,
      );
      
      // Step 4: Add to local state (incremental - no reload!)
      _habits.insert(0, habitWithCompletions);
      
      // Step 5: Update cache using additive method
      final metadata = HabitMetadata.fromHabit(habitWithCompletions);
      await _dataAccessService.cache.addHabitToMetadata(habitWithCompletions.id, {
        'id': metadata.id,
        'name': metadata.name,
        'description': metadata.description,
        'lightColorValue': metadata.lightColorValue,
        'darkColorValue': metadata.darkColorValue,
        'iconName': metadata.iconName,
        'createdAt': metadata.createdAt.toIso8601String(),
        'reminderTime': metadata.reminderTime != null 
            ? '${metadata.reminderTime!.hour}:${metadata.reminderTime!.minute}'
            : null,
        'enableReminders': metadata.enableReminders,
        'isArchived': metadata.isArchived,
        'orderValue': metadata.orderValue,
        'frequencyDays': metadata.frequencyDays,
        'targetGoal': metadata.targetGoal,
        'allowExceedGoal': metadata.allowExceedGoal,
      });
      _metadataCache.cacheHabitMetadata(habitWithCompletions.id, metadata);
      
      // Cache completions
      for (final entry in completions.entries) {
        await _dataAccessService.cache.cacheCompletion(
          habitWithCompletions.id,
          entry.key,
          entry.value.count,
        );
      }
      
      debugPrint('✅ [UNARCHIVE] Habit added to local state with ${completions.length} completions');

      // Step 6: Update persistent cache incrementally
      try {
        await _persistentCache.updateHabit(habitWithCompletions);
        debugPrint('✅ [UNARCHIVE] Persistent cache updated');
    } catch (e) {
        debugPrint('⚠️ [UNARCHIVE] Failed to update persistent cache: $e');
        // Non-fatal - app continues with in-memory data
      }

      // Step 7: Single notification
      notifyListeners();
      
      debugPrint('🎯 [UNARCHIVE] Completed successfully - NO full reload!');
      return true;
      
    } catch (e) {
      debugPrint('❌ [UNARCHIVE] Failed: $e');
      _error = 'Failed to unarchive habit: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a habit with optimistic UI update and rollback on failure
  Future<void> deleteHabit(String habitId) async {
    debugPrint('🗑️ [DELETE] Starting optimistic delete for habit $habitId');
    
    // Find habit in local state
    final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
    if (habitIndex < 0) {
      debugPrint('❌ [DELETE] Habit not found: $habitId');
      return;
    }
    
    final originalHabit = _habits[habitIndex];
    
    try {
      // OPTIMISTIC UPDATE: Remove from UI immediately
      _habits.removeAt(habitIndex);
      notifyListeners(); // Instant UI update
      
      debugPrint('⚡ [DELETE] Optimistic update: Removed habit $habitId from UI');
      
      // BACKGROUND DATABASE SYNC: Delete from database
      final result = await _dataAccessService.atomicDataService.deleteHabit(
        habitId: habitId,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'deleteHabit',
        ),
      );

      if (result.success) {
        // Update cache using selective method (remove specific habit)
        await _dataAccessService.cache.invalidateHabit(habitId);
        _metadataCache.invalidateHabit(habitId);

        // Update persistent cache (remove deleted habit)
        try {
          await _persistentCache.removeHabit(habitId);
          debugPrint('✅ [DELETE] Persistent cache updated');
        } catch (e) {
          debugPrint('⚠️ [DELETE] Failed to update persistent cache: $e');
        }
        
        debugPrint('✅ [DELETE] Database sync successful for habit $habitId');
      } else {
        // ROLLBACK: Database operation failed, restore habit
        debugPrint('❌ [DELETE] Database sync failed, rolling back');
        _habits.insert(habitIndex, originalHabit);
        notifyListeners();
        
        _error = 'Failed to delete habit: ${result.errorMessage}';
      }
      
    } catch (e) {
      // ROLLBACK: Exception occurred, restore habit
      debugPrint('❌ [DELETE] Exception occurred, rolling back: $e');
      _habits.insert(habitIndex, originalHabit);
      notifyListeners();
      
      _error = 'Failed to delete habit: $e';
    }
  }


  /// Get habits that need attention
  Future<List<Habit>> getHabitsNeedingAttention() async {
    try {
      final result = await _dataAccessService.atomicDataService.getHabitsNeedingAttention(
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'getHabitsNeedingAttention',
        ),
      );
      
      if (result.success && result.data != null) {
        return result.data!;
      } else {
        debugPrint('❌ Failed to get habits needing attention: ${result.errorMessage}');
        return [];
      }
    } catch (e) {
      _error = 'Failed to get habits needing attention: $e';
      notifyListeners();
      return [];
    }
  }

  /// Check if a habit with the same name and icon already exists
  ///
  /// This method provides duplicate detection for habit creation and editing.
  /// It checks against active (non-archived) habits only.
  ///
  /// @param name The habit name to check
  /// @param iconName The icon name to check
  /// @param excludeHabitId Optional habit ID to exclude from check (for editing)
  /// @return true if a duplicate exists, false otherwise
  Future<bool> hasDuplicateHabit(
    String name,
    String iconName, {
    String? excludeHabitId,
  }) async {
    try {
      final result = await _dataAccessService.atomicDataService.hasDuplicateHabit(
        name: name,
        iconName: iconName,
        excludeHabitId: excludeHabitId,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'hasDuplicateHabit',
          parameters: {'name': name, 'iconName': iconName},
        ),
      );
      
      if (result.success && result.data != null) {
        return result.data!;
      } else {
        debugPrint('❌ Failed to check for duplicate habit: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error checking for duplicate habit: $e');
      return false; // Fail safe - allow creation if check fails
    }
  }

  /// Check if a habit can be updated without creating duplicates
  ///
  /// This method is used when editing existing habits to ensure the new
  /// name/icon combination doesn't conflict with other active habits.
  ///
  /// @param habitId The ID of the habit being edited
  /// @param newName The new name for the habit
  /// @param newIconName The new icon name for the habit
  /// @return true if the update is safe (no duplicates), false otherwise
  Future<bool> canUpdateHabit(
    String habitId,
    String newName,
    String newIconName,
  ) async {
    try {
      final result = await _dataAccessService.atomicDataService.canUpdateHabit(
        habitId: habitId,
        newName: newName,
        newIconName: newIconName,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'canUpdateHabit',
          parameters: {'habitId': habitId, 'newName': newName, 'newIconName': newIconName},
        ),
      );
      
      if (result.success && result.data != null) {
        return result.data!;
      } else {
        debugPrint('❌ Failed to check if habit can be updated: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error checking if habit can be updated: $e');
      return false; // Fail safe - prevent update if check fails
    }
  }

  /// Import sample habits with historical data
  ///
  /// This method imports realistic sample habits with 2 years of completion data
  /// for testing and demonstration purposes.
  ///
  /// @param clearExisting Whether to clear existing habits before import
  /// @param numberOfHabits Number of sample habits to generate (always 3)
  /// @param onProgress Optional callback for progress tracking
  /// @return Number of habits successfully imported
  Future<int> importSampleHabits({
    bool clearExisting = false,
    int numberOfHabits = 3, // Always 3 specific habits
    Function(String habitName, double progress)? onProgress,
  }) async {
    try {
      debugPrint('📥 Starting sample habits import...');
      
      // Generate sample habits
      final sampleHabits = await SampleDataGeneratorService.generateSampleHabits(
        numberOfHabits: numberOfHabits,
        yearsOfData: 2,
        onProgress: onProgress,
      );
      
      debugPrint('🎲 Generated ${sampleHabits.length} sample habits');
      
      // Import habits using atomic service
      int importedCount;
      if (clearExisting) {
        final result = await _dataAccessService.atomicDataService.importSampleHabits(
          sampleHabits: sampleHabits,
          clearExisting: true,
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'importSampleHabits',
            parameters: {'clearExisting': true, 'count': sampleHabits.length},
          ),
        );
        
        if (result.success && result.data != null) {
          importedCount = result.data!;
      } else {
          debugPrint('❌ Failed to import sample habits: ${result.errorMessage}');
          importedCount = 0;
        }
      } else {
        final result = await _dataAccessService.atomicDataService.importSampleHabits(
          sampleHabits: sampleHabits,
          onProgress: (progress) {
            // Convert int progress to the expected format
            onProgress?.call('Importing habits', progress / 100.0);
          },
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'importSampleHabits',
            parameters: {'count': sampleHabits.length},
          ),
        );
        
        if (result.success && result.data != null) {
          importedCount = result.data!;
        } else {
          debugPrint('❌ Failed to import sample habits: ${result.errorMessage}');
          importedCount = 0;
        }
      }
      
      if (importedCount > 0) {
        // Reload habits to update local state
        await loadHabitsForDashboard(forceRefresh: true);
        
        // Get and log statistics
        final stats = SampleDataGeneratorService.getSampleDataStats(sampleHabits);
        debugPrint('📊 Sample data statistics: $stats');
      }
      
      debugPrint('✅ Sample habits import completed: $importedCount habits imported');
      return importedCount;
      
    } catch (e) {
      debugPrint('❌ Error importing sample habits: $e');
      _error = 'Failed to import sample habits: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Get habit by ID
  Habit? getHabitById(String id) {
    try {
      return _habits.firstWhere((habit) => habit.id == id);
    } catch (e) {
      return null;
    }
  }


  // NOTE: Old cache methods removed - now using additive cache updates
  // (_updateCacheAfterDatabaseOperation and _updateHabitInCache)
  // New approach: Use addHabitToMetadata, updateHabitInMetadata, removeHabitFromMetadata
  // for surgical cache updates instead of rebuilding entire cache

  /// Log cache errors with context for debugging
  /// 
  /// Provides comprehensive error logging for troubleshooting cache issues.
  void _logCacheError(String operation, dynamic error, {String? habitId}) {
    final timestamp = DateTime.now().toIso8601String();
    final context = habitId != null ? ' (Habit: $habitId)' : '';
    
    debugPrint('''
❌ CACHE ERROR LOG [$timestamp]
Operation: $operation$context
Error: $error
Habits Count: ${_habits.length}
Cache Service: ${_persistentCache.runtimeType}
    ''');
  }




  /// Get cache health statistics for monitoring
  /// 
  /// Provides comprehensive statistics about cache performance and health.
  Map<String, dynamic> getCacheHealthStats() {
    return {
      'habitsCount': _habits.length,
      'lastLoadTime': _lastLoadTime?.toIso8601String(),
      'isDataFresh': isDataFresh,
      'needsRefresh': needsRefresh,
      'cacheServiceType': _persistentCache.runtimeType.toString(),
      'hasValidCache': _persistentCache.hasValidCache(),
    };
  }

  /// Perform cache health check
  /// 
  /// This method performs a comprehensive health check of the cache system
  /// and reports any issues found.
  Future<Map<String, dynamic>> performCacheHealthCheck() async {
    final healthReport = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'overallHealth': 'healthy',
      'issues': <String>[],
      'recommendations': <String>[],
    };

    try {
      // Check if cache service is accessible
      if (!await _persistentCache.hasValidCache()) {
        healthReport['issues'].add('Cache service not accessible');
        healthReport['overallHealth'] = 'warning';
      }

      // Check data freshness
      if (!isDataFresh) {
        healthReport['issues'].add('Data is stale');
        healthReport['overallHealth'] = 'warning';
        healthReport['recommendations'].add('Refresh data from database');
      }

      // Check habits data integrity
      if (_habits.isEmpty) {
        healthReport['issues'].add('No habits data available');
        healthReport['overallHealth'] = 'warning';
        healthReport['recommendations'].add('Load habits from database');
      }

      debugPrint('🔍 Cache health check completed: ${healthReport['overallHealth']}');
      return healthReport;

    } catch (e) {
      healthReport['overallHealth'] = 'error';
      healthReport['issues'].add('Health check failed: $e');
      debugPrint('❌ Cache health check failed: $e');
      return healthReport;
    }
  }

  /// Recover from cache issues
  /// 
  /// This method attempts to recover from various cache issues and restore
  /// normal operation.
  Future<bool> recoverFromCacheIssues() async {
    try {
      debugPrint('🔄 Attempting cache recovery...');
      
      // Reload habits from database (loadHabits handles caching internally)
      await loadHabitsForDashboard(forceRefresh: true);
      
      debugPrint('✅ Cache recovery completed successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ Cache recovery failed: $e');
      _logCacheError('recoverFromCacheIssues', e);
      return false;
    }
  }
}

/// Provider for HabitState
class HabitProvider extends HabitState {
  final SqliteHabitRepository _repository;

  HabitProvider(super.habitRepository, super.settingsRepository)
      : _repository = habitRepository;

  // Factory method for easy creation with SQLite repository
  factory HabitProvider.create() {
    final databaseService = DatabaseService();
    final sqliteRepository = SqliteHabitRepository(databaseService);
    final settingsRepository = SettingsRepository(databaseService);
    return HabitProvider(sqliteRepository, settingsRepository);
  }

  // Initialize the provider with persistent cache and enhanced error handling
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Starting HabitProvider initialization with persistent cache...');

      // Initialize persistent cache service
      await _persistentCache.initialize();

      // Try to load from persistent cache first (fast path)
      if (await _persistentCache.hasValidCache()) {
        debugPrint('📱 Loading habits from persistent cache...');
        final cachedHabits = await _persistentCache.loadHabits();
        
        if (cachedHabits.isNotEmpty) {
          _habits = cachedHabits;
          _isLoading = false;
          _lastLoadTime = VirtualDateService().currentDate;
          _loadedFromCache = true; // Mark as loaded from cache
          notifyListeners();
          
          debugPrint('✅ Loaded ${_habits.length} habits from persistent cache');
          
          return;
        }
      }

      debugPrint('📱 No valid cache found, loading from database...');
      _loadedFromCache = false; // Mark as loaded from database

      // Initialize database with timeout and recovery
      final databaseService = DatabaseService();
      await databaseService.database.timeout(
        const Duration(seconds: 2), // Very short timeout
        onTimeout: () {
          debugPrint('⏰ Database initialization timed out after 2 seconds');
          throw TimeoutException(
            'Database initialization timed out',
            const Duration(seconds: 2),
          );
        },
      );

      debugPrint('✅ Database initialized successfully');

      // Load settings with timeout
      await loadHabitFilterSetting().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⚠️ Settings loading timed out - using defaults');
          // Don't throw - continue with default settings
        },
      );

      debugPrint('📱 HabitProvider: Loading habits from database...');

      // Load habits with timeout and recovery
      await _performLoadWithRecovery(false);

      // Save to persistent cache for next startup
      if (_habits.isNotEmpty) {
        try {
          await _persistentCache.saveDashboardHabits(_habits);
          debugPrint('✅ Saved ${_habits.length} dashboard-optimized habits to persistent cache');
        } catch (e) {
          debugPrint('⚠️ Failed to save habits to persistent cache: $e');
          // Don't fail initialization if cache save fails
        }
      }

      debugPrint(
        '✅ HabitProvider: Initialization complete with ${_habits.length} habits',
      );
    } catch (e) {
      debugPrint('❌ HabitProvider initialization failed: $e');

      // Enhanced error logging
      if (e is TimeoutException) {
        debugPrint('⏰ HabitProvider timeout - database may be slow to respond');
        debugPrint('💡 This often happens after app backgrounding');
      } else if (e.toString().contains('database')) {
        debugPrint('🗄️ Database error in HabitProvider');
        debugPrint('💡 Database may be corrupted or locked');
      }

      // Try to load from cache as fallback
      try {
        final cachedHabits = await _persistentCache.loadHabits();
        if (cachedHabits.isNotEmpty) {
          _habits = cachedHabits;
          _isLoading = false;
          _lastLoadTime = VirtualDateService().currentDate;
          notifyListeners();
          debugPrint('✅ Fallback: Loaded ${_habits.length} habits from cache');
          return;
        }
      } catch (cacheError) {
        debugPrint('❌ Cache fallback also failed: $cacheError');
      }

      // Don't rethrow - continue with empty state
      debugPrint('🔄 Continuing with empty habit list');
      
      // Ensure we have a valid state even if initialization fails
      _isLoading = false;
      _habits = [];
      notifyListeners();
    }
  }


  /// Performs habit loading with recovery mechanisms
  Future<void> _performLoadWithRecovery(bool showLoading) async {
    try {
      // Use new dashboard load method (last 30 days, optimized)
      await _performDashboardLoad(false);
    } catch (e) {
      debugPrint('❌ Habit loading failed: $e');

      // Try recovery mechanisms
      if (e.toString().contains('database') || e is TimeoutException) {
        debugPrint('🔄 Attempting habit loading recovery...');

        try {
          // Wait a bit and try again
          await Future.delayed(const Duration(milliseconds: 500));
          await _performDashboardLoad(false);
          debugPrint('✅ Habit loading recovery successful');
          return;
        } catch (recoveryError) {
          debugPrint('❌ Habit loading recovery failed: $recoveryError');
        }
      }

      // If all recovery attempts fail, continue with empty state
      debugPrint('🔄 Continuing with empty habit list after recovery failure');
      if (showLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Getter to access repository for complex operations
  SqliteHabitRepository get repository => _repository;

  // Override notifyListeners to add debouncing for performance
  @override
  void notifyListeners() {
    // Only notify if we have actual listeners to prevent unnecessary work
    if (hasListeners) {
      super.notifyListeners();
    }
  }


  /// Enter sorting mode for habit reordering
  void enterSortingMode() {
    _isSortingMode = true;
    debugPrint('🔄 Entered sorting mode');
    notifyListeners();
  }

  /// Exit sorting mode
  void exitSortingMode() {
    _isSortingMode = false;
    debugPrint('🔄 Exited sorting mode');
    notifyListeners();
  }

  /// Reorder habits with optimistic updates
  Future<void> reorderHabits(String draggedId, int newPosition) async {
    try {
      // Optimistic update - move habit in local list immediately
      final draggedHabit = _habits.firstWhere((h) => h.id == draggedId);
      _habits.removeWhere((h) => h.id == draggedId);
      _habits.insert(newPosition, draggedHabit);

      debugPrint(
        '🔄 Optimistically reordered habit $draggedId to position $newPosition',
      );
      notifyListeners();

      // Perform actual reordering in database using atomic service
      final result = await _dataAccessService.atomicDataService.reorderHabits(
        draggedId: draggedId,
        newPosition: newPosition,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'reorderHabits',
          parameters: {'draggedId': draggedId, 'newPosition': newPosition},
        ),
      );
      
      if (result.success) {
        debugPrint('✅ Successfully reordered habit $draggedId in database');
        
        // Update persistent cache with new order
        try {
          await _persistentCache.saveHabits(_habits);
          debugPrint('✅ Updated persistent cache with new habit order');
        } catch (e) {
          debugPrint('⚠️ Failed to update persistent cache: $e');
          // Non-fatal - app continues with correct in-memory order
        }
      } else {
        debugPrint('❌ Failed to reorder habit: ${result.errorMessage}');
        throw Exception('Failed to reorder habit: ${result.errorMessage}');
      }

      // Increment reorder counter and normalize if needed
      _reorderCount++;
      if (_reorderCount >= 10) {
        // Normalize every 10 reorders using atomic service
        debugPrint('🔄 Normalizing order values after $_reorderCount reorders');
        final result = await _dataAccessService.atomicDataService.normalizeOrderValues(
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'normalizeOrderValues',
            parameters: {'reorderCount': _reorderCount},
          ),
        );
        
        if (result.success) {
          debugPrint('✅ Successfully normalized order values');
        } else {
          debugPrint('❌ Failed to normalize order values: ${result.errorMessage}');
        }
        _reorderCount = 0;
        // Reload habits to get normalized order values
        await loadHabitsForDashboard(forceRefresh: true);
      }
    } catch (e) {
      // Rollback on error - reload habits from database
      debugPrint('❌ Error reordering habits: $e');
      await loadHabitsForDashboard(forceRefresh: true);
      _error = 'Failed to reorder habits: $e';
      notifyListeners();
    }
  }

  /// Reorder habits with filtering context - handles filtered views correctly
  Future<void> reorderHabitsInContext(
    String draggedId,
    int newPosition,
    List<String> visibleHabitIds,
  ) async {
    try {
      debugPrint(
        '🔄 Reordering habit $draggedId to position $newPosition in filtered context'
      );

      // Optimistic update - move habit in local list immediately
      final draggedHabit = _habits.firstWhere((h) => h.id == draggedId);
      _habits.removeWhere((h) => h.id == draggedId);
      _habits.insert(newPosition, draggedHabit);

      debugPrint(
        '🔄 Optimistically reordered habit $draggedId to position $newPosition in context'
      );
      notifyListeners();

      // Perform actual reordering in database with context using atomic service
      final result = await _dataAccessService.atomicDataService.reorderHabitsInContext(
        draggedId: draggedId,
        newPosition: newPosition,
        visibleHabitIds: visibleHabitIds,
        context: DataAccessContext(
          component: 'HabitProvider',
          operation: 'reorderHabitsInContext',
          parameters: {'draggedId': draggedId, 'newPosition': newPosition, 'visibleCount': visibleHabitIds.length},
        ),
      );
      
      if (result.success) {
        debugPrint('✅ Successfully reordered habit $draggedId in database with context');
        
        // NEW: Reload updated orderValues from DB for visible habits
        try {
          // Edge case: Skip if no visible habits
          if (visibleHabitIds.isEmpty) {
            debugPrint('📭 No visible habits to reload orderValues for');
          } else {
            final metadataResult = await _dataAccessService.atomicDataService.getHabitMetadata(
              habitIds: visibleHabitIds,
              includeArchived: false,
              context: DataAccessContext(
                component: 'HabitProvider',
                operation: 'reloadOrderValuesAfterReorder',
                parameters: {'visibleCount': visibleHabitIds.length},
              ),
            );

            if (metadataResult.success && metadataResult.data != null) {
              final updatedMetadata = metadataResult.data!;

              // Update local _habits with new orderValues
              for (final meta in updatedMetadata) {
                final habitIndex = _habits.indexWhere((h) => h.id == meta.id);
                if (habitIndex != -1) {
                  final updatedHabit = _habits[habitIndex].copyWith(
                    orderValue: meta.orderValue,
                  );
                  _habits[habitIndex] = updatedHabit;
                }
              }

              // Re-sort local list by updated orderValues (should match optimistic order)
              _habits.sort((a, b) => (b.orderValue ?? 0.0).compareTo(a.orderValue ?? 0.0));

              debugPrint('✅ Reloaded and applied orderValues for ${updatedMetadata.length} habits');
            } else {
              throw Exception('Failed to reload orderValues: ${metadataResult.errorMessage}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to reload orderValues from DB: $e');
          // Fallback: Locally calculate orderValues based on current _habits order
          final total = _habits.length;
          for (int i = 0; i < total; i++) {
            final newOrderValue = (total - i) * 1000.0;
            _habits[i] = _habits[i].copyWith(orderValue: newOrderValue);
          }
          debugPrint('🔄 Fallback: Locally calculated orderValues for $total habits');
        }
        
        // Update persistent cache with new order (now with synced orderValues)
        try {
          await _persistentCache.saveHabits(_habits);
          debugPrint('✅ Updated persistent cache with new habit order (context)');
        } catch (e) {
          debugPrint('⚠️ Failed to update persistent cache: $e');
          // Non-fatal - app continues with correct in-memory order
        }
      } else {
        debugPrint('❌ Failed to reorder habit: ${result.errorMessage}');
        throw Exception('Failed to reorder habit: ${result.errorMessage}');
      }

      // Increment reorder counter and normalize if needed
      _reorderCount++;
      if (_reorderCount >= 10) {
        // Normalize every 10 reorders using atomic service
        debugPrint('🔄 Normalizing order values after $_reorderCount reorders');
        final result = await _dataAccessService.atomicDataService.normalizeOrderValues(
          context: DataAccessContext(
            component: 'HabitProvider',
            operation: 'normalizeOrderValues',
            parameters: {'reorderCount': _reorderCount},
          ),
        );

        if (result.success) {
          debugPrint('✅ Successfully normalized order values');
        } else {
          debugPrint('❌ Failed to normalize order values: ${result.errorMessage}');
        }
        _reorderCount = 0;
        // Reload habits to get normalized order values (use dashboard-optimized loading)
        await loadHabitsForDashboard(forceRefresh: true);
      }
    } catch (e) {
      // Rollback on error - reload habits from database (use dashboard-optimized loading)
      debugPrint('❌ Error reordering habits in context: $e');
      await loadHabitsForDashboard(forceRefresh: true);
      _error = 'Failed to reorder habits: $e';
      notifyListeners();
    }
  }

  /// Update the selected date for filtering
  Future<void> updateSelectedDate(DateTime newDate) async {
    if (_selectedDate != newDate) {
      final wasInOverrideMode = VirtualDateService().isVirtualMode;
      
      debugPrint('🔍 Date transition debug:');
      debugPrint('  - Current _selectedDate: ${_formatDate(_selectedDate)}');
      debugPrint('  - New date: ${_formatDate(newDate)}');
      debugPrint('  - wasInOverrideMode: $wasInOverrideMode');
      
      // Update the virtual date service first
      await VirtualDateService().setVirtualDate(newDate);
      final isNowInOverrideMode = VirtualDateService().isVirtualMode;
      
      debugPrint('  - isNowInOverrideMode (after virtual date update): $isNowInOverrideMode');
      
      // NEW: Simple cache invalidation logic based on override mode changes
      if (!wasInOverrideMode && isNowInOverrideMode) {
        // Entering override mode - invalidate cache and reload data
        debugPrint('🗑️ Entering date override mode - invalidating persistent cache');
        try {
          await _persistentCache.invalidateAllCompletions();
          debugPrint('✅ Cleared persistent cache');
        } catch (e) {
          debugPrint('❌ Error invalidating cache: $e');
          // Continue operation even if cache invalidation fails
        }
        // CRITICAL: Reload habits from database with new virtual date
        debugPrint('🔄 Reloading habits from database for new virtual date');
        await refreshDataSilently();
      } else if (wasInOverrideMode && !isNowInOverrideMode) {
        // Exiting override mode - allow cache recreation
        debugPrint('🔄 Exiting date override mode - cache will be recreated on next interaction');
        // Don't recreate cache here - let Dashboard interactions handle it
      } else if (wasInOverrideMode && isNowInOverrideMode) {
        // Date changed within override mode - invalidate cached data and reload
        debugPrint('🗑️ Date changed within override mode - invalidating cached data');
        invalidateCachedData();
        // CRITICAL: Reload habits from database for new virtual date
        debugPrint('🔄 Reloading habits from database for new virtual date');
        await refreshDataSilently();
      }
      
      _selectedDate = newDate;

      notifyListeners();
      debugPrint('📅 Selected date updated to: ${_formatDate(newDate)}');
    }
  }

  /// Update the selected time for completion timestamps
  void updateSelectedTime(TimeOfDay newTime) {
    if (_selectedTime != newTime) {
      _selectedTime = newTime;
      // Also update the virtual time service
      VirtualTimeService().setTimeOverride(newTime);
      notifyListeners();
      debugPrint('🕐 Selected time updated to: ${_formatTime(newTime)}');
    }
  }

  /// Set whether to show all habits or just today's habits
  void setShowAllHabits(bool showAll) {
    if (_showAllHabits != showAll) {
      _showAllHabits = showAll;
      notifyListeners();
      debugPrint(
        '🔄 Habit filter changed to: ${showAll ? 'All Habits' : 'Today\'s Habits'}',
      );
      // Save the filter preference
      saveHabitFilterSetting();
    }
  }

  /// Load habit filter setting from storage
  Future<void> loadHabitFilterSetting() async {
    try {
      debugPrint('📊 Loading habit filter setting from storage...');
      final settingValue = await _settingsRepository.getSettingWithDefault(
        'habit_filter_mode',
        'today', // Default to Today's Habits
      );

      _showAllHabits = settingValue == 'all';
      debugPrint(
        '📊 Habit filter setting loaded: ${_showAllHabits ? 'All Habits' : 'Today\'s Habits'}',
      );
    } catch (e) {
      debugPrint('❌ Error loading habit filter setting: $e');
      // Fallback to default (Today's Habits)
      _showAllHabits = false;
    }
  }

  /// Save habit filter setting to storage
  Future<void> saveHabitFilterSetting() async {
    try {
      debugPrint('📊 Saving habit filter setting to storage...');
      final settingValue = _showAllHabits ? 'all' : 'today';
      final success = await _settingsRepository.saveSetting(
        'habit_filter_mode',
        settingValue,
      );

      if (success) {
        debugPrint('📊 Habit filter setting saved: $settingValue');
      } else {
        debugPrint('❌ Failed to save habit filter setting: $settingValue');
      }
    } catch (e) {
      debugPrint('❌ Error saving habit filter setting: $e');
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    // Simply show the actual date in a readable format
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  /// Format time for display in 24-hour format
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
