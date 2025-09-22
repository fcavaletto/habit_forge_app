import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Monthly Calendar Widget
///
/// Displays a scrollable monthly calendar with habit completion data.
/// Supports navigation through multiple months with visual completion indicators.
class MonthlyCalendar extends StatefulWidget {
  final Map<DateTime, int> completions;
  final DateTime currentDate;
  final DateTime? selectedMonth;

  const MonthlyCalendar({
    super.key,
    required this.completions,
    required this.currentDate,
    this.selectedMonth,
  });

  @override
  State<MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<MonthlyCalendar> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = AppConstants.calendarInitialPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Calendar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Navigation hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chevron_left,
                    size: AppConstants.iconSizeSmall,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppConstants.swipeToNavigateHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: AppConstants.iconSizeSmall,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Calendar pages
            SizedBox(
              height: AppConstants.calendarHeight - 60, // Account for header and hint
              child: PageView.builder(
                controller: _pageController,
                itemCount: AppConstants.calendarTotalMonths,
                itemBuilder: (context, pageIndex) {
                  final monthOffset = pageIndex - AppConstants.calendarInitialPage;
                  final targetMonth = DateTime(widget.currentDate.year, widget.currentDate.month + monthOffset, 1);
                  return _buildMonthGrid(targetMonth);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);

    // Calculate the weekday offset (0 = Monday, 1 = Tuesday, etc.)
    final firstWeekday = firstDayOfMonth.weekday;
    final offset = (firstWeekday - 1) % 7; // Adjust so Monday is 0

    return Column(
      children: [
        // Month and year header
        Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.defaultMargin),
          child: Text(
            '${_getMonthName(monthDate.month)} ${monthDate.year}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Day labels
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((day) => Expanded(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ))
              .toList(),
        ),

        const SizedBox(height: AppConstants.defaultMargin),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppConstants.calendarGridColumns,
              crossAxisSpacing: AppConstants.calendarSpacing,
              mainAxisSpacing: AppConstants.calendarSpacing,
            ),
            itemCount: AppConstants.calendarGridColumns * AppConstants.calendarGridRows,
            itemBuilder: (context, index) {
              final dayNumber = index - offset + 1;

              if (dayNumber < 1 || dayNumber > lastDayOfMonth.day) {
                // Empty cell for days outside current month
                return Container();
              }

              final date = DateTime(monthDate.year, monthDate.month, dayNumber);
              final completionCount = widget.completions[DateTime(date.year, date.month, date.day)] ?? 0;
              final isCompleted = completionCount > 0;
              final isToday = date.year == widget.currentDate.year &&
                             date.month == widget.currentDate.month &&
                             date.day == widget.currentDate.day;

              return Container(
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Theme.of(context).colorScheme.primary
                      : isToday
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isCompleted
                      ? Border.all(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 2,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  dayNumber.toString(),
                  style: TextStyle(
                    color: isCompleted
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }
}
