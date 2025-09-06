import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_storage.dart';
import '../services/notification_service.dart';
import '../providers/app_state_provider.dart';

/// Controller class that handles all business logic for the dashboard
/// This separates UI concerns from business logic for better testability and maintainability
class DashboardController {
  final AppState _appState;

  DashboardController(this._appState);

  // Getters for state
  List<Habit> get habits => _appState.habits;
  bool get isLoading => _appState.isLoading;
  String? get error => _appState.error;

  /// Load habits from storage
  Future<void> loadHabits() async {
    debugPrint('📱 Loading habits from storage...');
    await _appState.habitProvider.loadHabits();
    debugPrint('📱 Loaded ${habits.length} habits');
  }

  /// Handle habit tap - navigate to details
  void onHabitTap(BuildContext context, Habit habit) {
    // TODO: Navigate to habit details screen
    // For now, we'll implement this in the view
  }

  /// Mark habit as completed or incomplete
  Future<void> onMarkCompleted(Habit habit) async {
    final today = DateTime.now();
    final isCompleted = habit.isCompleted(today);

    // Update completion status
    await _appState.habitProvider.updateHabitCompletion(
      habit.id,
      today,
      !isCompleted,
    );

    // Handle notification scheduling
    if (!isCompleted && habit.enableReminders) {
      // Habit was just completed - cancel reminder for today, schedule for tomorrow
      await _appState.notificationProvider.cancelHabitReminder(habit.id);
      await _appState.notificationProvider.scheduleHabitReminder(habit);
    } else if (isCompleted && habit.enableReminders) {
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
      ),
      Habit.create(
        name: 'Exercise',
        description: '30 minutes of physical activity',
        colorIndex: 1,
        iconName: 'fitness_center',
      ),
      Habit.create(
        name: 'Read Book',
        description: 'Read for at least 20 minutes',
        colorIndex: 2,
        iconName: 'book',
      ),
      Habit.create(
        name: 'Sleep Early',
        description: 'Go to bed by 10 PM',
        colorIndex: 3,
        iconName: 'bed',
      ),
    ];
  }

  /// Retrieve all archived habits
  Future<void> retrieveArchivedHabits(BuildContext context) async {
    try {
      final archivedHabits = await _appState.habitProvider.repository.getArchivedHabits();

      if (archivedHabits.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No habits are currently archived'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Unarchive all archived habits
      int retrievedCount = 0;
      for (final habit in archivedHabits) {
        final success = await _appState.habitProvider.unarchiveHabit(habit.id);
        if (success) {
          retrievedCount++;
        }
      }

      // Refresh the UI
      await loadHabits();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$retrievedCount archived habit${retrievedCount != 1 ? 's' : ''} retrieved'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error retrieving archived habits: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Clear error state
  void clearError() {
    _appState.clearErrors();
  }

  /// Get completed habits count for today
  int getCompletedTodayCount() {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return habits.where((habit) => habit.completions[todayKey] == true).length;
  }

  /// Get completion rate for today
  double getTodayCompletionRate() {
    if (habits.isEmpty) return 0.0;
    return getCompletedTodayCount() / habits.length;
  }
}
