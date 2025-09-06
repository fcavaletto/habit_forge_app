import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/app_state_provider.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/habit_card.dart';
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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _controller.loadHabits();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(appState),
          floatingActionButton: _buildFloatingActionButton(),
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
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _navigateToCalendar(),
          tooltip: 'View Calendar',
        ),
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettings(),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildBody(AppState appState) {
    if (appState.isLoadingHabits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appState.habits.isEmpty) {
      return _buildEmptyState();
    }

    return _buildHabitsGrid(appState.habits);
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
    );
  }

  Widget _buildHabitsGrid(List<Habit> habits) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          sliver: SliverToBoxAdapter(
            child: _buildHeader(habits),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final habit = habits[index];
                return HabitCard(
                  habit: habit,
                  onTap: () => _onHabitTap(habit),
                  onComplete: () => _onMarkCompleted(habit),
                  onEdit: () => _showHabitDetails(habit),
                  onArchive: () => _onArchiveHabit(habit),
                  onDelete: () => _onDeleteHabit(habit),
                );
              },
              childCount: habits.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<Habit> habits) {
    final completedToday = _controller.getCompletedTodayCount();
    final completionRate = habits.isNotEmpty ? completedToday / habits.length : 0.0;

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
    return FloatingActionButton(
      onPressed: _showAddHabitDialog,
      tooltip: 'Add New Habit',
      child: const Icon(Icons.add),
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
          currentThemeMode: ThemeMode.system, // TODO: Get from theme provider
          onThemeChanged: (mode) {}, // TODO: Implement theme change
          onAddSampleHabits: () => _controller.addSampleHabits(context),
          onRetrieveArchivedHabits: () => _controller.retrieveArchivedHabits(context),
        ),
      ),
    );
  }

  void _showAddHabitDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitScreen(
        onHabitAdded: (habit) => _controller.loadHabits(),
        existingHabits: _controller.habits,
      ),
    );
  }

  void _onHabitTap(Habit habit) {
    _controller.onHabitTap(context, habit);
  }

  Future<void> _onMarkCompleted(Habit habit) async {
    await _controller.onMarkCompleted(habit);
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
