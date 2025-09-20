import 'package:flutter/material.dart';
import 'dart:async';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/database_service.dart';
import '../utils/data_freshness.dart';

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

  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;
  bool _isSortingMode = false;
  int _reorderCount = 0; // Track reorder operations for normalization
  DateTime _selectedDate = DateTime.now(); // Selected date for filtering

  HabitState(this._habitRepository);

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
  
  /// Get habits filtered for the currently selected date
  List<Habit> get filteredHabits => getHabitsForDate(_selectedDate);

  /// Get habits filtered by completion status for a specific date
  List<Habit> getHabitsForDate(DateTime date) {
    return _habits.where((habit) => _isHabitActiveOnDate(habit, date)).toList();
  }

  /// Get habit IDs that should be visible based on current filter
  List<String> getVisibleHabitIds() {
    return getHabitsForDate(_selectedDate).map((h) => h.id).toList();
  }

  /// Update the selected date for filtering
  void updateSelectedDate(DateTime newDate) {
    _selectedDate = newDate;
    debugPrint('📅 Selected date updated to: ${_selectedDate.toIso8601String().split('T')[0]}');
    notifyListeners();
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
      await _habitRepository.updateHabitCompletion(habitId, date, count);
      
      // Update local state directly instead of reloading all habits
      final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);
      if (habitIndex >= 0) {
        final updatedHabit = _habits[habitIndex].markCompleted(date, count);
        _habits[habitIndex] = updatedHabit;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update habit completion: $e';
      notifyListeners();
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
    final today = DateTime.now();
    return _habits.where((habit) => habit.isGoalAchieved(today)).length;
  }

  /// Get total completion percentage for today across all habits
  double getTodayCompletionRate() {
    if (_habits.isEmpty) return 0.0;
    
    double totalCompletionPercentage = 0.0;
    final today = DateTime.now();
    
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

  HabitProvider(super.habitRepository) : _repository = habitRepository;

  // Factory method for easy creation with SQLite repository
  factory HabitProvider.create() {
    final databaseService = DatabaseService();
    final sqliteRepository = SqliteHabitRepository(databaseService);
    return HabitProvider(sqliteRepository);
  }
  
  // Initialize the provider
  Future<void> initialize() async {
    // Initialize database
    final databaseService = DatabaseService();
    await databaseService.database;
    debugPrint('✅ Database initialized');
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
}
