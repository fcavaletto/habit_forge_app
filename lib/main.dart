import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'models/habit.dart';
import 'models/habit_storage.dart';
import 'widgets/habit_card.dart';
import 'screens/add_habit_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
// PHASE 2: Import for new DashboardScreen implementation
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';

/// Application entry point
///
/// Initializes all necessary services and starts the Flutter application.
/// This includes:
/// 1. Storage initialization - Loads existing habit data
/// 2. Notification service setup - Configures push notifications
/// 3. Error handling - Graceful degradation if services fail
/// 4. App launch - Starts the main Flutter application
///
/// The initialization is designed to be robust and will continue
/// even if individual services fail to initialize.
Future<void> main() async {
  // Ensure Flutter framework is ready before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app...');
  
  // Start the Flutter app immediately - no service initialization
  runApp(const HabitForgeApp());
  debugPrint('✅ Flutter app started');
}

/// Root application widget with theme management
///
/// This widget manages the application's theme state and provides
/// the MaterialApp configuration. It handles:
/// - Theme mode persistence (light/dark/system)
/// - Theme switching functionality
/// - Material 3 design system integration
/// - Navigation to the main dashboard
class HabitForgeApp extends StatefulWidget {
  const HabitForgeApp({super.key});

  @override
  State<HabitForgeApp> createState() => _HabitForgeAppState();
}

class _HabitForgeAppState extends State<HabitForgeApp> {
  /// Current theme mode - defaults to system preference
  ThemeMode _themeMode = ThemeMode.system;

  /// PHASE 2: Feature flag to switch between old and new dashboard implementations
  /// Set to false to use original HabitDashboard, true to use new DashboardScreen
  static const bool _useNewDashboard = true; // PHASE 4: ENABLED - Using new DashboardScreen

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  /// Loads the user's preferred theme mode from persistent storage
  ///
  /// Retrieves the saved theme preference from SharedPreferences.
  /// If no preference is saved, defaults to system theme.
  /// Values: 0 = system, 1 = light, 2 = dark
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
    });
  }

  /// Saves the user's theme preference to persistent storage
  ///
  /// Persists the theme mode selection so it survives app restarts.
  /// Updates both the persistent storage and the widget state.
  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Forge', // App title shown in task switcher
      theme: AppTheme.lightTheme, // Light theme configuration
      darkTheme: AppTheme.darkTheme, // Dark theme configuration
      themeMode: _themeMode, // Current theme mode (system/light/dark)
      home: _buildDashboard(), // PHASE 2: Use conditional dashboard builder
    );
  }

  /// PHASE 2: Conditional dashboard builder to support both implementations
  ///
  /// This method allows switching between the original HabitDashboard implementation
  /// and the new DashboardScreen implementation using the _useNewDashboard flag.
  /// Both implementations remain available for testing and gradual migration.
  Widget _buildDashboard() {
    if (_useNewDashboard) {
      // PHASE 4: New DashboardScreen implementation (ENABLED)
      return DashboardScreen(
        themeMode: _themeMode,
        onThemeChanged: _saveThemeMode,
      );
    }

    // PHASE 2: Original HabitDashboard implementation (available for rollback)
    // This fallback implementation remains available for emergency rollback
    // if any issues are discovered with the new DashboardScreen
    return HabitDashboard(
      themeMode: _themeMode, // Pass current theme to dashboard
      onThemeChanged: _saveThemeMode, // Callback for theme changes
    );
  }
}

/// Main dashboard screen displaying user's habits and providing navigation
///
/// This is the primary screen users see when opening the app. It features:
/// - List of habit cards with progress visualization
/// - Quick access to habit creation and calendar views
/// - Theme switching controls
/// - Overdue habit notifications
/// - Pull-to-refresh functionality
///
/// The dashboard serves as the central hub for all habit-related activities.
class HabitDashboard extends StatefulWidget {
  /// Current theme mode for theme switching UI
  final ThemeMode themeMode;

  /// Callback function to handle theme mode changes
  final ValueChanged<ThemeMode> onThemeChanged;

  const HabitDashboard({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HabitDashboard> createState() => _HabitDashboardState();
}

class _HabitDashboardState extends State<HabitDashboard> {
  /// List of user's habits loaded from storage
  List<Habit> _habits = [];

  /// Loading state to show progress indicator during data fetch
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _checkOverdueHabits();
  }

  /// Loads all habits from persistent storage
  ///
  /// Fetches habits from SharedPreferences and updates the UI.
  /// Also triggers overdue habit checking after successful load.
  /// Handles loading states to provide user feedback.
  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);

    try {
      final habits = await habitStorage.getHabits();
      setState(() {
        _habits = habits;
        _isLoading = false;
      });

      // Check for overdue habits after loading
      _checkOverdueHabits();

      // Note: Reminders are now scheduled on-demand when user enables them
      // No need to schedule all reminders here since notification service
      // will be initialized when user first tries to enable reminders
    } catch (e) {
      debugPrint('Error loading habits: $e');
      setState(() => _isLoading = false);
      // Show error snackbar to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load habits: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Checks for habits that are overdue and shows notifications
  ///
  /// Scans through all habits with reminders enabled and identifies
  /// those that should have been completed yesterday or today but weren't.
  /// Shows an in-app banner for the first overdue habit found.
  ///
  /// This helps users stay on track by alerting them to missed completions.
  void _checkOverdueHabits() {
    final now = DateTime.now();

    // Filter habits that have reminders enabled and are overdue
    final overdueHabits = _habits.where((habit) {
      // Skip habits without reminders enabled
      if (!habit.enableReminders) return false;

      // Check if habit was supposed to be completed yesterday or today
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      return !habit.isCompleted(yesterday) || !habit.isCompleted(now);
    }).toList();

    // Show notification for first overdue habit (if any)
    if (overdueHabits.isNotEmpty) {
      final overdueHabit = overdueHabits.first;
      _showOverdueBanner(overdueHabit);
    }
  }

  /// Shows an in-app banner notification for overdue habits
  ///
  /// Displays a prominent snackbar with the overdue habit name and
  /// provides a quick "Complete" action button. Uses a delayed callback
  /// to ensure the widget tree is fully built before showing the banner.
  ///
  /// The banner includes:
  /// - Warning icon for visual prominence
  /// - Habit name in the message
  /// - Orange background for attention
  /// - 5-second duration with manual dismissal option
  /// - Quick completion action
  void _showOverdueBanner(Habit habit) {
    // Delay to ensure widget is fully built and context is valid
    Future.delayed(const Duration(milliseconds: 500), () {
      // Check if widget is still mounted before showing UI
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"${habit.name}" is overdue! Complete it now.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[700], // Orange for warning/attention
          duration: const Duration(seconds: 5), // Auto-dismiss after 5 seconds
          action: SnackBarAction(
            label: 'Complete',
            textColor: Colors.white,
            onPressed: () {
              _markHabitComplete(habit); // Quick completion from banner
            },
          ),
        ),
      );
    });
  }

  /// Adds sample habits to the user's dashboard.
  ///
  /// This method ensures there are always 4 sample habits available by:
  /// 1. Unarchiving any archived sample habits (preserving their completion history)
  /// 2. Creating missing sample habits from the predefined templates
  /// 3. Providing clear user feedback about what actions were taken
  ///
  /// The method handles edge cases gracefully:
  /// - If all sample habits are already active, shows appropriate message
  /// - If some habits are archived, prioritizes unarchiving over creating new ones
  /// - Provides detailed feedback about how many habits were created vs unarchived
  ///
  /// Sample habits include: Drink Water, Exercise, Read Book, and Sleep Early.
  ///
  /// @return Future that completes when sample habits have been processed
  /// @throws StorageException if habit storage operations fail
  Future<void> _addSampleHabits() async {
    try {
      // Step 1: Gather current habit state (both active and archived)
      final allHabits = await habitStorage.getHabits(includeArchived: true);
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
          final success = await habitStorage.unarchiveHabit(archivedHabit.id);
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
          final result = await habitStorage.saveHabit(sampleHabit);
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

  /// Toggles the completion status of a habit for today
  ///
  /// Marks a habit as completed or incomplete for the current day.
  /// Updates the storage, refreshes the UI, and manages notification scheduling.
  ///
  /// If a habit is marked as completed and has reminders enabled,
  /// the reminder is rescheduled for tomorrow. If marked as incomplete,
  /// a reminder is scheduled for today to encourage completion.
  ///
  /// @param habit The habit to toggle completion for
  Future<void> _markHabitComplete(Habit habit) async {
    final today = DateTime.now();
    final isCompleted = habit.isCompleted(today);

    // Update completion status in storage
    await habitStorage.updateHabitCompletion(
      habit.id,
      today,
      !isCompleted, // Toggle the current completion state
    );

    // Manage notification scheduling based on new completion state
    if (!isCompleted && habit.enableReminders) {
      // Habit was just completed - cancel reminder for today, schedule for tomorrow
      await notificationService.cancelHabitReminder(habit.id);
      await notificationService.scheduleHabitReminder(habit);
    } else if (isCompleted && habit.enableReminders) {
      // Habit was marked incomplete - schedule reminder for today
      await notificationService.scheduleHabitReminder(habit);
    }

    // Refresh the UI with updated data
    await _loadHabits();
  }

  /// Navigates to the settings screen
  ///
  /// Opens a full-screen settings page with theme selection options
  /// and additional app settings. Provides access to theme switching
  /// and sample data generation with a proper navigation experience.
  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentThemeMode: widget.themeMode, // Pass current theme
          onThemeChanged: widget.onThemeChanged, // Theme change callback
          onAddSampleHabits: _addSampleHabits, // Sample data callback
          onRetrieveArchivedHabits: _retrieveArchivedHabits, // Archived habits callback
        ),
      ),
    );
  }

  /// Shows the habit creation modal
  ///
  /// Opens a full-screen modal for creating new habits with:
  /// - Form validation and duplicate checking
  /// - Time picker for reminders
  /// - Icon and color selection
  /// - Automatic refresh after creation
  void _showAddHabitDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full-screen modal
      backgroundColor: Colors.transparent, // Custom background
      builder: (context) => AddHabitScreen(
        onHabitAdded: (habit) {
          _loadHabits(); // Refresh the habit list
        },
        existingHabits: _habits, // Pass current habits for duplicate checking
      ),
    );
  }

  /// Archive a habit (hide from main view)
  ///
  /// Marks the habit as archived so it doesn't appear in the main habit list
  /// but keeps all completion data intact.
  Future<void> _archiveHabit(Habit habit) async {
    try {
      final success = await habitStorage.archiveHabit(habit.id);
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
  Future<void> _unarchiveHabit(Habit habit) async {
    try {
      final success = await habitStorage.unarchiveHabit(habit.id);
      if (success) {
        await _loadHabits(); // Refresh the UI
      }
    } catch (e) {
      debugPrint('Error unarchiving habit: $e');
    }
  }

  /// Show delete confirmation dialog
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

  /// Delete a habit permanently
  Future<void> _deleteHabit(Habit habit) async {
    try {
      await habitStorage.deleteHabit(habit.id);
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

  /// Returns a list of predefined sample habit templates.
  ///
  /// These sample habits serve as onboarding examples for new users and demonstrate
  /// the app's capabilities. Each sample habit includes:
  /// - A descriptive name and detailed description
  /// - An appropriate Material Design icon
  /// - A unique color index for visual differentiation
  ///
  /// The current sample habits are:
  /// - "Drink Water": Daily hydration tracking (8 glasses)
  /// - "Exercise": Physical activity goals (30 minutes)
  /// - "Read Book": Reading habit formation (20 minutes)
  /// - "Sleep Early": Better sleep schedule (bed by 10 PM)
  ///
  /// Each sample habit is created with deterministic IDs based on name+icon combination,
  /// enabling reliable duplicate detection and archiving/unarchiving functionality.
  ///
  /// @return List of 4 sample Habit objects with predefined templates
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

  /// Retrieve all archived habits and bring them back to main view
  Future<void> _retrieveArchivedHabits() async {
    try {
      final archivedHabits = await habitStorage.getArchivedHabits();

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
        final success = await habitStorage.unarchiveHabit(habit.id);
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

  /// Shows detailed habit information in a modal
  ///
  /// Displays comprehensive habit details including:
  /// - 4-week progress visualization
  /// - Completion statistics
  /// - Individual day toggling
  /// - Streak information
  void _showHabitDetails(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow large modal
      builder: (context) => DraggableScrollableSheet(
        expand: false, // Don't expand to full screen
        initialChildSize: 0.8, // Start at 80% screen height
        maxChildSize: 0.9, // Max 90% screen height
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController, // Enable scrolling
          child: DetailedHabitCard(
            habit: habit,
            onClose: () => Navigator.of(context).pop(), // Close handler
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Main app bar with navigation and action buttons
      appBar: AppBar(
        title: const Text('Habit Forge'), // App branding
        backgroundColor: Theme.of(context).colorScheme.surface, // Theme-aware background
        foregroundColor: Theme.of(context).colorScheme.onSurface, // Theme-aware text color
        elevation: 0, // Flat design for modern look
        shadowColor: Colors.transparent, // Remove shadow
        surfaceTintColor: Colors.transparent, // Remove tint
        actions: [
          // Calendar navigation button
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CalendarScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_today),
            tooltip: 'View Calendar', // Accessibility tooltip
          ),
          // Settings button
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          // Add habit button
          IconButton(
            onPressed: _showAddHabitDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add New Habit',
          ),
        ],
      ),
      // Dynamic body content based on app state
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Loading spinner
          : _habits.isEmpty
              ? _buildEmptyState() // Onboarding screen for new users
              : _buildHabitList(), // Main habit list view
    );
  }

  /// Builds the empty state onboarding screen for new users.
  ///
  /// This screen is shown when the user has no active habits and serves as
  /// the primary onboarding experience. It provides two clear paths:
  /// 1. "Add Habit" - Direct creation of a custom habit
  /// 2. "Add Sample Habits" - Quick setup with 4 predefined example habits
  ///
  /// The sample habits option is prominently displayed as a secondary action
  /// to help users get started quickly with proven habit examples.
  ///
  /// @return Widget displaying the onboarding empty state interface
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large icon to make the screen visually appealing
          Icon(
            Icons.track_changes,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          // Main heading
          Text(
            'No habits yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          // Subtle guidance text
          Text(
            'Add your first habit to get started!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Primary action button
          FilledButton.icon(
            onPressed: _showAddHabitDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Habit'),
          ),
          const SizedBox(height: 12),
          // Secondary action for sample data
          TextButton(
            onPressed: _addSampleHabits,
            child: const Text('Add Sample Habits'),
          ),
        ],
      ),
    );
  }

  /// Builds the main habit list view
  ///
  /// Displays all user habits in a scrollable list with:
  /// - Pull-to-refresh functionality for data sync
  /// - Individual habit cards with completion status
  /// - Tap-to-view-details interaction
  /// - Quick completion toggle buttons
  ///
  /// Uses RefreshIndicator for manual data refresh and
  /// ListView.builder for efficient rendering of habit cards.
  Widget _buildHabitList() {
    return RefreshIndicator(
      // Pull-to-refresh gesture handler
      onRefresh: _loadHabits,
      child: ListView.builder(
        // Add bottom padding for better scrolling experience
        padding: const EdgeInsets.only(bottom: 16),
        // Number of habits to display
        itemCount: _habits.length,
        itemBuilder: (context, index) {
          final habit = _habits[index];
          return HabitCard(
            habit: habit,
            // Tap card to view detailed information
            onTap: () => _showHabitDetails(habit),
            // Tap completion button to toggle status
            onComplete: () => _markHabitComplete(habit),
            // Long press menu actions
            onEdit: () => _showHabitDetails(habit), // Reuse the details screen for editing
            onArchive: () => _archiveHabit(habit),
            onDelete: () => _showDeleteConfirmation(habit),
          );
        },
      ),
    );
  }
}