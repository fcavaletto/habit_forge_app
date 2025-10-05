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
import '../widgets/stats/active_days_widget.dart';
import '../utils/constants.dart';
import '../providers/app_state_provider.dart';
import '../services/virtual_date_service.dart';
import '../theme.dart';

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
  String _selectedCompletionTimeRange = AppConstants.defaultCompletionTimeRange;
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
                  // Habit Header (now includes Active Days)
                  _buildHabitHeader(context),
                    const SizedBox(height: 24),

                    // Current Streak
                  Builder(
                    builder: (context) {
                      final longestStreakData = _calculateLongestStreakWithRange(completions, widget.habit.frequencyDays, appState.isActiveDaysStreakEnabled);
                      return StreakDisplay(
                        currentStreak: _calculateCurrentStreak(completions, currentDate, widget.habit.frequencyDays, appState.isActiveDaysStreakEnabled),
                        longestStreak: longestStreakData['streak'] as int,
                        streakCalculationMode: appState.streakCalculationMode,
                        longestStreakStartDate: longestStreakData['startDate'] as DateTime?,
                        longestStreakEndDate: longestStreakData['endDate'] as DateTime?,
                      );
                    },
                    ),
                    const SizedBox(height: 24),

                    // Completion Rate Chart
                  CompletionChart(
                    completionData: _getCompletionDataForRange(
                      _selectedCompletionTimeRange,
                      completions,
                      currentDate,
                    ),
                    currentDate: currentDate,
                    timeRange: _selectedCompletionTimeRange,
                    onTimeRangeChanged: (newRange) {
                      setState(() {
                        _selectedCompletionTimeRange = newRange;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // PRO Features Section (Last 7 Days onward)
                  _buildProFeaturesSection(context, appState, completions, currentDate),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the PRO features section with dimmed overlay when PRO is inactive
  Widget _buildProFeaturesSection(BuildContext context, AppState appState, Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final isProActive = appState.isProSubscriptionActive;
    
    return Stack(
      children: [
        // Content
        Column(
          children: [
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
        
        // Dimmed overlay when PRO is inactive
        if (!isProActive)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // PRO badge in top-right corner
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PRO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Positioned message (higher up)
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Advanced Analytics',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upgrade to PRO to access detailed statistics,\ncompletion patterns, and insights',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              // Navigate to settings to enable PRO
                              Navigator.of(context).pushNamed('/settings');
                            },
                            icon: const Icon(Icons.upgrade),
                            label: const Text('Upgrade to PRO'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
                color: Theme.of(context).colorScheme.habitColor(widget.habit.colorIndex),
                size: 36.0,
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
                  if (widget.habit.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.habit.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: 'Goal: ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: '${widget.habit.targetGoal}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Days:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActiveDaysWidget(
                    frequencyDays: widget.habit.frequencyDays,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculates completion rate data points for the last 7 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  List<double> _getLast7DaysCompletionData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = 6; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Calculates completion rate data points for the last 30 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  List<double> _getLast30DaysCompletionData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = 29; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Calculates completion rate data points for the last 365 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  /// Missing days are set to 0.0.
  List<double> _getLast365DaysCompletionData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = 364; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Gets completion data for the selected time range
  ///
  /// Returns completion rate data based on the currently selected time range.
  List<double> _getCompletionDataForRange(
    String timeRange,
    Map<DateTime, CompletionRecord> completions,
    DateTime currentDate,
  ) {
    switch (timeRange) {
      case 'Last 7 Days':
        return _getLast7DaysCompletionData(completions, currentDate);
      case 'Last 30 Days':
        return _getLast30DaysCompletionData(completions, currentDate);
      case 'Last 365 Days':
        return _getLast365DaysCompletionData(completions, currentDate);
      default:
        return _getLast30DaysCompletionData(completions, currentDate);
    }
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
  /// Supports two calculation modes:
  /// - All Days: Count consecutive days regardless of active days
  /// - Active Days Only: Count consecutive active days only
  ///
  /// A streak continues as long as the habit achieves its goal each day.
  /// The streak breaks when a day's goal is not met, but can resume the next day.
  int _calculateCurrentStreak(Map<DateTime, CompletionRecord> completions, DateTime currentDate, Map<String, int> frequencyDays, bool isActiveDaysOnly) {
    int streak = 0;
    DateTime checkDate = currentDate;

    // Edge case: No active days in active days mode
    if (isActiveDaysOnly && !_hasActiveDays(frequencyDays)) {
      return 0;
    }

    // Count consecutive goal-achieved days backward from current date
    while (true) {
      final dayKey = DateTime(checkDate.year, checkDate.month, checkDate.day);
      final weekday = _getWeekdayKey(checkDate.weekday);
      
      // Check if this day is active (only relevant for active days mode)
      final isActiveDay = frequencyDays[weekday] == 1;
      
      if (isActiveDaysOnly && !isActiveDay) {
        // Skip inactive days in active days mode
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      
      final record = completions[dayKey];
      
      if (record != null && record.isGoalAchieved) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (checkDate.year == currentDate.year && 
                 checkDate.month == currentDate.month && 
                 checkDate.day == currentDate.day) {
        // Don't break streak for today if goal not achieved yet
        break;
      } else {
        break;
      }
    }

    return streak;
  }


  /// Calculates the longest streak with its date range
  ///
  /// Returns a map containing both the streak count and the date range.
  /// Used for displaying detailed information in tooltips.
  Map<String, dynamic> _calculateLongestStreakWithRange(Map<DateTime, CompletionRecord> completions, Map<String, int> frequencyDays, bool isActiveDaysOnly) {
    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? longestStreakStart;
    DateTime? longestStreakEnd;
    DateTime? currentStreakStart;

    // Edge case: No active days in active days mode
    if (isActiveDaysOnly && !_hasActiveDays(frequencyDays)) {
      return {
        'streak': 0,
        'startDate': null,
        'endDate': null,
      };
    }

    // Get the date range to check (from earliest completion to latest)
    if (completions.isEmpty) {
      return {
        'streak': 0,
        'startDate': null,
        'endDate': null,
      };
    }

    final dates = completions.keys.toList()..sort();
    final startDate = dates.first;
    final endDate = dates.last;

    // Check consecutive days from start to end
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final weekday = _getWeekdayKey(currentDate.weekday);
      final isActiveDay = frequencyDays[weekday] == 1;
      
      // Skip inactive days in active days mode
      if (isActiveDaysOnly && !isActiveDay) {
        currentStreak = 0; // Reset streak when encountering inactive day
        currentStreakStart = null;
        currentDate = currentDate.add(const Duration(days: 1));
        continue;
      }
      
      final record = completions[currentDate];
      if (record != null && record.isGoalAchieved) {
        if (currentStreak == 0) {
          currentStreakStart = currentDate; // Start of new streak
        }
        currentStreak++;
        
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
          longestStreakStart = currentStreakStart;
          longestStreakEnd = currentDate;
        }
      } else {
        currentStreak = 0;
        currentStreakStart = null;
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return {
      'streak': longestStreak,
      'startDate': longestStreakStart,
      'endDate': longestStreakEnd,
    };
  }

  /// Helper method to check if habit has any active days
  bool _hasActiveDays(Map<String, int> frequencyDays) {
    return frequencyDays.values.any((value) => value == 1);
  }

  /// Helper method to get weekday key from DateTime weekday
  String _getWeekdayKey(int weekday) {
    const weekdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    return weekdays[weekday % 7];
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