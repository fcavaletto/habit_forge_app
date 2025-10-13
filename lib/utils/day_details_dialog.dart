import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/atomic_data_service.dart';

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
  /// @param atomicDataService The atomic data service for fetching timestamps
  static Future<void> show(
    BuildContext context,
    DateTime date,
    CompletionRecord? record,
    String habitId,
    IAtomicDataService atomicDataService,
  ) async {
    final fullDayName = _getFullDayName(date);
    final dateStr = '${date.day} ${_getMonthAbbreviation(date.month)}';
    
    // Fetch individual completion timestamps for this day
    List<DateTime> completionTimes = [];
    if (record != null && record.count > 0) {
      try {
        // Normalize date to start of day for accurate querying
        final startOfDay = DateTime(date.year, date.month, date.day);
        
        // Use the atomic service method that gets individual timestamps
        final result = await atomicDataService.getIndividualCompletionTimestamps(
          habitId: habitId,
          date: startOfDay,
          context: DataAccessContext(
            component: 'DayDetailsDialog',
            operation: 'getIndividualCompletionTimestamps',
            parameters: {'habitId': habitId, 'date': date.toIso8601String()},
          ),
        );
        
        if (result.success && result.data != null) {
          completionTimes = result.data!;
        }
        
        debugPrint('📊 [DayDetailsDialog] Found ${completionTimes.length} individual completion timestamps');
      } catch (e) {
        debugPrint('❌ Error fetching individual completion times: $e');
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
                _buildCompletionTimesList(context, completionTimes),
              ] else ...[
                Text(
                  'No completion times available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ] else ...[
              const Text('No completions recorded'),
            ],
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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

  /// Build completion times list with scrolling
  static Widget _buildCompletionTimesList(BuildContext context, List<DateTime> completionTimes) {
    const double maxListHeight = 200.0; // Maximum height for the scrollable list
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxListHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: completionTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final time = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  // Completion number
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time
                  Text(
                    _formatTime(time),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // AM/PM indicator
                  Text(
                    time.hour < 12 ? 'AM' : 'PM',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
