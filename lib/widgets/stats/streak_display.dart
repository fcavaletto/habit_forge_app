import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Streak Display Widget
///
/// Shows the current and longest streaks for a habit.
/// Provides visual representation of habit consistency and achievement.
/// Displays the current streak calculation mode for user awareness.
/// Shows tooltip with date range for longest streak on tap.
class StreakDisplay extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final String streakCalculationMode;
  final DateTime? longestStreakStartDate;
  final DateTime? longestStreakEndDate;

  const StreakDisplay({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.streakCalculationMode,
    this.longestStreakStartDate,
    this.longestStreakEndDate,
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
              'Streaks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Calculation: $streakCalculationMode',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildStreakCard(
                      context: context,
                      title: 'Current Streak',
                      value: currentStreak,
                      icon: Icons.local_fire_department,
                      color: colorScheme.primary,
                      subtitle: _getStreakSubtitle(currentStreak),
                    ),
                  ),
                  const SizedBox(width: AppConstants.defaultMargin),
                  Expanded(
                    child: _buildStreakCard(
                      context: context,
                      title: 'Longest Streak',
                      value: longestStreak,
                      icon: Icons.emoji_events,
                      color: colorScheme.secondary,
                      subtitle: 'Personal best',
                      showTooltip: true,
                      tooltipText: _getLongestStreakTooltip(),
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

  Widget _buildStreakCard({
    required BuildContext context,
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool showTooltip = false,
    String? tooltipText,
  }) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: AppConstants.iconSizeLarge,
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (showTooltip && tooltipText != null && tooltipText.isNotEmpty) {
      return Tooltip(
        message: tooltipText,
        preferBelow: false,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
        child: cardContent,
      );
    }

    return cardContent;
  }

  String _getStreakSubtitle(int streak) {
    if (streak == 0) {
      return 'Start today!';
    } else if (streak == 1) {
      return 'Keep it going!';
    } else if (streak < 7) {
      return 'Building momentum';
    } else if (streak < 30) {
      return 'Great progress!';
    } else if (streak < 100) {
      return 'Amazing dedication!';
    } else {
      return 'Legendary streak!';
    }
  }

  String _getLongestStreakTooltip() {
    if (longestStreak == 0) {
      return 'No streak recorded yet';
    }
    
    if (longestStreakStartDate == null || longestStreakEndDate == null) {
      return 'Longest streak: $longestStreak days';
    }
    
    final startFormatted = _formatDate(longestStreakStartDate!);
    final endFormatted = _formatDate(longestStreakEndDate!);
    
    if (longestStreakStartDate!.year == longestStreakEndDate!.year &&
        longestStreakStartDate!.month == longestStreakEndDate!.month &&
        longestStreakStartDate!.day == longestStreakEndDate!.day) {
      return 'Longest streak: $longestStreak days\nDate: $startFormatted';
    }
    
    return 'Longest streak: $longestStreak days\nFrom: $startFormatted\nTo: $endFormatted';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
