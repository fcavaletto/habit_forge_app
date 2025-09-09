import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../widgets/stats/completion_chart.dart';
import '../widgets/stats/streak_display.dart';
import '../widgets/stats/weekly_overview.dart';
import '../widgets/stats/monthly_calendar.dart';
import '../utils/constants.dart';
import '../utils/icon_utils.dart';

/// Stats Screen - Displays analytics and charts for habit tracking
///
/// Shows comprehensive statistics including:
/// - Completion streaks with motivational messages
/// - 30-day completion rate chart with interactive tooltips
/// - Weekly overview with visual completion indicators
/// - Monthly calendar with horizontal scrolling navigation
/// - Today highlighting and completion status visualization
class StatsScreen extends StatefulWidget {
  final Habit habit;

  const StatsScreen({
    super.key,
    required this.habit,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<DateTime, int> _completions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabitData();
  }

  /// Loads habit data including completion history
  /// Handles loading states and error scenarios
  Future<void> _loadHabitData() async {
    setState(() => _isLoading = true);
    try {
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      final habit = habitProvider.getHabitById(widget.habit.id) ?? widget.habit;
      setState(() {
        _completions = habit.completions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Don't show error message in initState to avoid ScaffoldMessenger issues
      debugPrint('Error loading habit data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Habit Header
                  _buildHabitHeader(),
                  const SizedBox(height: 24),

                  // Current Streak
                  StreakDisplay(
                    currentStreak: _calculateCurrentStreak(),
                    longestStreak: _calculateLongestStreak(),
                  ),
                  const SizedBox(height: 24),

                  // Completion Rate Chart
                  CompletionChart(completionData: _getLast30DaysData()),
                  const SizedBox(height: 24),

                  // Weekly Overview
                  WeeklyOverview(weeklyData: _getWeeklyData()),
                  const SizedBox(height: 24),

                  // Monthly Calendar
                  MonthlyCalendar(completions: _completions),
                ],
              ),
            ),
    );
  }

  /// Builds the habit header card with icon and basic information
  Widget _buildHabitHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Container(
              width: AppConstants.iconSizeLarge,
              height: AppConstants.iconSizeLarge,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              ),
              child: Icon(
                widget.habit.iconName.toIconData,
                color: Theme.of(context).colorScheme.primary,
                size: AppConstants.iconSizeMedium,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.habit.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.habit.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculates completion rate data points for the last 30 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  /// The chart shows daily completion percentage based on the habit's target goal.
  List<double> _getLast30DaysData() {
    final data = <double>[];
    final now = DateTime.now();

    for (int i = AppConstants.chartDaysCount - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final completionCount = _completions[DateTime(date.year, date.month, date.day)] ?? 0;
      final rate = (completionCount / widget.habit.targetGoal).clamp(0.0, 1.0);
      data.add(rate);
    }

    return data;
  }

  /// Calculates weekly completion data for the current week
  ///
  /// Returns a list of boolean values representing goal achievement status
  /// for each day of the current week (Monday to Sunday).
  List<bool> _getWeeklyData() {
    final data = <bool>[];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < AppConstants.weeklyOverviewDays; i++) {
      final date = weekStart.add(Duration(days: i));
      final completionCount = _completions[DateTime(date.year, date.month, date.day)] ?? 0;
      data.add(completionCount >= widget.habit.targetGoal);
    }

    return data;
  }

  /// Calculates the current streak of consecutive goal-achieved days
  ///
  /// A streak continues as long as the habit achieves its goal each day.
  /// The streak breaks when a day's goal is not met, but can resume the next day.
  int _calculateCurrentStreak() {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final completionCount = _completions[DateTime(date.year, date.month, date.day)] ?? 0;

      if (completionCount >= widget.habit.targetGoal) {
        streak++;
      } else if (i == 0) {
        // Don't break streak for today if goal not achieved yet
        continue;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Calculates the longest streak of consecutive goal-achieved days
  ///
  /// This represents the personal best achievement for this habit.
  int _calculateLongestStreak() {
    int longestStreak = 0;
    int currentStreak = 0;

    final dates = _completions.keys.toList()..sort();

    for (final date in dates) {
      if ((_completions[date] ?? 0) >= widget.habit.targetGoal) {
        currentStreak++;
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return longestStreak;
  }

}