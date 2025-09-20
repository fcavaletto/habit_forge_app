import 'package:flutter/material.dart';
import 'dart:async';
import '../models/habit.dart';
import '../models/habit_result.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/database_service.dart';
import '../utils/data_freshness.dart';

/// State class to hold habit-related data and operations
class HabitState extends ChangeNotifier {
  final SqliteHabitRepository _habitRepository;

  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;

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
    if (!forceRefresh && isDataFresh) {
      debugPrint('📱 HabitProvider: Data is fresh, skipping reload');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 HabitProvider: Loading habits from storage...');
      _habits = await _habitRepository.getActiveHabits();
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
}
