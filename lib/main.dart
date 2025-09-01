/// Habit Forge - A comprehensive habit tracking application
///
/// This application provides users with tools to build and maintain healthy habits
/// through visual progress tracking, reminder notifications, and data persistence.
///
/// Key Features:
/// - Interactive habit cards with completion tracking
/// - GitHub-style calendar visualization
/// - Daily reminder notifications
/// - Local data persistence with SharedPreferences
/// - Material 3 design with dark/light theme support
/// - Comprehensive error handling and user feedback

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'theme.dart';
import 'models/habit.dart';
import 'models/habit_storage.dart';
import 'widgets/habit_card.dart';
import 'screens/add_habit_screen.dart';
import 'screens/calendar_screen.dart';
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

  debugPrint('Starting app initialization...');

  // Initialize storage system to load existing habits
  debugPrint('Initializing storage...');
  await habitStorage.getHabits(); // Warm up storage and preload data
  debugPrint('Storage initialized');

  // Initialize notifications with comprehensive error handling
  // This is wrapped in a try-catch to ensure the app starts even if
  // notification permissions are denied or services fail
  try {
    debugPrint('Initializing notifications...');
    await notificationService.initialize().timeout(
      const Duration(seconds: 10), // Prevent hanging on initialization
      onTimeout: () {
        debugPrint('Notification initialization timed out - continuing without notifications');
        return;
      },
    );
    debugPrint('Notifications initialized successfully');
  } catch (e) {
    // Log the error but don't crash the app - notifications are not critical
    debugPrint('Failed to initialize notifications: $e');
    debugPrint('App will continue without notification features');
  }

  debugPrint('Starting Flutter app...');
  runApp(const HabitForgeApp());
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
      title: 'HabitKit', // App title shown in task switcher
      theme: AppTheme.lightTheme, // Light theme configuration
      darkTheme: AppTheme.darkTheme, // Dark theme configuration
      themeMode: _themeMode, // Current theme mode (system/light/dark)
      home: HabitDashboard(
        themeMode: _themeMode, // Pass current theme to dashboard
        onThemeChanged: _saveThemeMode, // Callback for theme changes
      ),
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

      // Reschedule all reminders to ensure they're active after app restart
      await notificationService.scheduleAllReminders(habits);
    } catch (e) {
      debugPrint('Error loading habits: $e');
      setState(() => _isLoading = false);
      // Show error snackbar to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading habits: $e')),
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
              Icon(
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

  Future<void> _addSampleHabits() async {
    final sampleHabits = [
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

    for (final habit in sampleHabits) {
      await habitStorage.saveHabit(habit);
    }

    await _loadHabits();
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

  /// Shows the settings modal bottom sheet
  ///
  /// Displays theme selection options and additional app settings.
  /// Provides access to theme switching and sample data generation.
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SettingsBottomSheet(
        currentThemeMode: widget.themeMode, // Pass current theme
        onThemeChanged: widget.onThemeChanged, // Theme change callback
        onAddSampleHabits: _addSampleHabits, // Sample data callback
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
            onComplete: () => _markHabitComplete(habit), // Completion handler
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
        title: const Text('HabitKit'), // App branding
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

  /// Builds the empty state screen for new users
  ///
  /// Shows a welcoming interface when no habits exist yet.
  /// Provides clear call-to-action buttons for creating first habit
  /// or loading sample data for demonstration purposes.
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
          );
        },
      ),
    );
  }
}

/// Settings modal bottom sheet
///
/// Provides access to app settings and preferences including:
/// - Theme mode selection (light/dark/system)
/// - Sample data generation for testing
/// - Additional app configuration options
///
/// Uses a clean, modal design that slides up from the bottom
/// and provides immediate access to key settings without
/// navigating away from the main screen.
class SettingsBottomSheet extends StatelessWidget {
  /// Current theme mode for UI state display
  final ThemeMode currentThemeMode;

  /// Callback for theme mode changes
  final ValueChanged<ThemeMode> onThemeChanged;

  /// Callback for adding sample habits
  final VoidCallback onAddSampleHabits;

  const SettingsBottomSheet({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    required this.onAddSampleHabits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeOption(
                  context,
                  'Light',
                  ThemeMode.light,
                  Icons.light_mode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  context,
                  'Dark',
                  ThemeMode.dark,
                  Icons.dark_mode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  context,
                  'System',
                  ThemeMode.system,
                  Icons.settings_suggest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              onAddSampleHabits();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Sample Habits'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    IconData icon,
  ) {
    final isSelected = currentThemeMode == mode;
    return InkWell(
      onTap: () {
        onThemeChanged(mode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DEPRECATED: Old AddHabitDialog class - replaced with AddHabitScreen modal bottom sheet
// This class is no longer used but kept for reference
/*
class AddHabitDialog extends StatefulWidget {
  final VoidCallback onHabitAdded;

  const AddHabitDialog({super.key, required this.onHabitAdded});

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedColorIndex = 0;
  String _selectedIcon = 'check_circle';

  final List<String> _availableIcons = [
    'check_circle',
    'fitness_center',
    'local_drink',
    'book',
    'bed',
    'restaurant',
    'directions_run',
    'school',
    'work',
    'favorite',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveHabit() async {
    if (_nameController.text.trim().isEmpty) return;

    final habit = Habit.create(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      colorIndex: _selectedColorIndex,
      iconName: _selectedIcon,
    );

    await habitStorage.saveHabit(habit);
    widget.onHabitAdded();

    // Use a post-frame callback to ensure context is still valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Add New Habit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                hintText: 'e.g., Drink Water',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Drink 8 glasses daily',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: colorScheme.habitColors.length,
                itemBuilder: (context, index) {
                  final color = colorScheme.habitColors[index];
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Icon',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final iconName = _availableIcons[index];
                  final isSelected = _selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveHabit,
          child: const Text('Add Habit'),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'local_drink':
        return Icons.local_drink;
      case 'book':
        return Icons.book;
      case 'bed':
        return Icons.bed;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_run':
        return Icons.directions_run;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.check_circle;
    }
  }
}
*/