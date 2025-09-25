import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/habit.dart';
import '../../repositories/sqlite_habit_repository.dart';
import '../../services/database_service.dart';

/// Last 7 Days Overview Widget
///
/// Shows a visual representation of habit completion for the last 7 days.
/// Displays each day with completion status, partial completion visualization,
/// and day labels. Supports multi-goal habits with gradient fills.
class Last7DaysOverview extends StatelessWidget {
  final List<CompletionRecord?> weeklyData;
  final DateTime currentDate;
  final Map<DateTime, CompletionRecord>? completions; // Full completions map for timestamps
  final String habitId; // Habit ID for fetching completion timestamps

  const Last7DaysOverview({
    super.key,
    required this.weeklyData,
    required this.currentDate,
    this.completions,
    required this.habitId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 Days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(AppConstants.weeklyOverviewDays, (index) {
                final date = currentDate.subtract(Duration(days: 6 - index));
                final dayName = _getDayName(date);
                final record = index < weeklyData.length ? weeklyData[index] : null;

                return _buildDayIndicator(
                  context: context,
                  dayName: dayName,
                  record: record,
                  colorScheme: colorScheme,
                  date: date,
                );
              }),
            ),
            const SizedBox(height: 8),
            _buildWeeklySummary(context, weeklyData),
          ],
        ),
      ),
    );
  }

  Widget _buildDayIndicator({
    required BuildContext context,
    required String dayName,
    required CompletionRecord? record,
    required ColorScheme colorScheme,
    required DateTime date,
  }) {
    final hasCompletion = record != null && record.count > 0;
    final isFullyCompleted = record?.isGoalAchieved ?? false;
    final fillPercentage = record != null ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        GestureDetector(
          onTap: () async => await _showDayDetails(context, date, record),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isFullyCompleted
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: Border.all(
                color: hasCompletion
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              // Add gradient for partial completion
              gradient: hasCompletion && !isFullyCompleted && fillPercentage > 0
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        colorScheme.primary.withValues(alpha: fillPercentage.clamp(0.1, 1.0)), // Ensure minimum alpha
                        colorScheme.surfaceContainerHighest,
                      ],
                    )
                  : null,
            ),
            child: Icon(
              isFullyCompleted ? Icons.check : (hasCompletion ? Icons.close : Icons.close),
              color: isFullyCompleted
                  ? colorScheme.onPrimary
                  : hasCompletion
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.5),
              size: AppConstants.iconSizeMedium,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dayName,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySummary(BuildContext context, List<CompletionRecord?> weeklyData) {
    final fullyCompletedCount = weeklyData.where((record) => record?.isGoalAchieved ?? false).length;
    final totalDays = weeklyData.length;
    final completionRate = totalDays > 0 ? (fullyCompletedCount / totalDays * 100).round() : 0;
    
    // Check if any habit has a goal greater than 1
    final hasMultiGoalHabit = weeklyData.any((record) => record?.goalAtCompletion != null && record!.goalAtCompletion > 1);
    final messageText = hasMultiGoalHabit 
        ? '$fullyCompletedCount of $totalDays days fully completed ($completionRate%)'
        : '$fullyCompletedCount of $totalDays days completed ($completionRate%)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            messageText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return dayNames[date.weekday - 1]; // weekday is 1-7, array is 0-6
  }

  String _getFullDayName(DateTime date) {
    const fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return fullDayNames[date.weekday - 1]; // weekday is 1-7, array is 0-6
  }

  /// Show day details dialog
  Future<void> _showDayDetails(BuildContext context, DateTime date, CompletionRecord? record) async {
    final fullDayName = _getFullDayName(date);
    final dateStr = '${date.day} ${_getMonthAbbreviation(date.month)}';
    
    // Fetch completion timestamps for this day
    List<DateTime> completionTimes = [];
    if (record != null && record.count > 0) {
      try {
        final databaseService = DatabaseService();
        final repository = SqliteHabitRepository(databaseService);
        completionTimes = await repository.getCompletionTimestampsForDay(habitId, date);
      } catch (e) {
        debugPrint('❌ Error fetching completion times: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$fullDayName, $dateStr'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record != null) ...[
              Text('Goal: ${record.goalAtCompletion}'),
              Text('Completed: ${record.count}'),
              Text('Status: ${record.isGoalAchieved ? "Goal Achieved" : "Partial"}'),
              const SizedBox(height: 8),
              Text(
                'Completion Times:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              if (completionTimes.isNotEmpty) ...[
                ...completionTimes.map((time) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(
                    _formatTime(time),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                )),
              ] else ...[
                Text(
                  'No completion times available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ] else ...[
              Text('No completions recorded'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Get abbreviated month name from month number
  String _getMonthAbbreviation(int month) {
    const monthAbbreviations = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthAbbreviations[month];
  }

  /// Format time for display (24-hour format)
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
