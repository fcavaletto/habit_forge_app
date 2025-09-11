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

/// Dashboard View - Pure UI component for the dashboard screen
///
/// This widget contains only the UI rendering logic and delegates all
/// business logic to the DashboardController. It uses Provider to access
/// the app state and controller.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late DashboardController _controller;
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
    _controller = DashboardController(_appState);
    // Schedule initial data load after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    await _controller.loadHabits();
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
            appBar: _buildAppBar(),
            body: _buildBody(appState),
            floatingActionButton: _buildFloatingActionButton(),
          ),
        );
      },
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
        // Settings button
        Semantics(
          label: 'Settings',
          hint: 'Open app settings and preferences',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(),
            tooltip: 'Settings',
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

    debugPrint('📊 Building habits list with ${appState.habits.length} habits');
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
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final habit = habits[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _buildHabitCard(habit),
                );
              },
              childCount: habits.length,
              // Add performance optimizations
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
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
        Text(
          '$completedToday of ${habits.length} habits completed',
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

  Widget _buildFloatingActionButton() {
    return Semantics(
      label: 'Add new habit',
      hint: 'Opens form to create a new habit',
      button: true,
      child: FloatingActionButton(
        onPressed: _showAddHabitDialog,
        tooltip: 'Add New Habit',
        child: const Icon(Icons.add),
      ),
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
}
