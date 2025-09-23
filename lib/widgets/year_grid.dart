import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme.dart';
import '../services/virtual_date_service.dart';

/// YearGrid widget - GitHub-style habit tracking grid
///
/// Features:
/// - Horizontal scrolling year view
/// - 7 rows (Monday to Sunday)
/// - 10px squares with 2px border radius
/// - Empty cells: #E0E0E0
/// - Filled cells: Gradient based on habit color and completion count
/// - Tooltips showing date and completion count
class YearGrid extends StatefulWidget {
  final Habit habit;
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime, int)? onCompletionTap;
  final double squareSize;
  final double spacing;

  const YearGrid({
    super.key,
    required this.habit,
    required this.startDate,
    required this.endDate,
    this.onCompletionTap,
    this.squareSize = 10.0,
    this.spacing = 1.0,
  });

  @override
  State<YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<YearGrid> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Auto-scroll to show recent days
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToRecent();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToRecent() {
    final now = VirtualDateService().currentDate;
    final daysSinceStart = now.difference(widget.startDate).inDays;
    final targetOffset = (daysSinceStart * (widget.squareSize + widget.spacing)) - 200; // Show some context
    if (targetOffset > 0) {
      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.endDate.difference(widget.startDate).inDays + 1;
    final weeks = (days / 7).ceil();

    return Column(
      children: [
        // Day labels (Mon, Tue, Wed, etc.)
        Row(
          children: [
            const SizedBox(width: 30), // Space for month labels
            for (int i = 0; i < 7; i++)
              SizedBox(
                width: widget.squareSize,
                child: Center(
                  child: Text(
                    _getDayAbbrev(i),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            if (weeks > 1) SizedBox(width: widget.spacing), // Extra spacing
          ],
        ),
        const SizedBox(height: 4),
        // Grid
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month labels column
                Column(
                  children: [
                    for (int week = 0; week < 7; week++)
                      SizedBox(
                        height: widget.squareSize,
                        child: Center(
                          child: Text(
                            _getDayName(week),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Grid content
                SizedBox(
                  width: weeks * (widget.squareSize + widget.spacing),
                  child: Column(
                    children: List.generate(7, (dayOfWeek) {
                      return Row(
                        children: List.generate(weeks, (week) {
                          final dayIndex = week * 7 + dayOfWeek;
                          if (dayIndex >= days) {
                            return SizedBox(width: widget.squareSize + widget.spacing);
                          }

                          final date = widget.startDate.add(Duration(days: dayIndex));
                          final count = widget.habit.getCompletionCount(date);

                          return Row(
                            children: [
                              _buildDaySquare(date, count),
                              if (week < weeks - 1) SizedBox(width: widget.spacing),
                            ],
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySquare(DateTime date, int count) {
    final isToday = _isSameDay(date, VirtualDateService().currentDate);
    final isGoalAchieved = count >= widget.habit.targetGoal;
    final maxOpacity = widget.habit.targetGoal.toDouble();
    final opacity = count > 0 ? (count / maxOpacity).clamp(0.0, 1.0) : 0.0;

    return Tooltip(
      message: '${_formatDate(date)}: ${count > 0 ? '$count/${widget.habit.targetGoal} completion${count != 1 ? 's' : ''}' : 'No completions'}',
      child: GestureDetector(
        onTap: widget.onCompletionTap != null
            ? () => widget.onCompletionTap!(date, count > 0 ? 0 : 1)
            : null,
        child: Container(
          width: widget.squareSize,
          height: widget.squareSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: count > 0
                ? _getHabitColor().withValues(alpha: opacity)
                : const Color(0xFFE0E0E0),
            border: isToday ? Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ) : isGoalAchieved ? Border.all(
              color: Colors.green.shade600,
              width: 1,
            ) : null,
          ),
          child: count > 1 ? Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w600,
                color: isGoalAchieved ? Colors.green.shade800 : Colors.white,
              ),
            ),
          ) : isGoalAchieved ? const Icon(
            Icons.check,
            size: 8,
            color: Colors.white,
          ) : null,
        ),
      ),
    );
  }

  Color _getHabitColor() {
    // Get color based on habit's color index using theme colors
    return Theme.of(context).colorScheme.habitColor(widget.habit.colorIndex);
  }

  String _getDayAbbrev(int dayIndex) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[dayIndex];
  }

  String _getDayName(int dayIndex) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayIndex];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
