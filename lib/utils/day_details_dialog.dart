import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../repositories/sqlite_habit_repository.dart';
import '../services/database_service.dart';

/// Shared utility for displaying day details dialogs
///
/// Provides a consistent dialog interface for showing completion details
/// across different widgets (Last 7 Days, Monthly Calendar, etc.)
class DayDetailsDialog {
  /// Show day details dialog with completion information
  ///
  /// @param context The build context
  /// @param date The date to show details for
  /// @param record The completion record for that date (can be null)
  /// @param habitId The habit ID for fetching completion timestamps
  static Future<void> show(
    BuildContext context,
    DateTime date,
    CompletionRecord? record,
    String habitId,
  ) async {
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
    
    if (!context.mounted) return;
    
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

  /// Get full weekday name from date
  static String _getFullDayName(DateTime date) {
    const fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return fullDayNames[date.weekday - 1]; // weekday is 1-7, array is 0-6
  }

  /// Get abbreviated month name from month number
  static String _getMonthAbbreviation(int month) {
    const monthAbbreviations = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthAbbreviations[month];
  }

  /// Format time for display (24-hour format)
  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
