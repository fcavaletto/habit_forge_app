import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../providers/app_state_provider.dart';
import '../utils/data_freshness.dart';

/// Controller class that handles all business logic for the dashboard
///
/// This controller implements the MVC pattern by separating UI concerns from business logic,
/// providing better testability and maintainability. It manages the complete dashboard
/// workflow including data loading, habit operations, and lifecycle management.
///
/// ## Responsibilities:
/// - **Data Management**: Handles habit loading, refreshing, and caching
/// - **Lifecycle Management**: Manages app lifecycle events and data freshness
/// - **Habit Operations**: Processes habit completion, archiving, and deletion
/// - **Business Logic**: Implements habit statistics and progress calculations
/// - **Error Handling**: Manages errors and provides user feedback
/// - **Sample Data**: Handles sample habit creation and management
///
/// ## Key Features:
/// - **Smart Refresh**: Automatically refreshes data when stale or on new day
/// - **Performance Optimization**: Debounced refresh calls and caching
/// - **Statistics Calculation**: Computes completion rates and streaks
/// - **Notification Integration**: Manages reminder scheduling
/// - **User Feedback**: Provides contextual success/error messages
///
/// ## Data Flow:
/// 1. **Initialization**: Loads habits from storage
/// 2. **User Interaction**: Processes habit completion/management
/// 3. **Lifecycle Events**: Refreshes data on app resume
/// 4. **State Updates**: Notifies UI of changes via callbacks
///
/// ## Usage Pattern:
/// ```dart
/// final controller = DashboardController(appState);
/// await controller.loadHabits();
/// await controller.refreshHabits();
/// ```
class DashboardController {
  final AppState _appState;
  DateTime? _lastRefreshTime;

  DashboardController(this._appState);

  // Getters for state
  List<Habit> get habits => _appState.habits;
  bool get isLoading => _appState.isLoading;
  String? get error => _appState.error;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  bool get needsRefresh => _lastRefreshTime == null ||
    DataFreshness.shouldRefreshOnResume(_lastRefreshTime!);

  /// Load habits from storage and update refresh timestamp
  ///
  /// This method fetches all active habits from the data layer and updates
  /// the internal refresh timestamp. It's called during initialization and
  /// when manual refresh is requested.
  ///
  /// ## Process:
  /// 1. Calls the habit provider to load data from storage
  /// 2. Updates the last refresh timestamp
  /// 3. Logs the operation for debugging
  ///
  /// ## Error Handling:
  /// Errors are handled by the underlying provider and logged appropriately.
  Future<void> loadHabits() async {
    debugPrint('📱 DashboardController: Loading habits from storage...');
    await _appState.habitProvider.loadHabits();
    _lastRefreshTime = DateTime.now();
    debugPrint('📱 DashboardController: Loaded ${habits.length} habits at $_lastRefreshTime');
  }

  /// Refresh habits with intelligent freshness checking
  ///
  /// This method implements smart refresh logic that only reloads data when necessary,
  /// improving performance and user experience. It checks data freshness and only
  /// performs expensive operations when required.
  ///
  /// ## Parameters:
  /// - [forceRefresh]: If true, bypasses freshness check and always refreshes
  ///
  /// ## Refresh Conditions:
  /// - Data has never been loaded (first time)
  /// - Data is older than 1 hour
  /// - A new day has passed since last load
  /// - Force refresh is explicitly requested
  ///
  /// ## Performance Benefits:
  /// - Avoids unnecessary network/storage calls
  /// - Reduces battery usage
  /// - Improves app responsiveness
  Future<void> refreshHabits({bool forceRefresh = false}) async {
    final shouldRefresh = forceRefresh || needsRefresh;
    
    if (!shouldRefresh) {
      debugPrint('📱 DashboardController: Habits are fresh, skipping refresh');
      return;
    }
    
    debugPrint('🔄 DashboardController: Refreshing habits...');
    await loadHabits();
  }

  /// Handle habit tap - navigate to details
  void onHabitTap(BuildContext context, Habit habit) {
    // TODO: Navigate to habit details screen
    // For now, we'll implement this in the view
  }

  /// Update habit completion count
  Future<void> onMarkCompleted(Habit habit, [int? count]) async {
    final today = DateTime.now();
    final currentCount = habit.getCompletionCount(today);

    // If no count specified, toggle between 0 and 1 for backward compatibility
    final newCount = count ?? (currentCount > 0 ? 0 : 1);

    // Update completion count
    await _appState.habitProvider.updateHabitCompletion(
      habit.id,
      today,
      newCount,
    );

    // Handle notification scheduling based on completion status
    final wasCompleted = currentCount > 0;
    final isCompleted = newCount > 0;

    if (!wasCompleted && isCompleted && habit.enableReminders) {
      // Habit was just completed - cancel reminder for today, schedule for tomorrow
      await _appState.notificationProvider.cancelHabitReminder(habit.id);
      await _appState.notificationProvider.scheduleHabitReminder(habit);
    } else if (wasCompleted && !isCompleted && habit.enableReminders) {
      // Habit was marked incomplete - schedule reminder for today
      await _appState.notificationProvider.scheduleHabitReminder(habit);
    }
  }

  /// Archive a habit
  Future<void> archiveHabit(BuildContext context, Habit habit) async {
    final success = await _appState.habitProvider.archiveHabit(habit.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Habit "${habit.name}" archived'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => unarchiveHabit(context, habit),
          ),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to archive habit'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Unarchive a habit
  Future<void> unarchiveHabit(BuildContext context, Habit habit) async {
    final success = await _appState.habitProvider.unarchiveHabit(habit.id);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to unarchive habit'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Delete a habit permanently
  Future<void> deleteHabit(BuildContext context, Habit habit) async {
    final success = await _showDeleteConfirmation(context, habit);
    if (success) {
      await _appState.habitProvider.deleteHabit(habit.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Habit "${habit.name}" deleted'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Show delete confirmation dialog
  Future<bool> _showDeleteConfirmation(BuildContext context, Habit habit) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Habit'),
          content: Text(
            'Are you sure you want to delete "${habit.name}"? This action cannot be undone and will permanently remove all completion data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Add sample habits
  Future<void> addSampleHabits(BuildContext context) async {
    try {
      // Get all habits (including archived) to check for existing samples
      final allHabits = await _appState.habitProvider.repository.getAllHabits();
      final archivedHabits = allHabits.where((h) => h.isArchived).toList();

      int retrievedCount = 0; // Counter for habits restored from archive
      int addedCount = 0;    // Counter for newly created habits

      // Get the 4 predefined sample habit templates
      final sampleHabits = _getAllSampleHabits();

      // Step 1: Unarchive any archived sample habits (preserves completion history)
      for (final archivedHabit in archivedHabits) {
        // Check if this archived habit matches one of our sample templates
        final isSample = sampleHabits.any((sample) => archivedHabit.id == sample.id);

        if (isSample) {
          final success = await _appState.habitProvider.unarchiveHabit(archivedHabit.id);
          if (success) {
            retrievedCount++;
          }
        }
      }

      // Step 2: Create missing sample habits to ensure we have all 4 available
      for (final sampleHabit in sampleHabits) {
        // Check if this sample habit already exists (active or archived)
        final alreadyExists = allHabits.any((existing) => existing.id == sampleHabit.id);

        if (!alreadyExists) {
          final result = await _appState.habitProvider.addHabit(sampleHabit);
          if (result.success) {
            addedCount++;
          }
        }
      }

      // Step 3: Refresh UI and provide user feedback
      await loadHabits(); // Refresh UI

      if (context.mounted) {
        // Generate appropriate user feedback message based on actions taken
        String message;
        Color backgroundColor;

        if (retrievedCount > 0 && addedCount > 0) {
          message = '$addedCount sample habit${addedCount != 1 ? 's' : ''} created. $retrievedCount unarchived.';
          backgroundColor = Colors.green;
        } else if (retrievedCount > 0) {
          message = '$retrievedCount sample habit${retrievedCount != 1 ? 's' : ''} unarchived.';
          backgroundColor = Colors.blue;
        } else if (addedCount > 0) {
          message = '$addedCount sample habit${addedCount != 1 ? 's' : ''} created.';
          backgroundColor = Colors.green;
        } else {
          message = 'All samples are already active.';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding sample habits: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Get all sample habits
  List<Habit> _getAllSampleHabits() {
    return [
      Habit.create(
        name: 'Drink Water',
        description: 'Drink 8 glasses of water daily',
        colorIndex: 0,
        iconName: 'local_drink',
        targetGoal: 8,
      ),
      Habit.create(
        name: 'Take a Walk',
        description: 'Go for a 10-minute walk outdoors',
        colorIndex: 1,
        iconName: 'directions_walk',
        targetGoal: 1,
      ),
      Habit.create(
        name: 'Read 10 Minutes',
        description: 'Read a book for at least 10 minutes',
        colorIndex: 2,
        iconName: 'book',
        targetGoal: 1,
      ),
      Habit.create(
        name: 'Eat Vegetables',
        description: 'Eat 4 portions of vegetables daily',
        colorIndex: 3,
        iconName: 'eco',
        targetGoal: 4,
      ),
    ];
  }


  /// Clear error state
  void clearError() {
    _appState.clearErrors();
  }

  /// Get completed habits count for today (habits that achieved their goal)
  int getCompletedTodayCount() {
    final today = DateTime.now();
    return habits.where((habit) => habit.isGoalAchieved(today)).length;
  }

  /// Get total completion percentage for today across all habits
  double getTodayCompletionRate() {
    if (habits.isEmpty) return 0.0;
    
    double totalCompletionPercentage = 0.0;
    final today = DateTime.now();
    
    for (final habit in habits) {
      final count = habit.getCompletionCount(today);
      final percentage = (count / habit.targetGoal).clamp(0.0, 1.0);
      totalCompletionPercentage += percentage;
    }
    
    return totalCompletionPercentage / habits.length;
  }
}
