import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Weekly Overview Widget
///
/// Shows a visual representation of habit completion for the current week.
/// Displays each day with completion status and day labels.
class WeeklyOverview extends StatelessWidget {
  final List<bool> weeklyData;
  final DateTime currentDate;

  const WeeklyOverview({
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
              'This Week',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(AppConstants.weeklyOverviewDays, (index) {
                final dayName = _getDayName(index);
                final isCompleted = index < weeklyData.length ? weeklyData[index] : false;

                return _buildDayIndicator(
                  context: context,
                  dayName: dayName,
                  isCompleted: isCompleted,
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
    required bool isCompleted,
    required ColorScheme colorScheme,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            border: Border.all(
              color: isCompleted
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.close,
            color: isCompleted
                ? colorScheme.onPrimary
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

  Widget _buildWeeklySummary(BuildContext context, List<bool> weeklyData) {
    final completedCount = weeklyData.where((completed) => completed).length;
    final totalDays = weeklyData.length;
    final completionRate = totalDays > 0 ? (completedCount / totalDays * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            completionRate >= 70
                ? Icons.thumb_up
                : completionRate >= 40
                    ? Icons.thumbs_up_down
                    : Icons.thumb_down,
            size: AppConstants.iconSizeSmall,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$completedCount of $totalDays days completed ($completionRate%)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int index) {
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return dayNames[index % dayNames.length];
  }
}
