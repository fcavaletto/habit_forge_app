import 'package:flutter/material.dart';
import 'dart:async';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/database_service.dart';
import '../services/virtual_date_service.dart';
import '../utils/data_freshness.dart';
import '../utils/timezone_utils.dart';

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

  HabitState(this._habitRepository, this._settingsRepository) {
    _initializeTimezoneHandling();
  }
  
  /// Initialize timezone handling for the app
  Future<void> _initializeTimezoneHandling() async {
    try {
      // Check if we have legacy data (local timezone) or new data (UTC)
      final db = await databaseService.database;
      final metadataRows = await db.query(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['timestamp_format'],
      );
      
      if (metadataRows.isNotEmpty) {
        final format = metadataRows.first['value'] as String;
        final isLegacy = format == 'legacy_local';
        TimezoneUtils.setLegacyDataMode(isLegacy);
        debugPrint('🌍 Timezone handling initialized: ${isLegacy ? "Legacy (local)" : "New (UTC)"}');
      } else {
        // No metadata found, assume legacy data for backward compatibility
        TimezoneUtils.setLegacyDataMode(true);
        debugPrint('🌍 Timezone handling initialized: Legacy (local) - no metadata found');
      }
    } catch (e) {
      // If metadata table doesn't exist yet, assume legacy data
      TimezoneUtils.setLegacyDataMode(true);
      debugPrint('🌍 Timezone handling initialized: Legacy (local) - metadata table not found');
    }
  }

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
        notifyListeners();
      }
      return result;
    } catch (e) {
      return HabitSaveResult.error('Failed to add habit: $e');
    }
  }

  /// Update habit completion count
  Future<void> updateHabitCompletion(String habitId, DateTime date, int count) async {
    try {
      // Get current habit to check existing completion count
      final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
      if (habitIndex < 0) {
        debugPrint('❌ Habit not found: $habitId');
        return;
      }
      
      final habit = _habits[habitIndex];
      final currentCount = habit.getCompletionCount(date);
      
      // Calculate the difference and apply changes incrementally
      final difference = count - currentCount;
      
      if (difference > 0) {
        // Add completions
        for (int i = 0; i < difference; i++) {
          await _habitRepository.addHabitCompletion(habitId, date);
        }
      } else if (difference < 0) {
        // Remove completions
        for (int i = 0; i < -difference; i++) {
          await _habitRepository.removeHabitCompletion(habitId, date);
        }
      }
      
      // Update local state by reloading the habit from database
      final updatedHabit = await _habitRepository.getHabitById(habitId);
      if (updatedHabit != null) {
        _habits[habitIndex] = updatedHabit;
        notifyListeners();
        debugPrint('✅ Updated habit completion: $habitId on ${date.toIso8601String().split('T')[0]} = $count');
      }
    } catch (e) {
      _error = 'Failed to update habit completion: $e';
      notifyListeners();
      debugPrint('❌ Error updating habit completion: $e');
    }
  }

  /// Load hourly completion data for histogram analysis
  ///
  /// @param habitId The ID of the habit to analyze
  /// @param timeRange The time range for analysis ("Last 7 Days", "Last 30 Days", "Total")
  /// @param currentDate The current virtual date for calculations
  /// @return HourlyHistogramData with completion distribution
  Future<HourlyHistogramData> loadHourlyData(String habitId, String timeRange, DateTime currentDate) async {
    try {
      Map<int, int> hourlyCompletions;
      DateTime startDate;
      DateTime endDate = currentDate;
      
      switch (timeRange) {
        case 'Last 7 Days':
          // Include today + 6 previous days = 7 days total
          startDate = currentDate.subtract(const Duration(days: 6));
          endDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59); // End of today
          hourlyCompletions = await _habitRepository.getHourlyCompletions(habitId, startDate, endDate);
          break;
        case 'Last 30 Days':
          // Include today + 29 previous days = 30 days total
          startDate = currentDate.subtract(const Duration(days: 29));
          endDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 23, 59, 59); // End of today
          hourlyCompletions = await _habitRepository.getHourlyCompletions(habitId, startDate, endDate);
          break;
        case 'Total':
          startDate = DateTime(2020); // Arbitrary early date
          hourlyCompletions = await _habitRepository.getAllTimeHourlyCompletions(habitId);
          break;
        default:
          throw ArgumentError('Invalid time range: $timeRange');
      }
      
      final totalCompletions = hourlyCompletions.values.fold(0, (sum, count) => sum + count);
      
      final data = HourlyHistogramData(
        hourlyCompletions: hourlyCompletions,
        totalCompletions: totalCompletions,
        startDate: startDate,
        endDate: endDate,
        timeRange: timeRange,
      );
      
      debugPrint('📊 Loaded hourly data for $habitId: $totalCompletions total completions across ${data.activeHours.length} hours');
      debugPrint('📅 Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      return data;
    } catch (e) {
      debugPrint('❌ Error loading hourly data: $e');
      rethrow;
    }
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
    // Initialize database
    final databaseService = DatabaseService();
    await databaseService.database;
    debugPrint('✅ Database initialized');
    
    // Load habit filter setting FIRST
    await loadHabitFilterSetting();
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

  /// Enhanced unarchive with bottom positioning
  @override
  Future<bool> unarchiveHabit(String habitId) async {
    try {
      final success = await _habitRepository.unarchiveHabit(habitId);
      if (success) {
        // Reload habits to get unarchived habit at bottom
        await loadHabits(forceRefresh: true);
        debugPrint('✅ Unarchived habit $habitId and positioned at bottom');
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
