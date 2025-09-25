import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/habit.dart';

/// Last 7 Days Overview Widget
///
/// Shows a visual representation of habit completion for the last 7 days.
/// Displays each day with completion status, partial completion visualization,
/// and day labels. Supports multi-goal habits with gradient fills.
class Last7DaysOverview extends StatelessWidget {
  final List<CompletionRecord?> weeklyData;
  final DateTime currentDate;

  const Last7DaysOverview({
    super.key,
    required this.weeklyData,
    required this.currentDate,
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
  }) {
    final hasCompletion = record != null && record.count > 0;
    final isFullyCompleted = record?.isGoalAchieved ?? false;
    final fillPercentage = record != null ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Container(
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
}
