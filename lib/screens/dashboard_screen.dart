import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_storage.dart';
import '../widgets/habit_card.dart';
import '../utils/constants.dart';

// Screen imports for navigation
import '../screens/settings_screen.dart';
import '../screens/add_habit_screen.dart';
import '../screens/calendar_screen.dart';

// Service imports for functionality
import '../services/notification_service.dart';

/// Dashboard Screen - Main habit tracking interface
///
/// PHASE 1 COMPLETE: This screen is a standalone replica of the main dashboard
/// functionality from main.dart, designed for better separation of concerns.
///
/// This screen displays:
/// - Grid of active habits with completion status
/// - Empty state with sample habit creation
/// - Quick actions for habit management (edit, archive, delete)
/// - Today's progress overview with completion statistics
/// - Navigation to calendar, settings, and habit creation
///
/// Key Features:
/// ✅ Habit completion tracking with notification integration
/// ✅ Sample habit creation and management
/// ✅ Theme-aware UI with proper Material 3 design
/// ✅ Comprehensive error handling and user feedback
/// ✅ Standalone implementation ready for migration
///
/// Architecture Benefits:
/// - Better separation of concerns from main.dart
/// - Improved maintainability and testability
/// - Reusable component for future dashboard variations
/// - Clean dependency injection with required parameters
class DashboardScreen extends StatefulWidget {
  /// Current theme mode for theme switching UI
  final ThemeMode themeMode;

  /// Callback function to handle theme mode changes
  final ValueChanged<ThemeMode> onThemeChanged;

  const DashboardScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// State class for DashboardScreen
///
/// Manages the state and business logic for the dashboard screen including:
/// - Habit data loading and state management
/// - User interactions (habit completion, navigation)
/// - Error handling and user feedback
/// - Service coordination (storage, notifications)
///
/// This state class is designed to be self-contained and testable,
/// with clear separation between UI rendering and business logic.
class _DashboardScreenState extends State<DashboardScreen> {
  /// Storage service for habit data persistence
  /// Singleton instance - no disposal needed
  final HabitStorage _habitStorage = HabitStorage();

  /// Notification service for habit reminders
  /// Singleton instance - no disposal needed
  final NotificationService _notificationService = NotificationService();

  /// Current list of habits loaded from storage
  /// Updated whenever habits change (completion, addition, deletion)
  List<Habit> _habits = [];

  /// Loading state to show progress indicator during data operations
  /// Set to true during initial load and major operations
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    // Note: HabitStorage and NotificationService are singleton instances
    // and don't require explicit disposal
    super.dispose();
  }

  Future<void> _loadHabits() async {
    try {
      final habits = await _habitStorage.getHabits();
      if (mounted) {
        setState(() {
          _habits = habits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load habits: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Habit Forge'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      actions: [
        // Calendar navigation button for viewing habit progress over time
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CalendarScreen(),
              ),
            );
          },
          tooltip: 'View Calendar',
        ),
        // Settings button for app configuration and theme switching
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettings,
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_habits.isEmpty) {
      return _buildEmptyState();
    }

    return _buildHabitsGrid(_habits);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.track_changes,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'Welcome to Habit Forge!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Build lasting habits with daily tracking and progress visualization.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.defaultPadding * 2),
            FilledButton.icon(
              onPressed: _addSampleHabits,
              icon: const Icon(Icons.add),
              label: const Text('Add Sample Habits'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding * 2,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsGrid(List<Habit> habits) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          sliver: SliverToBoxAdapter(
            child: _buildHeader(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12), // Reduced padding
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8, // Reduced spacing
              mainAxisSpacing: 8, // Reduced spacing
              childAspectRatio: 1.0, // Adjusted aspect ratio for new layout
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final habit = habits[index];
                return HabitCard(
                  habit: habit,
                  onTap: () => _onHabitTap(habit),
                  onComplete: () => _onMarkCompleted(habit),
                  onEdit: () => _showHabitDetails(habit),      // Enable editing from card
                  onArchive: () => _archiveHabit(habit),       // Enable archiving from card
                  onDelete: () => _showDeleteConfirmation(habit), // Enable deletion from card
                );
              },
              childCount: habits.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final completedToday = _getCompletedTodayCount();
    final completionRate = _habits.isNotEmpty ? completedToday / _habits.length : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Progress',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$completedToday of ${_habits.length} habits completed',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (completionRate > 0) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: completionRate,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(completionRate * 100).round()}% complete',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: AppConstants.defaultPadding),
      ],
    );
  }

  int _getCompletedTodayCount() {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return _habits.where((habit) => habit.completions[todayKey] == true).length;
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showAddHabitDialog,
      tooltip: 'Add New Habit',
      child: const Icon(Icons.add),
    );
  }

  Future<void> _addSampleHabits() async {
    try {
      // Step 1: Gather current habit state (both active and archived)
      final allHabits = await _habitStorage.getHabits(includeArchived: true);
      final archivedHabits = allHabits.where((h) => h.isArchived).toList();

      int retrievedCount = 0; // Counter for habits restored from archive
      int addedCount = 0;    // Counter for newly created habits

      // Get the 4 predefined sample habit templates
      final sampleHabits = _getAllSampleHabits();

      // Step 2: Unarchive any archived sample habits (preserves completion history)
      for (final archivedHabit in archivedHabits) {
        // Check if this archived habit matches one of our sample templates
        final isSample = sampleHabits.any((sample) => archivedHabit.id == sample.id);

        if (isSample) {
          final success = await _habitStorage.unarchiveHabit(archivedHabit.id);
          if (success) {
            retrievedCount++;
          }
        }
      }

      // Step 3: Create missing sample habits to ensure we have all 4 available
      for (final sampleHabit in sampleHabits) {
        // Check if this sample habit already exists (active or archived)
        // Uses deterministic ID matching for reliable duplicate detection
        final alreadyExists = allHabits.any((existing) => existing.id == sampleHabit.id);

        if (!alreadyExists) {
          final result = await _habitStorage.saveHabit(sampleHabit);
          if (result.success) {
            addedCount++;
          }
        }
      }

      // Step 4: Refresh UI and provide user feedback
      await _loadHabits(); // Refresh UI

      if (mounted) {
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
      debugPrint('Error in _addSampleHabits: $e');
      if (mounted) {
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

  /// Navigate to the settings screen for app configuration
  ///
  /// Opens the settings screen with theme management and other app settings.
  /// Passes the current theme mode and theme change callback to the settings screen.
  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentThemeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
          onAddSampleHabits: _addSampleHabits,
          onRetrieveArchivedHabits: _retrieveArchivedHabits,
        ),
      ),
    );
  }

  /// Show the habit creation modal bottom sheet
  ///
  /// Opens a modal bottom sheet for creating new habits with form validation,
  /// duplicate checking, and automatic refresh after creation.
  void _showAddHabitDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitScreen(
        onHabitAdded: (habit) {
          _loadHabits(); // Refresh the habit list after adding new habit
        },
        existingHabits: _habits, // Pass current habits for duplicate checking
      ),
    );
  }

  /// Show detailed habit information in a modal bottom sheet
  ///
  /// Displays comprehensive habit details including progress visualization,
  /// completion statistics, and habit management options.
  void _showHabitDetails(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: DetailedHabitCard(
            habit: habit,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  void _onHabitTap(Habit habit) {
    _showHabitDetails(habit);
  }


  /// Mark a habit as completed or incomplete for today
  ///
  /// Toggles the completion status of a habit and updates the storage.
  /// Also manages notification scheduling based on completion state.
  Future<void> _onMarkCompleted(Habit habit) async {
    final today = DateTime.now();
    final isCompleted = habit.isCompleted(today);

    // Update completion status in storage
    await _habitStorage.updateHabitCompletion(
      habit.id,
      today,
      !isCompleted, // Toggle the current completion state
    );

    // Manage notification scheduling based on new completion state
    if (!isCompleted && habit.enableReminders) {
      // Habit was just completed - cancel reminder for today, schedule for tomorrow
      await _notificationService.cancelHabitReminder(habit.id);
      await _notificationService.scheduleHabitReminder(habit);
    } else if (isCompleted && habit.enableReminders) {
      // Habit was marked incomplete - schedule reminder for today
      await _notificationService.scheduleHabitReminder(habit);
    }

    await _loadHabits(); // Refresh the habits list

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completed: ${habit.name}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Archive a habit (hide from main view but keep data)
  ///
  /// Marks the habit as archived so it doesn't appear in the main habit list
  /// but keeps all completion data intact for potential restoration.
  Future<void> _archiveHabit(Habit habit) async {
    try {
      final success = await _habitStorage.archiveHabit(habit.id);
      if (success) {
        await _loadHabits(); // Refresh the UI

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Habit "${habit.name}" archived'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () => _unarchiveHabit(habit),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to archive habit'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error archiving habit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving habit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Unarchive a habit (restore to main view)
  ///
  /// Removes the archived status from a habit so it appears in the main habit list again.
  Future<void> _unarchiveHabit(Habit habit) async {
    try {
      final success = await _habitStorage.unarchiveHabit(habit.id);
      if (success) {
        await _loadHabits(); // Refresh the UI
      }
    } catch (e) {
      debugPrint('Error unarchiving habit: $e');
    }
  }

  /// Show delete confirmation dialog for permanent habit removal
  ///
  /// Displays a confirmation dialog before permanently deleting a habit
  /// and all its completion data.
  Future<void> _showDeleteConfirmation(Habit habit) async {
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

    if (result == true) {
      await _deleteHabit(habit);
    }
  }

  /// Permanently delete a habit from storage
  ///
  /// Removes the habit with the specified ID from persistent storage.
  /// This operation cannot be undone and permanently deletes all completion data.
  Future<void> _deleteHabit(Habit habit) async {
    try {
      await _habitStorage.deleteHabit(habit.id);
      await _loadHabits(); // Refresh the UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Habit "${habit.name}" deleted'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting habit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting habit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Retrieve all archived habits and bring them back to main view
  ///
  /// Unarchives all archived habits, making them visible in the main habit list again.
  /// This is used by the settings screen to restore archived habits.
  Future<void> _retrieveArchivedHabits() async {
    try {
      final archivedHabits = await _habitStorage.getArchivedHabits();

      if (archivedHabits.isEmpty) {
        if (mounted) {
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
        final success = await _habitStorage.unarchiveHabit(habit.id);
        if (success) {
          retrievedCount++;
        }
      }

      // Refresh the UI to show the retrieved habits
      await _loadHabits();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$retrievedCount archived habit${retrievedCount != 1 ? 's' : ''} retrieved'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error retrieving archived habits: $e');
      if (mounted) {
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



}

