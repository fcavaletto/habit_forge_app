import 'package:flutter/material.dart';
import 'dart:async';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/database_service.dart';
import '../services/virtual_date_service.dart';
import '../services/completion_cache_service.dart';
import '../services/habit_metadata_cache_service.dart';
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
  final CompletionCacheService _completionCache = CompletionCacheService();
  final HabitMetadataCacheService _metadataCache = HabitMetadataCacheService();

  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;
  bool _isSortingMode = false;
  int _reorderCount = 0; // Track reorder operations for normalization
  DateTime _selectedDate = DateTime.now(); // Selected date for filtering
  TimeOfDay _selectedTime = TimeOfDay.now(); // Selected time for completion timestamps
  bool _showAllHabits = false; // Whether to show all habits or just today's habits

  HabitState(this._habitRepository, this._settingsRepository);

  // Getters
  List<Habit> get habits => _habits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastLoadTime => _lastLoadTime;
  bool get isDataFresh => _lastLoadTime != null && 
    !DataFreshness.isDataStale(_lastLoadTime!);
  bool get needsRefresh => _lastLoadTime == null ||
    DataFreshness.shouldRefreshOnResume(_lastLoadTime!);
  bool get isSortingMode => _isSortingMode;
  DateTime get selectedDate => _selectedDate;
  TimeOfDay get selectedTime => _selectedTime;
  bool get isShowingAllHabits => _showAllHabits;
  
  /// Get habits filtered based on current filter mode (all habits or date-filtered)
  List<Habit> get filteredHabits => _showAllHabits ? _habits : getHabitsForDate(_selectedDate);

  /// Get habits filtered by completion status for a specific date
  List<Habit> getHabitsForDate(DateTime date) {
    return _habits.where((habit) => _isHabitActiveOnDate(habit, date)).toList();
  }

  /// Get habit IDs that should be visible based on current filter
  List<String> getVisibleHabitIds() {
    return getHabitsForDate(_selectedDate).map((h) => h.id).toList();
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

  /// Load all active habits
  Future<void> loadHabits({bool forceRefresh = false}) async {
    // Debounce rapid refresh calls
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performLoad(forceRefresh);
    });
  }

  /// Internal method to perform the actual load operation
  Future<void> _performLoad(bool forceRefresh) async {
    // Skip reload if data is fresh and not forcing refresh
    // This prevents unnecessary database queries and improves performance
    if (!forceRefresh && isDataFresh) {
      debugPrint('📱 HabitProvider: Data is fresh, skipping reload');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 HabitProvider: Loading habits from storage...');
      // Fetch fresh data from repository layer
      _habits = await _habitRepository.getActiveHabits();
      
      // Warm cache with completion data for current date
      await _warmCompletionCache();
      
      // Warm cache with metadata for all habits
      await _warmMetadataCache();
      
      // Update timestamp for freshness tracking
      _lastLoadTime = DateTime.now();

      _isLoading = false;
      notifyListeners();
      debugPrint('📱 HabitProvider: Loaded ${_habits.length} habits at $_lastLoadTime');
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load habits: $e';
      notifyListeners();
      debugPrint('❌ HabitProvider: Failed to load habits: $e');
    }
  }

  /// Add a new habit
  Future<HabitSaveResult> addHabit(Habit habit) async {
    try {
      final result = await _habitRepository.saveHabit(habit);
      if (result.success && result.savedHabit != null) {
        // Add to local state directly
        _habits.insert(0, result.savedHabit!); // Add at the beginning
        
        // Cache the new habit metadata
        final metadata = HabitMetadata.fromHabit(result.savedHabit!);
        _metadataCache.cacheHabitMetadata(result.savedHabit!.id, metadata);
        
        notifyListeners();
      }
      return result;
    } catch (e) {
      return HabitSaveResult.error('Failed to add habit: $e');
    }
  }

  /// Update habit completion count with optimistic UI updates
  /// 
  /// This method updates the UI immediately (optimistic) and then syncs
  /// to the database in the background. If the database sync fails,
  /// the UI will be rolled back to the previous state.
  Future<void> updateHabitCompletion(String habitId, DateTime date, int count) async {
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
        debugPrint('📝 No change needed for habit $habitId on ${date.toIso8601String().split('T')[0]}');
        return;
      }
      
      // OPTIMISTIC UI UPDATE: Update UI immediately
      final optimisticHabit = originalHabit.markCompleted(date, count);
      _habits[habitIndex] = optimisticHabit;
      notifyListeners(); // Instant UI update
      
      debugPrint('⚡ Optimistic update: $habitId on ${date.toIso8601String().split('T')[0]} = $count');
      
      // BACKGROUND DATABASE SYNC: Perform database operations in background
      _syncCompletionToDatabase(habitId, date, count, originalHabit, habitIndex);
      
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
  Future<void> _syncCompletionToDatabase(
    String habitId, 
    DateTime date, 
    int count, 
    Habit originalHabit, 
    int habitIndex
  ) async {
    try {
      final currentCount = originalHabit.getCompletionCount(date);
      final difference = count - currentCount;
      
      if (difference > 0) {
        // Add completions using batch operation
        await _habitRepository.addMultipleCompletions(habitId, date, difference);
        // Invalidate cache for this habit and date
        _completionCache.invalidateCompletion(habitId, date);
      } else if (difference < 0) {
        // Remove completions
        for (int i = 0; i < -difference; i++) {
          await _habitRepository.removeHabitCompletion(habitId, date);
        }
        // Invalidate cache for this habit and date
        _completionCache.invalidateCompletion(habitId, date);
      }
      
      debugPrint('✅ Database sync successful: $habitId on ${date.toIso8601String().split('T')[0]} = $count');
    } catch (e) {
      debugPrint('❌ Database sync failed for $habitId: $e');
      _rollbackOptimisticUpdate(habitId, originalHabit, habitIndex);
    }
  }
  
  /// Rollback optimistic UI update when database sync fails
  /// 
  /// This method reverts the UI changes if the database operation failed.
  void _rollbackOptimisticUpdate(String habitId, Habit originalHabit, int habitIndex) {
    try {
      _habits[habitIndex] = originalHabit;
        notifyListeners();
      _error = 'Failed to sync completion to database. Changes have been reverted.';
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
        debugPrint('📝 No completions to reset for habit $habitId on ${date.toIso8601String().split('T')[0]}');
        return;
      }
      
      // OPTIMISTIC UI UPDATE: Update UI immediately
      final optimisticHabit = originalHabit.markCompleted(date, 0);
      _habits[habitIndex] = optimisticHabit;
      notifyListeners(); // Instant UI update
      
      debugPrint('⚡ Optimistic reset: $habitId on ${date.toIso8601String().split('T')[0]} = 0');
      
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
  Future<void> setCustomCompletionCount(String habitId, DateTime date, int newCount) async {
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
        debugPrint('📝 Completion count already set to $newCount for habit $habitId on ${date.toIso8601String().split('T')[0]}');
        return;
      }
      
      // OPTIMISTIC UI UPDATE: Update UI immediately
      final optimisticHabit = originalHabit.markCompleted(date, newCount);
      _habits[habitIndex] = optimisticHabit;
      notifyListeners(); // Instant UI update
      
      debugPrint('⚡ Optimistic custom completion: $habitId on ${date.toIso8601String().split('T')[0]} = $newCount');
      
      // BACKGROUND DATABASE SYNC: Perform database operations in background
      _syncCustomCompletionToDatabase(habitId, date, newCount, originalHabit, habitIndex);
      
    } catch (e) {
      _error = 'Failed to set custom completion count: $e';
      notifyListeners();
      debugPrint('❌ Error setting custom completion count: $e');
    }
  }
  
  /// Sync custom completion operation to database in background
  Future<void> _syncCustomCompletionToDatabase(
    String habitId, 
    DateTime date, 
    int newCount,
    Habit originalHabit, 
    int habitIndex
  ) async {
    try {
      final currentCount = originalHabit.getCompletionCount(date);
      
      if (newCount > currentCount) {
        // INCREASE: Add additional completions while preserving existing timestamps
        final additionalCount = newCount - currentCount;
        await _habitRepository.addAdditionalCompletions(habitId, date, additionalCount);
        debugPrint('📈 Incremental increase: Added $additionalCount completions ($currentCount → $newCount)');
      } else if (newCount < currentCount) {
        // DECREASE: Remove newest completions while preserving older timestamps
        final countToRemove = currentCount - newCount;
        await _habitRepository.removeOldestCompletions(habitId, date, countToRemove);
        debugPrint('📉 Incremental decrease: Removed $countToRemove newest completions ($currentCount → $newCount)');
      }
      // If newCount == currentCount, no database operation needed
      
      // Invalidate cache for this habit and date
      _completionCache.invalidateCompletion(habitId, date);
      
      debugPrint('✅ Database custom completion successful: $habitId on ${date.toIso8601String().split('T')[0]} = $newCount');
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
    int habitIndex
  ) async {
    try {
      await _habitRepository.removeAllCompletionsForDate(habitId, date);
      
      // Invalidate cache for this habit and date
      _completionCache.invalidateCompletion(habitId, date);
      
      debugPrint('✅ Database reset successful: $habitId on ${date.toIso8601String().split('T')[0]}');
    } catch (e) {
      debugPrint('❌ Database reset failed for $habitId: $e');
      _rollbackOptimisticUpdate(habitId, originalHabit, habitIndex);
    }
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
    debugPrint('📅 Cache miss - loading completion count from database for habit $habitId on ${date.toIso8601String().split('T')[0]}');
    
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
      debugPrint('🔥 Warming completion cache for ${_habits.length} habits on ${currentDate.toIso8601String().split('T')[0]}');
      
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
    debugPrint('📅 Metadata cache miss - loading habit metadata from database for habit $habitId');
    
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
      
      debugPrint('🔥 Metadata cache warmed with ${_habits.length} habit metadata entries');
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
      'totalCacheSize': (completionStats['cacheSize'] as int) + (metadataStats['cacheSize'] as int),
      'totalCacheHits': (completionStats['cacheHits'] as int) + (metadataStats['cacheHits'] as int),
      'totalCacheMisses': (completionStats['cacheMisses'] as int) + (metadataStats['cacheMisses'] as int),
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
  Future<HourlyHistogramData> loadHourlyData(String habitId, String timeRange, DateTime currentDate) async {
    return await PerformanceMonitor.monitorOperation(
      'loadHourlyData($timeRange)',
      () async {
        try {
          // Always use virtual date service for consistency
          final virtualDate = VirtualDateService().currentDate;
          debugPrint('📅 [HabitProvider] Loading hourly data for $timeRange using virtual date: ${virtualDate.toIso8601String()}');
          
          Map<int, int> hourlyCompletions;
          DateRange dateRange;
          
          switch (timeRange) {
            case 'Last 7 Days':
              dateRange = DateRangeUtils.getLast7Days(virtualDate);
              DateRangeUtils.validateDateRange(dateRange.start, dateRange.end);
              hourlyCompletions = await _habitRepository.getHourlyCompletions(habitId, dateRange.start, dateRange.end);
              break;
            case 'Last 30 Days':
              dateRange = DateRangeUtils.getLast30Days(virtualDate);
              DateRangeUtils.validateDateRange(dateRange.start, dateRange.end);
              hourlyCompletions = await _habitRepository.getHourlyCompletions(habitId, dateRange.start, dateRange.end);
              break;
        case 'Total':
          dateRange = DateRangeUtils.getTotal(virtualDate);
          hourlyCompletions = await _habitRepository.getTotalHourlyCompletions(habitId);
          break;
            default:
              throw ArgumentError('Invalid time range: $timeRange');
          }
          
          final totalCompletions = hourlyCompletions.values.fold(0, (sum, count) => sum + count);
          
          final data = HourlyHistogramData(
            hourlyCompletions: hourlyCompletions,
            totalCompletions: totalCompletions,
            startDate: dateRange.start,
            endDate: dateRange.end,
            timeRange: timeRange,
          );
          
          debugPrint('📊 [HabitProvider] Loaded hourly data for $habitId: $totalCompletions total completions across ${data.activeHours.length} hours');
          return data;
        } catch (e) {
          debugPrint('❌ [HabitProvider] Error loading hourly data: $e');
          rethrow;
        }
      },
    );
  }

  /// Archive a habit
  Future<bool> archiveHabit(String habitId) async {
    try {
      final success = await _habitRepository.archiveHabit(habitId);
      if (success) {
        // Update local state directly
        final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
        if (habitIndex >= 0) {
          _habits.removeAt(habitIndex); // Remove from active habits list
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = 'Failed to archive habit: $e';
      notifyListeners();
      return false;
    }
  }

  /// Unarchive a habit
  Future<bool> unarchiveHabit(String habitId) async {
    try {
      final success = await _habitRepository.unarchiveHabit(habitId);
      if (success) {
        // Reload habits to get the unarchived habit back
        await loadHabits();
      }
      return success;
    } catch (e) {
      _error = 'Failed to unarchive habit: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a habit
  Future<void> deleteHabit(String habitId) async {
    try {
      await _habitRepository.deleteHabit(habitId);
      // Update local state directly
      _habits.removeWhere((habit) => habit.id == habitId);
      
      // Invalidate metadata cache for deleted habit
      _metadataCache.invalidateHabit(habitId);
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete habit: $e';
      notifyListeners();
    }
  }

  /// Overwrite archived habit
  Future<HabitSaveResult> overwriteArchivedHabit(String archivedHabitId, Habit newHabit) async {
    try {
      final result = await _habitRepository.overwriteArchivedHabit(archivedHabitId, newHabit);
      if (result.success && result.savedHabit != null) {
        // Add the unarchived habit to local state
        _habits.insert(0, result.savedHabit!);
        
        // Cache the new habit metadata
        final metadata = HabitMetadata.fromHabit(result.savedHabit!);
        _metadataCache.cacheHabitMetadata(result.savedHabit!.id, metadata);
        
        notifyListeners();
      }
      return result;
    } catch (e) {
      return HabitSaveResult.error('Failed to overwrite archived habit: $e');
    }
  }

  /// Get habits that need attention
  Future<List<Habit>> getHabitsNeedingAttention() async {
    try {
      return await _habitRepository.getHabitsNeedingAttention();
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
  Future<bool> hasDuplicateHabit(String name, String iconName, {String? excludeHabitId}) async {
    try {
      return await _habitRepository.hasDuplicateHabit(name, iconName, excludeHabitId: excludeHabitId);
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
  Future<bool> canUpdateHabit(String habitId, String newName, String newIconName) async {
    try {
      return await _habitRepository.canUpdateHabit(habitId, newName, newIconName);
    } catch (e) {
      debugPrint('❌ Error checking if habit can be updated: $e');
      return false; // Fail safe - prevent update if check fails
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

  /// Get completed habits count for today (habits that achieved their goal)
  int getCompletedTodayCount() {
    final today = VirtualDateService().currentDate;
    return _habits.where((habit) => habit.isGoalAchieved(today)).length;
  }

  /// Get total completion percentage for today across all habits
  double getTodayCompletionRate() {
    if (_habits.isEmpty) return 0.0;
    
    double totalCompletionPercentage = 0.0;
    final today = VirtualDateService().currentDate;
    
    for (final habit in _habits) {
      final count = habit.getCompletionCount(today);
      final percentage = (count / habit.targetGoal).clamp(0.0, 1.0);
      totalCompletionPercentage += percentage;
    }
    
    return totalCompletionPercentage / _habits.length;
  }
}

/// Provider for HabitState
class HabitProvider extends HabitState {
  final SqliteHabitRepository _repository;

  HabitProvider(super.habitRepository, super.settingsRepository) : _repository = habitRepository;

  // Factory method for easy creation with SQLite repository
  factory HabitProvider.create() {
    final databaseService = DatabaseService();
    final sqliteRepository = SqliteHabitRepository(databaseService);
    final settingsRepository = SettingsRepository(databaseService);
    return HabitProvider(sqliteRepository, settingsRepository);
  }
  
  // Initialize the provider
  Future<void> initialize() async {
    debugPrint('🗄️ Initializing database...');
    final databaseService = DatabaseService();
    await databaseService.database; // Pre-open database
    debugPrint('✅ Database initialized');

    await loadHabitFilterSetting();

    debugPrint('📱 HabitProvider: Loading habits during initialization...');
    await _performLoad(false);
    debugPrint('✅ HabitProvider: Initialization complete with ${_habits.length} habits');
  }

  // Getter to access repository for complex operations
  SqliteHabitRepository get repository => _repository;

  // Override notifyListeners to add debouncing for performance
  @override
  void notifyListeners() {
    // Only notify if we have actual listeners to prevent unnecessary work
    if (hasListeners) {
      debugPrint('🔔 HabitProvider notifying listeners');
      super.notifyListeners();
    } else {
      debugPrint('🚫 HabitProvider has no listeners, skipping notification');
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
      
      debugPrint('🔄 Optimistically reordered habit $draggedId to position $newPosition');
      notifyListeners();

      // Perform actual reordering in database
      await _habitRepository.reorderHabits(draggedId, newPosition);
      debugPrint('✅ Successfully reordered habit $draggedId in database');
      
      // Increment reorder counter and normalize if needed
      _reorderCount++;
      if (_reorderCount >= 10) { // Normalize every 10 reorders
        debugPrint('🔄 Normalizing order values after $_reorderCount reorders');
        await _habitRepository.normalizeOrderValues();
        _reorderCount = 0;
        // Reload habits to get normalized order values
        await loadHabits(forceRefresh: true);
      }
    } catch (e) {
      // Rollback on error - reload habits from database
      debugPrint('❌ Error reordering habits: $e');
      await loadHabits(forceRefresh: true);
      _error = 'Failed to reorder habits: $e';
      notifyListeners();
    }
  }

  /// Reorder habits with filtering context - handles filtered views correctly
  Future<void> reorderHabitsInContext(
    String draggedId, 
    int newPosition, 
    List<String> visibleHabitIds
  ) async {
    try {
      debugPrint('🔄 Reordering habit $draggedId to position $newPosition in filtered context');
      
      // Optimistic update - move habit in local list immediately
      final draggedHabit = _habits.firstWhere((h) => h.id == draggedId);
      _habits.removeWhere((h) => h.id == draggedId);
      _habits.insert(newPosition, draggedHabit);
      
      debugPrint('🔄 Optimistically reordered habit $draggedId to position $newPosition in context');
      notifyListeners();

      // Perform actual reordering in database with context
      await _habitRepository.reorderHabitsInContext(draggedId, newPosition, visibleHabitIds);
      debugPrint('✅ Successfully reordered habit $draggedId in database with context');
      
      // Increment reorder counter and normalize if needed
      _reorderCount++;
      if (_reorderCount >= 10) { // Normalize every 10 reorders
        debugPrint('🔄 Normalizing order values after $_reorderCount reorders');
        await _habitRepository.normalizeOrderValues();
        _reorderCount = 0;
        // Reload habits to get normalized order values
        await loadHabits(forceRefresh: true);
      }
    } catch (e) {
      // Rollback on error - reload habits from database
      debugPrint('❌ Error reordering habits in context: $e');
      await loadHabits(forceRefresh: true);
      _error = 'Failed to reorder habits: $e';
      notifyListeners();
    }
  }

  /// Enhanced unarchive with top positioning
  @override
  Future<bool> unarchiveHabit(String habitId) async {
    try {
      final success = await _habitRepository.unarchiveHabit(habitId);
      if (success) {
        // Reload habits to get unarchived habit at top
        await loadHabits(forceRefresh: true);
        debugPrint('✅ Unarchived habit $habitId and positioned at top');
      }
      return success;
    } catch (e) {
      _error = 'Failed to unarchive habit: $e';
      notifyListeners();
      debugPrint('❌ Error unarchiving habit: $e');
      return false;
    }
  }

  /// Update the selected date for filtering
  void updateSelectedDate(DateTime newDate) {
    if (_selectedDate != newDate) {
      _selectedDate = newDate;
      
      // Update the virtual date service to make this the "current date" for the entire app
      VirtualDateService().setVirtualDate(newDate);
      
      notifyListeners();
      debugPrint('📅 Selected date updated to: ${_formatDate(newDate)}');
    }
  }

  /// Update the selected time for completion timestamps
  void updateSelectedTime(TimeOfDay newTime) {
    if (_selectedTime != newTime) {
      _selectedTime = newTime;
      notifyListeners();
      debugPrint('🕐 Selected time updated to: ${_formatTime(newTime)}');
    }
  }

  /// Set whether to show all habits or just today's habits
  void setShowAllHabits(bool showAll) {
    if (_showAllHabits != showAll) {
      _showAllHabits = showAll;
      notifyListeners();
      debugPrint('🔄 Habit filter changed to: ${showAll ? 'All Habits' : 'Today\'s Habits'}');
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
      debugPrint('📊 Habit filter setting loaded: ${_showAllHabits ? 'All Habits' : 'Today\'s Habits'}');
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
      final success = await _settingsRepository.saveSetting('habit_filter_mode', settingValue);

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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  /// Format time for display in 24-hour format
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
