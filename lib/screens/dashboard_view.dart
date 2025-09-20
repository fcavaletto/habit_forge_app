import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/app_state_provider.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/habit_card.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/constants.dart';
import '../screens/settings_screen.dart';
import '../screens/add_habit_screen.dart';
import '../screens/calendar_screen.dart';
import '../utils/data_freshness.dart';

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
/// 5. **Navigation**: Access calendar, settings, and habit creation
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState = context.read<AppState>();
    _controller = DashboardController(_appState);
    // Schedule initial data load after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
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
    final now = DateTime.now();
    // Check if data needs refresh based on time elapsed or new day
    final shouldRefresh = _lastResumeTime == null || 
      DataFreshness.shouldRefreshOnResume(_lastResumeTime!);
    
    debugPrint('🔄 Dashboard: App resumed, shouldRefresh: $shouldRefresh');
    
    // Only refresh if data is stale to avoid unnecessary operations
    if (shouldRefresh) {
      debugPrint('🔄 Dashboard: Triggering data refresh');
      _refreshData();
    }
    
    // Update resume timestamp for future freshness checks
    _lastResumeTime = now;
  }

  Future<void> _loadInitialData() async {
    await _controller.loadHabits();
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
    return Consumer<AppState>(
      builder: (context, appState, child) {
        debugPrint('🎨 Consumer<AppState> builder called with ${appState.habits.length} habits');
        return Semantics(
          label: 'Habit Forge Dashboard',
          hint: 'Main screen showing your habits and progress',
          child: Scaffold(
            appBar: _buildAppBar(appState),
            body: _buildBody(appState),
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
        // Calendar navigation button
        Semantics(
          label: 'Calendar view',
          hint: 'Navigate to calendar to view habit progress over time',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _navigateToCalendar(),
            tooltip: 'View Calendar',
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

  Widget _buildBody(AppState appState) {
    debugPrint('🔄 DashboardView building with ${appState.habits.length} habits');

    if (appState.isLoadingHabits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appState.habits.isEmpty) {
      debugPrint('📭 No habits found, showing empty state');
      return _buildEmptyState();
    }

    debugPrint('📊 Building habits list with drag-and-drop capability');
    return _buildHabitsList(appState.habits);
  }

  Widget _buildEmptyState() {
    return SafeScrollableWrapper(
      child: Center(
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
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          sliver: SliverToBoxAdapter(
            child: _buildHeader(habits),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
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
                  child: _buildHabitCard(habit),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitCard(Habit habit) {
    // Extract to separate method for better performance
    // This allows Flutter to optimize widget rebuilding
    return HabitCard(
      key: ValueKey(habit.id), // Stable key for performance
      habit: habit,
      onTap: () => _onHabitTap(habit),
      onComplete: () => _onMarkCompleted(habit),
      onIncrement: () => _onIncrementCompletion(habit),
      onDecrement: () => _onDecrementCompletion(habit),
      onEdit: () => _showHabitDetails(habit),
      onArchive: () => _onArchiveHabit(habit),
      onDelete: () => _onDeleteHabit(habit),
    );
  }

  Widget _buildHeader(List<Habit> habits) {
    final completedToday = _controller.getCompletedTodayCount();
    final completionRate = _controller.getTodayCompletionRate();

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
        // Show completion count text if enabled in settings
        Consumer<AppState>(
          builder: (context, appState, child) {
            if (appState.showCompletionCount) {
              return Column(
                children: [
                  Text(
                    '$completedToday of ${habits.length} habits completed',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
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
          '${(completionRate * 100).round()}% complete',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
      ],
    );
  }


  void _navigateToCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CalendarScreen(),
      ),
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
            _controller.loadHabits();
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
    final today = DateTime.now();
    final currentCount = habit.getCompletionCount(today);
    await _controller.onMarkCompleted(habit, currentCount + 1);
  }

  Future<void> _onDecrementCompletion(Habit habit) async {
    final today = DateTime.now();
    final currentCount = habit.getCompletionCount(today);
    if (currentCount > 0) {
      await _controller.onMarkCompleted(habit, currentCount - 1);
    }
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
          child: DetailedHabitCard(
            habit: habit,
            onClose: () => Navigator.of(context).pop(),
          ),
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


  /// Reorder habits
  void _reorderHabits(String draggedId, int newPosition) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.habitProvider.reorderHabits(draggedId, newPosition);
  }
}
