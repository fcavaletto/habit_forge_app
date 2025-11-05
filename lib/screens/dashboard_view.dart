import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/habit.dart';
import '../providers/app_state_provider.dart';
import '../providers/habit_provider.dart';
import '../controllers/dashboard_controller.dart';
import '../services/virtual_date_service.dart';
import '../widgets/habit_card.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../widgets/current_time_clock.dart';
import '../utils/constants.dart';
import '../screens/settings_screen.dart';
import '../screens/add_habit_screen.dart';
import 'stats_screen.dart';
import 'reorder_habits_screen.dart';
import '../utils/data_freshness.dart';
import '../widgets/custom_completion_modal.dart';
import '../theme.dart';
import '../widgets/forms/icon_selector.dart';

/// Dashboard View - Pure UI component for the main habit tracking interface
///
/// This widget implements the View layer of the MVC pattern, containing only
/// UI rendering logic while delegating all business logic to the DashboardController.
/// It provides the primary user interface for habit tracking and management.
///
/// ## Architecture Pattern:
/// - **MVC Pattern**: View layer with separated business logic
/// - **Provider Pattern**: Reactive state management integration
/// - **Observer Pattern**: Lifecycle-aware UI updates
/// - **Composition Pattern**: Combines multiple specialized widgets
///
/// ## Key Responsibilities:
/// - **UI Rendering**: Displays habit cards, progress indicators, and controls
/// - **User Interaction**: Handles taps, gestures, and form interactions
/// - **State Display**: Shows loading states, errors, and empty states
/// - **Navigation**: Manages routing to other screens
/// - **Lifecycle Management**: Handles app lifecycle events for data refresh
///
/// ## User Journey:
/// 1. **Initial Load**: Displays loading indicator while data loads
/// 2. **Empty State**: Shows sample habit creation for new users
/// 3. **Habit List**: Displays interactive habit cards with progress
/// 4. **Quick Actions**: Tap to complete, long-press for options
/// 5. **Navigation**: Access settings and habit creation
///
/// ## Lifecycle Integration:
/// - **App Resume**: Automatically refreshes stale data
/// - **Smart Refresh**: Only refreshes when data is actually stale
/// - **User Feedback**: Shows subtle refresh confirmation messages
/// - **Error Handling**: Displays user-friendly error messages
///
/// ## Performance Features:
/// - **Efficient Rendering**: Uses Consumer pattern for selective rebuilds
/// - **Memory Management**: Proper disposal of controllers and observers
/// - **Debounced Operations**: Prevents rapid successive operations
/// - **Cached Data**: Shows cached data immediately while refreshing
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with WidgetsBindingObserver {
  late DashboardController _controller;
  late AppState _appState;
  DateTime? _lastResumeTime;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState = context.read<AppState>();
    _controller = DashboardController(_appState);
    // No need to load initial data - AppState already loaded it during initialization
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  /// Start the clock timer to update the display every minute when not overridden
  /// Timer is synchronized to update exactly when the system minute changes
  void _startClockTimer() {
    _clockTimer?.cancel();

    // Calculate delay until the next minute boundary
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final delay = nextMinute.difference(now);

    debugPrint(
      '🕐 Clock timer: Next update in ${delay.inSeconds} seconds (at ${nextMinute.hour}:${nextMinute.minute.toString().padLeft(2, '0')})',
    );

    // First timer: wait until the next minute boundary
    Timer(delay, () {
      if (mounted &&
          !_appState.isTimeOverridden &&
          _appState.showTimeOverride) {
        setState(() {
          // Force rebuild to update the clock display
        });
      }

      // Then start the regular minute timer
      _clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (mounted &&
            !_appState.isTimeOverridden &&
            _appState.showTimeOverride) {
          setState(() {
            // Force rebuild to update the clock display
          });
        }
      });
    });
  }

  /// Restart the clock timer based on current override state
  void _restartClockTimer() {
    _startClockTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        // Restart clock timer to sync with system time after app resume
        if (_appState.showTimeOverride && !_appState.isTimeOverridden) {
          _restartClockTimer();
        }
        break;
      case AppLifecycleState.paused:
        debugPrint('⏸️ Dashboard: App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('🔌 Dashboard: App detached');
        break;
      default:
        break;
    }
  }

  void _onAppResumed() {
    final now = VirtualDateService().currentDate;

    // Skip refresh during initial app startup (when _lastResumeTime is null)
    // Only refresh when app is actually resumed from background
    if (_lastResumeTime == null) {
      debugPrint('🔄 Dashboard: Initial app startup, skipping refresh');
      _lastResumeTime = now;
      return;
    }

    // Check if data needs refresh based on time elapsed or new day
    final shouldRefresh = DataFreshness.shouldRefreshOnResume(_lastResumeTime!);

    debugPrint('🔄 Dashboard: App resumed, shouldRefresh: $shouldRefresh');

    // Only refresh if data is stale to avoid unnecessary operations
    if (shouldRefresh) {
      debugPrint('🔄 Dashboard: Triggering data refresh');
      _refreshData();
    }

    // Update resume timestamp for future freshness checks
    _lastResumeTime = now;
  }

  Future<void> _refreshData() async {
    try {
      await _controller.refreshHabits();
      // Show subtle refresh indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data refreshed'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when filtered habits count changes
    return Selector<AppState, int>(
      selector: (context, appState) =>
          appState.habitProvider.filteredHabits.length,
      builder: (context, filteredCount, child) {
        final appState = context.read<AppState>();
        return Semantics(
          label: 'Habit Forge Dashboard',
          hint: 'Main screen showing your habits and progress',
          child: Scaffold(
            appBar: _buildAppBar(appState),
            body: _buildOptimizedBody(appState),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AppState appState) {
    return AppBar(
      title: const Text('Habit Forge'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: Semantics(
        label: 'Settings',
        hint: 'Open app settings and preferences',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettings(),
          tooltip: 'Settings',
        ),
      ),
      actions: [
        // Test habits button (for development)
        Semantics(
          label: 'Create test habits',
          hint: 'Creates 20 test habits with different colors',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _createTestHabits,
            tooltip: 'Create Test Habits',
          ),
        ),
        // Add habit button
        Semantics(
          label: 'Add new habit',
          hint: 'Opens form to create a new habit',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddHabitDialog,
            tooltip: 'Add New Habit',
          ),
        ),
      ],
    );
  }

  /// Optimized body builder that minimizes rebuilds
  ///
  /// This method uses selective consumers to avoid rebuilding
  /// the entire dashboard when only specific parts change.
  ///
  /// Note: No loading spinner is shown because data is preloaded before
  /// the UI is rendered. Dashboard always has data ready.
  Widget _buildOptimizedBody(AppState appState) {
    // Get week start preference using Selector to only rebuild when it changes
    return Selector<AppState, bool>(
      selector: (context, appState) => appState.weekStartsOnMonday,
      builder: (context, weekStartsOnMonday, child) {
        // Use Selector<HabitProvider, List<String>> to listen only to habit list changes
        // This prevents rebuilding when individual habit completions change
        return Selector<HabitProvider, List<String>>(
          selector: (context, habitProvider) =>
              habitProvider.filteredHabits.map((h) => h.id).toList(),
          builder: (context, habitIds, child) {
            final habitProvider = Provider.of<HabitProvider>(
              context,
              listen: false,
            );
            final filteredHabits = habitProvider.filteredHabits;
            final hasAnyHabits = habitProvider.habits.isNotEmpty;
            // Get current date from VirtualDateService (same for all cards)
            final currentDate = VirtualDateService().currentDate;

            debugPrint(
              '🔄 Optimized DashboardView building with ${filteredHabits.length} filtered habits',
            );

            // No loading spinner - data is preloaded before UI shows
            // Background refresh happens silently without loading states

            if (filteredHabits.isEmpty) {
              debugPrint(
                '📭 No habits found for selected date, showing empty state',
              );
              return _buildEmptyState(
                hasAnyHabits: hasAnyHabits,
                appState: appState,
              );
            }

            debugPrint('📊 Building habits list with selective rebuilds');
            return _buildHabitsList(
              filteredHabits,
              weekStartsOnMonday,
              currentDate,
            );
          },
        );
      },
    );
  }

  /// Builds empty state UI when no habits are found
  ///
  /// Displays appropriate messaging based on whether any habits exist:
  /// - If hasAnyHabits is true: shows "no habits visible" message with date selector
  /// - If hasAnyHabits is false: shows "no habits exist" message for new users
  Widget _buildEmptyState({
    required bool hasAnyHabits,
    required AppState appState,
  }) {
    return SafeScrollableWrapper(
      child: Column(
        children: [
          // Show date selector when habits exist but none visible for selected date
          if (hasAnyHabits) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
              child: _buildDateSelector(appState),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
          ],
          // Empty state content
          Expanded(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.7,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasAnyHabits ? Icons.calendar_today : Icons.track_changes,
                      size: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    Text(
                      hasAnyHabits
                          ? 'No habits scheduled for this date'
                          : 'You have no habits yet',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasAnyHabits
                          ? 'Pick a different date or create a habit for today.'
                          : 'Create your first habit to start tracking your progress.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.defaultPadding * 2),
                    if (hasAnyHabits) ...[
                      // Show create habit button when habits exist but none visible
                      FilledButton.icon(
                        onPressed: _showAddHabitDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Habit'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultPadding * 2,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Show sample habits button for new users
                      FilledButton.icon(
                        onPressed: () => _controller.addSampleHabits(context),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList(
    List<Habit> habits,
    bool weekStartsOnMonday,
    DateTime currentDate,
  ) {
    return SafeCustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            10, // left padding,
            12, // top padding
            10, // right padding
            0, // bottom padding
          ),
          sliver: SliverToBoxAdapter(child: _buildHeader(habits)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          sliver: SliverToBoxAdapter(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: habits.length,
              itemBuilder: (context, index) {
                final habit = habits[index];
                return Container(
                  key: ValueKey(habit.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _buildSelectiveHabitCard(
                    habit,
                    weekStartsOnMonday,
                    currentDate,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a habit card with true selective rebuilds
  ///
  /// This method uses Selector<HabitProvider, Habit> to listen only to changes
  /// in the specific habit data, rather than rebuilding when any habit changes.
  /// This provides significant performance improvements by only rebuilding
  /// the specific habit card that actually changed.
  Widget _buildSelectiveHabitCard(
    Habit habit,
    bool weekStartsOnMonday,
    DateTime currentDate,
  ) {
    // Store habitId to avoid closure capture issues
    final habitId = habit.id;

    // Use RepaintBoundary to isolate repaints and implement true selective rebuilds
    return RepaintBoundary(
      child: _HabitCardWrapper(
        habit: habit,
        onTap: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onHabitTap(freshHabit);
        },
        onLongPress: () => _openReorderScreen(),
        onReorder: () => _openReorderScreen(),
        onComplete: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onMarkCompleted(freshHabit);
        },
        onIncrement: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onIncrementCompletion(freshHabit);
        },
        onDecrement: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onCompletionButtonPress(freshHabit);
        },
        onCustomCompletion: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onCustomCompletion(freshHabit);
        },
        onEdit: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _showEditHabit(freshHabit);
        },
        onArchive: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onArchiveHabit(freshHabit);
        },
        onDelete: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _onDeleteHabit(freshHabit);
        },
        onStats: () {
          final freshHabit = _getFreshHabit(habitId);
          if (freshHabit != null) _showHabitStats(freshHabit);
        },
        weekStartsOnMonday: weekStartsOnMonday,
        currentDate: currentDate,
      ),
    );
  }

  /// Get fresh habit from provider to avoid stale closure captures
  Habit? _getFreshHabit(String habitId) {
    try {
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      return habitProvider.habits.firstWhere(
        (h) => h.id == habitId,
        orElse: () => throw Exception('Habit not found: $habitId'),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to get fresh habit $habitId: $e');
      return null;
    }
  }

  /// Builds the dashboard header with habit statistics
  ///
  /// Displays completion counts, progress indicators, and summary
  /// information for the current habit list.
  Widget _buildHeader(List<Habit> habits) {
    // Get the provider state
    final appState = Provider.of<AppState>(context, listen: false);
    final currentDate = appState.currentDate;
    final isShowingAllHabits = appState.habitProvider.isShowingAllHabits;

    // Calculate completion count and rate based on filter mode
    final completedCount = isShowingAllHabits
        ? _controller.getCompletedCountForAllHabits()
        : _controller.getCompletedCountForDate(currentDate);
    final completionRate = isShowingAllHabits
        ? _controller.getCompletionRateForAllHabits()
        : _controller.getCompletionRateForDate(currentDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date selector - Use Selector to only rebuild when current date changes
        Selector<AppState, DateTime>(
          selector: (context, appState) => appState.currentDate,
          builder: (context, currentDate, child) {
            final appState = context.read<AppState>();
            return _buildDateSelector(appState);
          },
        ),
        const SizedBox(height: 12),
        // Time selector (conditional based on setting)
        Selector<AppState, ({bool showTimeOverride, bool isTimeOverridden})>(
          selector: (context, appState) => (
            showTimeOverride: appState.showTimeOverride,
            isTimeOverridden: appState.isTimeOverridden,
          ),
          builder: (context, data, child) {
            if (!data.showTimeOverride) {
              // Cancel timer when time override is disabled
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _clockTimer?.cancel();
              });
              return const SizedBox.shrink(); // Hide when setting is off
            }
            final appState = context.read<AppState>();
            return _buildTimeSelector(appState);
          },
        ),
        // Conditional spacing - only show when time override is visible
        Selector<AppState, bool>(
          selector: (context, appState) => appState.showTimeOverride,
          builder: (context, showTimeOverride, child) {
            return showTimeOverride
                ? const SizedBox(height: 12)
                : const SizedBox.shrink();
          },
        ),
        // Habit filter moved to Settings; progress bar follows time selector
        // Progress bar is now always visible
        LinearProgressIndicator(
          value: completionRate,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getCompletionMessage(completionRate, completedCount, habits.length),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
      ],
    );
  }

  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentThemeMode: _appState.themeMode,
          onThemeChanged: (mode) {
            _appState.themeProvider.setThemeMode(mode);
            _appState.themeProvider.saveThemeMode();
          },
          onAddSampleHabits: () => _controller.addSampleHabits(context),
        ),
      ),
    );
  }

  void _showAddHabitDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddHabitScreen(
          onHabitAdded: (habit) {
            debugPrint('📱 Dashboard received new habit: ${habit.name}');
            _controller.loadHabitsForDashboard();
          },
          existingHabits: _controller.habits,
        ),
      ),
    );
  }

  void _onHabitTap(Habit habit) {
    _controller.onHabitTap(context, habit);
  }

  Future<void> _onMarkCompleted(Habit habit) async {
    await _controller.onMarkCompleted(habit);
  }

  Future<void> _onIncrementCompletion(Habit habit) async {
    final today = VirtualDateService().currentDate;
    final currentCount = habit.getCompletionCount(today);
    await _controller.onMarkCompleted(habit, currentCount + 1);
  }

  Future<void> _onDecrementCompletion(Habit habit) async {
    final today = VirtualDateService().currentDate;
    final currentCount = habit.getCompletionCount(today);
    if (currentCount > 0) {
      await _controller.onMarkCompleted(habit, currentCount - 1);
    }
  }

  /// Reset all completions for a habit on the current day
  /// This is called when user taps the tick mark on a completed habit
  Future<void> _onResetAllCompletions(Habit habit) async {
    await _controller.onResetAllCompletions(habit);
  }

  /// Handle completion button press - determines whether to decrement or reset all
  /// This method checks if the habit is completed and calls the appropriate action
  Future<void> _onCompletionButtonPress(Habit habit) async {
    final today = VirtualDateService().currentDate;
    final isCompleted = habit.isGoalAchieved(today);

    if (isCompleted) {
      // Habit is completed - reset all completions
      await _onResetAllCompletions(habit);
    } else {
      // Habit is not completed - decrement by 1
      await _onDecrementCompletion(habit);
    }
  }

  /// Handles custom completion modal for habits with allowExceedGoal flag
  Future<void> _onCustomCompletion(Habit habit) async {
    final today = VirtualDateService().currentDate;
    final currentCount = habit.getCompletionCount(today);

    await showCustomCompletionModal(
      context: context,
      habitName: habit.name,
      currentCount: currentCount,
      targetGoal: habit.targetGoal,
      onSave: (newCount) async {
        // Delegate to controller for business logic
        await _controller.onSetCustomCompletionCount(habit.id, today, newCount);
      },
      onCancel: () {
        // Modal was cancelled - no action needed
      },
    );
  }

  void _openReorderScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReorderHabitsScreen(),
      ),
    );
  }

  void _showEditHabit(Habit habit) {
    final appState = Provider.of<AppState>(context, listen: false);

    // Get fresh habit data with completions
    final freshHabit = appState.habitProvider.getHabitById(habit.id) ?? habit;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddHabitScreen(
          habitToEdit: freshHabit,
          existingHabits: appState.habitProvider.habits,
          onHabitAdded: (_) {}, // Not used in edit mode
          onHabitUpdated: (updatedHabit) {
            // Habit was already updated in provider, just navigate back
            // The provider will notify listeners and update the UI
          },
        ),
      ),
    );
  }

  void _showHabitStats(Habit habit) {
    // Get fresh habit data from the provider to ensure we have the latest completions
    final appState = Provider.of<AppState>(context, listen: false);
    final freshHabit = appState.habitProvider.getHabitById(habit.id) ?? habit;

    // Extract last 30 days data from dashboard to pass to stats screen
    final last30DaysData = appState.habitProvider.getLast30DaysCompletions();
    final habitLast30Days = last30DaysData[habit.id] ?? {};

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatsScreen(
          habit: freshHabit,
          last30DaysCompletions: habitLast30Days,
        ),
      ),
    );
  }

  Future<void> _onArchiveHabit(Habit habit) async {
    await _controller.archiveHabit(context, habit);
  }

  Future<void> _onDeleteHabit(Habit habit) async {
    await _controller.deleteHabit(context, habit);
  }

  /// Creates 20 test habits with different colors for UI testing
  Future<void> _createTestHabits() async {
    try {
      final appState = context.read<AppState>();
      final colorScheme = Theme.of(context).colorScheme;
      final random = math.Random();

      // Create 20 habits, one for each color in the palette
      for (int i = 0; i < 20; i++) {
        final colorPair = colorScheme.habitColorPairs[19 - i];
        final randomIcon = IconSelector
            .availableIcons[random.nextInt(IconSelector.availableIcons.length)];

        final habit = Habit.createWithUuid(
          name: 'Title: color #${19 - i + 1}',
          description: 'Test habit with color ${19 - i + 1}',
          lightColorValue: colorPair.light.toARGB32(),
          darkColorValue: colorPair.dark.toARGB32(),
          iconName: randomIcon,
          reminderTime: null,
          enableReminders: false,
          frequencyDays: const {
            'mon': 1,
            'tue': 1,
            'wed': 1,
            'thu': 1,
            'fri': 1,
            'sat': 1,
            'sun': 1,
          }, // Every day
          targetGoal: 20 - i,
          allowExceedGoal: false,
        );

        // Add the habit to the app state
        await appState.habitProvider.addHabit(habit);
      }

      // Refresh the dashboard to show the new habits
      _controller.loadHabitsForDashboard();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Created 20 test habits successfully!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to create test habits: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create test habits: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Reordering is handled in a dedicated screen to avoid gesture conflicts on the dashboard

  /// Build the date selector widget
  Widget _buildDateSelector(AppState appState) {
    final currentDate = appState.currentDate;
    final isDateOverridden = appState.isDateOverridden;

    // Theme-based border width
    final borderWidth = Theme.of(context).brightness == Brightness.light
        ? 1.0 // Light theme: more prominent borders
        : 0.5; // Dark theme: subtle borders

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDateOverridden
              ? [
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.error.withValues(alpha: 1.0),
                ]
              : [
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  Theme.of(context).colorScheme.outline.withValues(alpha: 1.0),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: EdgeInsets.all(isDateOverridden ? 1.5 : borderWidth),
        decoration: BoxDecoration(
          color: isDateOverridden
              ? (Theme.of(context).brightness == Brightness.light
                    ? Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 1)
                    : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest) // No background color change in dark mode
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(11.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: isDateOverridden
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDateOverridden ? 'Date set to:' : 'Today',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDateOverridden
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(currentDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDateOverridden
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDateOverridden) ...[
                // Reset button (outlined style to stand out)
                OutlinedButton(
                  onPressed: () => appState.resetDateOverride(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(' RESET DATE '),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                onPressed: () => _showDatePicker(appState),
                icon: Icon(
                  Icons.edit,
                  color: isDateOverridden
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Select Date',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the time selector widget with dynamic states
  Widget _buildTimeSelector(AppState appState) {
    final isTimeOverridden = appState.isTimeOverridden;

    // Theme-based border width
    final borderWidth = Theme.of(context).brightness == Brightness.light
        ? 1.0 // Light theme: more prominent borders
        : 0.5; // Dark theme: subtle borders

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTimeOverridden
              ? [
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.error.withValues(alpha: 1.0),
                ]
              : [
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  Theme.of(context).colorScheme.outline.withValues(alpha: 1.0),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: EdgeInsets.all(isTimeOverridden ? 1.5 : borderWidth),
        decoration: BoxDecoration(
          color: isTimeOverridden
              ? (Theme.of(context).brightness == Brightness.light
                    ? Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 1)
                    : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest) // No background color change in dark mode
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(11.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 20,
                color: isTimeOverridden
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTimeOverridden ? 'Time set at:' : 'Current Time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isTimeOverridden
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    isTimeOverridden
                        ? Text(
                            _formatTime(appState.currentTime),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          )
                        : CurrentTimeClock(
                            isTimeOverridden: isTimeOverridden,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                  ],
                ),
              ),
              if (isTimeOverridden) ...[
                // Turn Off button (outlined style to stand out)
                OutlinedButton(
                  onPressed: () => appState.resetTimeOverride(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(' RESET TIME '),
                ),
                const SizedBox(width: 6),
              ],
              // Edit button
              IconButton(
                onPressed: () => _showTimePicker(appState),
                icon: Icon(
                  Icons.edit,
                  color: isTimeOverridden
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                tooltip: isTimeOverridden
                    ? 'Change Override Time'
                    : 'Set Time Override',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get completion message based on habit goals
  String _getCompletionMessage(
    double completionRate,
    int completedCount,
    int totalHabits,
  ) {
    final percentage = (completionRate * 100).round();

    // Check if any habits have goals greater than 1
    final hasMultiGoalHabits = _appState.habits.any(
      (habit) => habit.targetGoal > 1,
    );

    if (hasMultiGoalHabits) {
      return '$completedCount of $totalHabits habits fully completed ($percentage%)';
    } else {
      return '$completedCount of $totalHabits habits completed ($percentage%)';
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

  /// Show date picker dialog
  Future<void> _showDatePicker(AppState appState) async {
    final currentDate = appState.currentDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: VirtualDateService().currentDate.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != appState.currentDate) {
      appState.dateProvider.setVirtualDate(pickedDate);
      debugPrint('📅 Date changed to: ${_formatDate(pickedDate)}');
    }
  }

  /// Show time picker dialog
  Future<void> _showTimePicker(AppState appState) async {
    final currentTime = appState.currentTime;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && pickedTime != currentTime) {
      appState.setTimeOverride(pickedTime);
      debugPrint('🕐 Time override set to: ${_formatTime(pickedTime)}');
    }
  }

  // Habit filter UI has been moved to Settings screen
}

/// Wrapper widget that implements true selective rebuilds for individual habit cards
///
/// This widget uses a custom approach to only rebuild when the specific habit
/// data changes, avoiding unnecessary rebuilds of other habit cards.
class _HabitCardWrapper extends StatefulWidget {
  final Habit habit;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onReorder;
  final VoidCallback onComplete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onCustomCompletion;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onStats;
  final bool weekStartsOnMonday;
  final DateTime currentDate;

  const _HabitCardWrapper({
    required this.habit,
    required this.onTap,
    required this.onLongPress,
    required this.onReorder,
    required this.onComplete,
    required this.onIncrement,
    required this.onDecrement,
    required this.onCustomCompletion,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onStats,
    required this.weekStartsOnMonday,
    required this.currentDate,
  });

  @override
  State<_HabitCardWrapper> createState() => _HabitCardWrapperState();
}

class _HabitCardWrapperState extends State<_HabitCardWrapper> {
  int? _cachedCompletionCount;
  DateTime? _cachedSelectedDate; // CRITICAL: Must track this separately
  bool? _cachedWeekStartsOnMonday;
  Habit? _cachedHabitReference; // Use for reference comparison with identical()
  bool _isInitialized = false;

  @override
  void didUpdateWidget(_HabitCardWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Use identical() for reference comparison, NOT ==
    // Habit.operator == compares by ID, not reference
    if (!identical(oldWidget.habit, widget.habit)) {
      // Habit reference changed - force rebuild to update cache
      setState(() {});
    }

    // Also check if week preference or currentDate changed
    if (oldWidget.weekStartsOnMonday != widget.weekStartsOnMonday ||
        oldWidget.currentDate != widget.currentDate) {
      setState(() {}); // Force rebuild for week-related changes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, DateTime>(
      selector: (context, appState) => appState.currentDate,
      builder: (context, currentDate, child) {
        final appState = Provider.of<AppState>(
          context,
          listen: false,
        );

        // Use app state's current date for completion count checks
        // This is the date the app is currently viewing (virtual or system)
        // Use widget.currentDate for week calculations (from VirtualDateService)
        // This is the date used for week boundary calculations
        final currentDateForWeeks = widget.currentDate;

        // Always get updated habit from provider (source of truth)
        final updatedHabit = appState.habitProvider.habits.firstWhere(
          (h) => h.id == widget.habit.id,
          orElse: () => widget.habit, // Fallback to widget.habit if not found
        );

        // Get completion count for current date
        final completionCount = updatedHabit.getCompletionCount(currentDate);

        // Check ALL changes using proper comparison methods
        final habitReferenceChanged = !identical(
          _cachedHabitReference,
          updatedHabit,
        );
        final completionCountChanged =
            _cachedCompletionCount != completionCount;
        final currentDateChanged = _cachedSelectedDate != currentDate;
        final weekPrefChanged =
            _cachedWeekStartsOnMonday != widget.weekStartsOnMonday;

        final hasChanged =
            !_isInitialized ||
            habitReferenceChanged ||
            completionCountChanged ||
            currentDateChanged ||
            weekPrefChanged;

        if (!hasChanged) {
          return child!; // Return cached widget
        }

        // Update ALL cache fields with latest values from provider
        _cachedCompletionCount = completionCount;
        _cachedSelectedDate = currentDate;
        _cachedWeekStartsOnMonday = widget.weekStartsOnMonday;
        _cachedHabitReference =
            updatedHabit; // CRITICAL: Cache provider's habit, not widget.habit
        _isInitialized = true;

        // Create new HabitCard with updated data
        return HabitCard(
          key: ValueKey(widget.habit.id),
          habit: updatedHabit, // Use updated habit from provider
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onReorder: widget.onReorder,
          onComplete: widget.onComplete,
          onIncrement: widget.onIncrement,
          onDecrement: widget.onDecrement,
          onCustomCompletion: widget.onCustomCompletion,
          onEdit: widget.onEdit,
          onArchive: widget.onArchive,
          onDelete: widget.onDelete,
          onStats: widget.onStats,
          weekStartsOnMonday: widget.weekStartsOnMonday,
          currentDate:
              currentDateForWeeks, // Use VirtualDateService date for week calculations
        );
      },
      child: HabitCard(
        key: ValueKey(widget.habit.id),
        habit: widget.habit,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onReorder: widget.onReorder,
        onComplete: widget.onComplete,
        onIncrement: widget.onIncrement,
        onDecrement: widget.onDecrement,
        onCustomCompletion: widget.onCustomCompletion,
        onEdit: widget.onEdit,
        onArchive: widget.onArchive,
        onDelete: widget.onDelete,
        onStats: widget.onStats,
        weekStartsOnMonday: widget.weekStartsOnMonday,
        currentDate: widget.currentDate,
      ),
    );
  }
}
