import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../widgets/stats/completion_chart.dart';
import '../widgets/stats/streak_display.dart';
import '../widgets/stats/last_7_days_overview.dart';
import '../widgets/stats/monthly_calendar.dart';
import '../widgets/stats/hourly_histogram.dart';
import '../utils/constants.dart';
import '../providers/app_state_provider.dart';
import '../services/virtual_date_service.dart';

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
  String _selectedTimeRange = 'Last 30 Days';
  HourlyHistogramData? _hourlyData;
  bool _isLoadingHourlyData = false;
  String? _hourlyDataError;

  @override
  void initState() {
    super.initState();
    _loadHourlyData();
  }

  @override
  void didUpdateWidget(StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habit.id != widget.habit.id) {
      _loadHourlyData();
    }
  }

  Future<void> _loadHourlyData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingHourlyData = true;
      _hourlyDataError = null;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentDate = VirtualDateService().currentDate;
      
      final data = await appState.habitProvider.loadHourlyData(
        widget.habit.id,
        _selectedTimeRange,
        currentDate,
      );
      
      if (mounted) {
        setState(() {
          _hourlyData = data;
          _isLoadingHourlyData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hourlyDataError = e.toString();
          _isLoadingHourlyData = false;
        });
      }
    }
  }

  void _onTimeRangeChanged(String newRange) {
    if (newRange != _selectedTimeRange) {
      setState(() {
        _selectedTimeRange = newRange;
      });
      _loadHourlyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
        builder: (context, appState, child) {
          final currentDate = VirtualDateService().currentDate;
          final completions = widget.habit.completions;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Statistics'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          body: SafeScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Habit Header
                  _buildHabitHeader(context),
                  const SizedBox(height: 24),

                  // Current Streak
                  StreakDisplay(
                    currentStreak: _calculateCurrentStreak(completions, currentDate),
                    longestStreak: _calculateLongestStreak(completions),
                  ),
                  const SizedBox(height: 24),

                  // Completion Rate Chart
                  CompletionChart(
                    completionData: _getLast30DaysData(completions, currentDate),
                    currentDate: currentDate,
                  ),
                  const SizedBox(height: 24),

                  // Last 7 Days Overview
                  Last7DaysOverview(
                    weeklyData: _getLast7DaysData(completions, currentDate),
                    currentDate: currentDate,
                    completions: completions,
                    habitId: widget.habit.id,
                  ),
                  const SizedBox(height: 24),

                  // Hourly Completion Histogram
                  if (_hourlyData != null)
                    HourlyHistogram(
                      data: _hourlyData!,
                      onTimeRangeChanged: _onTimeRangeChanged,
                    )
                  else if (_isLoadingHourlyData)
                    _buildHistogramLoadingState()
                  else if (_hourlyDataError != null)
                    _buildHistogramErrorState()
                  else
                    _buildHistogramEmptyState(),
                  const SizedBox(height: 24),

                  // Monthly Calendar
                  MonthlyCalendar(
                    completions: completions,
                    currentDate: currentDate,
                    habitId: widget.habit.id,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the habit header card with icon and basic information
  Widget _buildHabitHeader(BuildContext context) {
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
  List<double> _getLast30DaysData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = AppConstants.chartDaysCount - 1; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Calculates last 7 days completion data
  ///
  /// Returns a list of CompletionRecord objects representing completion status
  /// for each of the last 7 days (including today).
  List<CompletionRecord?> _getLast7DaysData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <CompletionRecord?>[];

    for (int i = 6; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];
      data.add(record);
    }

    return data;
  }

  /// Calculates the current streak of consecutive goal-achieved days
  ///
  /// A streak continues as long as the habit achieves its goal each day.
  /// The streak breaks when a day's goal is not met, but can resume the next day.
  int _calculateCurrentStreak(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];

      if (record != null && record.isGoalAchieved) {
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
  int _calculateLongestStreak(Map<DateTime, CompletionRecord> completions) {
    int longestStreak = 0;
    int currentStreak = 0;

    final dates = completions.keys.toList()..sort();

    for (final date in dates) {
      final record = completions[date];
      if (record != null && record.isGoalAchieved) {
        currentStreak++;
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return longestStreak;
  }

  /// Builds loading state for histogram
  Widget _buildHistogramLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Completions throughout the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds error state for histogram
  Widget _buildHistogramErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Completions throughout the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load data',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _loadHourlyData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds empty state for histogram
  Widget _buildHistogramEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Completions throughout the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No completion data available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete your habit to see hourly patterns',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}