import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/habit.dart';
import '../providers/app_state_provider.dart';
import '../providers/habit_provider.dart';
import '../controllers/dashboard_controller.dart';
import '../services/virtual_date_service.dart';
import '../widgets/habit_card_variant2.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../widgets/current_time_clock.dart';
import '../utils/constants.dart';
import '../screens/settings_screen.dart';
import '../screens/add_habit_screen.dart';
import 'stats_screen.dart';
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
class DashboardViewVariant2 extends StatefulWidget {
  const DashboardViewVariant2({super.key});

  @override
  State<DashboardViewVariant2> createState() => _DashboardViewVariant2State();
}

class _DashboardViewVariant2State extends State<DashboardViewVariant2> 
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
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final delay = nextMinute.difference(now);
    
    debugPrint('🕐 Clock timer: Next update in ${delay.inSeconds} seconds (at ${nextMinute.hour}:${nextMinute.minute.toString().padLeft(2, '0')})');
    
    // First timer: wait until the next minute boundary
    Timer(delay, () {
      if (mounted && !_appState.isTimeOverridden && _appState.showTimeOverride) {
        setState(() {
          // Force rebuild to update the clock display
        });
      }
      
      // Then start the regular minute timer
      _clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (mounted && !_appState.isTimeOverridden && _appState.showTimeOverride) {
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
      selector: (context, appState) => appState.habitProvider.filteredHabits.length,
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
      title: const Text('Dashboard 2'),
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
    // Use Consumer<HabitProvider> to listen only to habit list changes
    // This prevents rebuilding when individual habit completions change
    return Consumer<HabitProvider>(
      builder: (context, habitProvider, child) {
        final filteredHabits = habitProvider.filteredHabits;
        debugPrint('🔄 Optimized DashboardView building with ${filteredHabits.length} filtered habits');

        // No loading spinner - data is preloaded before UI shows
        // Background refresh happens silently without loading states

        if (filteredHabits.isEmpty) {
          debugPrint('📭 No habits found for selected date, showing empty state');
          return _buildEmptyState(isFiltered: true);
        }

        debugPrint('📊 Building habits list with selective rebuilds');
        return _buildHabitsList(filteredHabits);
      },
    );
  }

  /// Builds empty state UI when no habits are found
  /// 
  /// Displays appropriate messaging and sample habit creation options
  /// for both filtered and unfiltered empty states.
  Widget _buildEmptyState({bool isFiltered = false}) {
    return SafeScrollableWrapper(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFiltered ? Icons.calendar_today : Icons.track_changes,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              Text(
                isFiltered ? 'No habits scheduled for today' : 'Welcome to Habit Forge!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isFiltered 
                  ? 'No habits are scheduled to be completed on the selected date. Try selecting a different date or create habits for this day.'
                  : 'Build lasting habits with daily tracking and progress visualization.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.defaultPadding * 2),
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
          ),
        ),
      ),
    );
  }

  Widget _buildHabitsList(List<Habit> habits) {
    return SafeCustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            10, // left padding,
            12, // top padding
            10, // right padding
            0, // bottom padding
          ),
          sliver: SliverToBoxAdapter(
            child: _buildHeader(habits),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          sliver: SliverToBoxAdapter(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: habits.length,
              onReorder: (oldIndex, newIndex) {
                // Handle the reordering logic
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                _reorderHabits(habits[oldIndex].id, newIndex);
              },
              itemBuilder: (context, index) {
                final habit = habits[index];
                return Container(
                  key: ValueKey(habit.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _buildSelectiveHabitCard(habit),
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
  Widget _buildSelectiveHabitCard(Habit habit) {
    // Use RepaintBoundary to isolate repaints and implement true selective rebuilds
    return RepaintBoundary(
      child: _HabitCardWrapperVariant2(
        habit: habit,
        onTap: () => _onHabitTap(habit),
        onComplete: () => _onMarkCompleted(habit),
        onIncrement: () => _onIncrementCompletion(habit),
        onDecrement: () => _onCompletionButtonPress(habit),
        onCustomCompletion: () => _onCustomCompletion(habit),
        onEdit: () => _showHabitDetails(habit),
        onArchive: () => _onArchiveHabit(habit),
        onDelete: () => _onDeleteHabit(habit),
        onStats: () => _showHabitStats(habit),
      ),
    );
  }

  /// Builds the dashboard header with habit statistics
  /// 
  /// Displays completion counts, progress indicators, and summary
  /// information for the current habit list.
  Widget _buildHeader(List<Habit> habits) {
    // Get the provider state
    final appState = Provider.of<AppState>(context, listen: false);
    final selectedDate = appState.habitProvider.selectedDate;
    final isShowingAllHabits = appState.habitProvider.isShowingAllHabits;
    
    // Calculate completion count and rate based on filter mode
    final completedCount = isShowingAllHabits 
        ? _controller.getCompletedCountForAllHabits()
        : _controller.getCompletedCountForDate(selectedDate);
    final completionRate = isShowingAllHabits
        ? _controller.getCompletionRateForAllHabits()
        : _controller.getCompletionRateForDate(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date selector - Use Selector to only rebuild when selected date changes
        Selector<AppState, DateTime>(
          selector: (context, appState) => appState.habitProvider.selectedDate,
          builder: (context, selectedDate, child) {
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
            return showTimeOverride ? const SizedBox(height: 12) : const SizedBox.shrink();
          },
        ),
        // Habit filter dropdown - Use Selector to only rebuild when filter changes
        Selector<AppState, bool>(
          selector: (context, appState) => appState.habitProvider.isShowingAllHabits,
          builder: (context, isShowingAll, child) {
            final appState = context.read<AppState>();
            return _buildHabitFilterDropdown(appState);
          },
        ),
        const SizedBox(height: 8),
        // Progress bar is now always visible
        LinearProgressIndicator(
          value: completionRate,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          child: DetailedHabitCardVariant2(
            habit: habit,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  void _showHabitStats(Habit habit) {
    // Get fresh habit data from the provider to ensure we have the latest completions
    final appState = Provider.of<AppState>(context, listen: false);
    final freshHabit = appState.habitProvider.getHabitById(habit.id) ?? habit;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatsScreen(habit: freshHabit),
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
        final colorPair = colorScheme.habitColorPairs[19-i];
        final randomIcon = IconSelector.availableIcons[random.nextInt(IconSelector.availableIcons.length)];
        
        final habit = Habit.createWithUuid(
          name: 'Title: color #${19 - i + 1}',
          description: 'Test habit with color ${19 - i + 1}',
          lightColorValue: colorPair.light.toARGB32(),
          darkColorValue: colorPair.dark.toARGB32(),
          iconName: randomIcon,
          reminderTime: null,
          enableReminders: false,
          frequencyDays: const {
            'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1
          }, // Every day
          targetGoal: 20-i,
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


  /// Reorder habits with filtering context
  void _reorderHabits(String draggedId, int newPosition) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Get visible habit IDs for filtering context
    final visibleHabitIds = appState.habitProvider.getVisibleHabitIds();
    
    // Use the new filtering-aware reordering method
    appState.habitProvider.reorderHabitsInContext(draggedId, newPosition, visibleHabitIds);
  }

  /// Build the date selector widget
  Widget _buildDateSelector(AppState appState) {
    final selectedDate = appState.habitProvider.selectedDate;
    final isDateOverridden = appState.isDateOverridden;

    // Theme-based border width
    final borderWidth = Theme.of(context).brightness == Brightness.light 
        ? 1.0  // Light theme: more prominent borders
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
                  ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 1)
                  : Theme.of(context).colorScheme.surfaceContainerHighest) // No background color change in dark mode
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
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(selectedDate),
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
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
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
        ? 1.0  // Light theme: more prominent borders
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
                  ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 1)
                  : Theme.of(context).colorScheme.surfaceContainerHighest) // No background color change in dark mode
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
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                isTimeOverridden
                    ? Text(
                        _formatTime(appState.currentTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : CurrentTimeClock(
                        isTimeOverridden: isTimeOverridden,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
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
                side: BorderSide(color: Theme.of(context).colorScheme.error),
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
            tooltip: isTimeOverridden ? 'Change Override Time' : 'Set Time Override',
          ),
        ],
      ),
        ),
      ),
    );
  }

  /// Get completion message based on habit goals
  String _getCompletionMessage(double completionRate, int completedCount, int totalHabits) {
    final percentage = (completionRate * 100).round();
    
    // Check if any habits have goals greater than 1
    final hasMultiGoalHabits = _appState.habits.any((habit) => habit.targetGoal > 1);
    
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  /// Format time for display in 24-hour format
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Show date picker dialog
  Future<void> _showDatePicker(AppState appState) async {
    final selectedDate = appState.habitProvider.selectedDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
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

    if (pickedDate != null && pickedDate != selectedDate) {
      appState.habitProvider.updateSelectedDate(pickedDate);
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

  /// Build habit filter dropdown (Today's Habits vs All Habits)
  Widget _buildHabitFilterDropdown(AppState appState) {
    final isShowingAllHabits = appState.habitProvider.isShowingAllHabits;
    
    // Theme-based border width
    final borderWidth = Theme.of(context).brightness == Brightness.light 
        ? 1.0  // Light theme: more prominent borders
        : 0.5; // Dark theme: subtle borders
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            Theme.of(context).colorScheme.outline.withValues(alpha: 1.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(11.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.view_list,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Habit Filter',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          DropdownButton<String>(
            value: isShowingAllHabits ? 'all' : 'today',
            onChanged: (String? newValue) {
              if (newValue != null) {
                appState.habitProvider.setShowAllHabits(newValue == 'all');
              }
            },
            underline: Container(), // Remove default underline
            icon: Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.primary,
            ),
            items: const [
              DropdownMenuItem(
                value: 'today',
                child: Text('Today\'s Habits'),
              ),
              DropdownMenuItem(
                value: 'all',
                child: Text('All Habits'),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// Wrapper widget that implements true selective rebuilds for individual habit cards
/// 
/// This widget uses a custom approach to only rebuild when the specific habit
/// data changes, avoiding unnecessary rebuilds of other habit cards.
class _HabitCardWrapperVariant2 extends StatefulWidget {
  final Habit habit;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onCustomCompletion;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onStats;

  const _HabitCardWrapperVariant2({
    required this.habit,
    required this.onTap,
    required this.onComplete,
    required this.onIncrement,
    required this.onDecrement,
    required this.onCustomCompletion,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onStats,
  });

  @override
  State<_HabitCardWrapperVariant2> createState() => _HabitCardWrapperVariant2State();
}

class _HabitCardWrapperVariant2State extends State<_HabitCardWrapperVariant2> {
  int? _cachedCompletionCount;
  DateTime? _cachedDate;
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (context, habitProvider, child) {
        final currentDate = habitProvider.selectedDate;
        
        // Get the updated habit object from provider instead of using stale widget.habit
        final updatedHabit = habitProvider.habits.firstWhere(
          (h) => h.id == widget.habit.id,
          orElse: () => widget.habit, // Fallback to widget.habit if not found
        );
        
        // Get completion count directly from cache without FutureBuilder
        final currentCompletionCount = habitProvider.getCachedCompletionCountSync(widget.habit.id, currentDate) ?? 
            updatedHabit.getCompletionCount(currentDate);
        
        // Check if this specific habit actually changed
        final hasChanged = !_isInitialized ||
            _cachedCompletionCount != currentCompletionCount ||
            _cachedDate != currentDate;
        
        if (!hasChanged) {
          return child!; // Return cached widget
        }
        
        // Update cache
        _cachedCompletionCount = currentCompletionCount;
        _cachedDate = currentDate;
        _isInitialized = true;
        
        return HabitCardVariant2(
          key: ValueKey(widget.habit.id),
          habit: updatedHabit, // Use updated habit object
          onTap: widget.onTap,
          onComplete: widget.onComplete,
          onIncrement: widget.onIncrement,
          onDecrement: widget.onDecrement,
          onCustomCompletion: widget.onCustomCompletion,
          onEdit: widget.onEdit,
          onArchive: widget.onArchive,
          onDelete: widget.onDelete,
          onStats: widget.onStats,
        );
      },
      child: HabitCardVariant2(
        key: ValueKey(widget.habit.id),
        habit: widget.habit,
        onTap: widget.onTap,
        onComplete: widget.onComplete,
        onIncrement: widget.onIncrement,
        onDecrement: widget.onDecrement,
        onCustomCompletion: widget.onCustomCompletion,
        onEdit: widget.onEdit,
        onArchive: widget.onArchive,
        onDelete: widget.onDelete,
        onStats: widget.onStats,
      ),
    );
  }
}
