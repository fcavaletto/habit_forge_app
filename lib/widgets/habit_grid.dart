import 'package:flutter/material.dart';

/// HabitGrid Widget - GitHub-style contribution grid for habit tracking
///
/// Features:
/// - Interactive tile-based progress grid (7 columns x dynamic rows)
/// - Shows last 3 months of habit completions
/// - Each cell: 12x12px with 2px border radius
/// - Filled cells use habitColor, empty cells use #E0E0E0
/// - Tap to toggle completion status
/// - Horizontal month labels above grid
/// - Smooth FadeTransition animations
/// - Two implementations: HabitGrid (with individual controllers) and OptimizedHabitGrid (better performance)
///
/// Usage:
/// ```dart
/// HabitGrid(
///   completions: [DateTime.now(), DateTime.now().subtract(Duration(days: 1))],
///   habitColor: Colors.green,
///   onCompletionChanged: (date, completed) {
///     // Handle completion change
///   },
/// )
/// ```

/// A GitHub-style contribution grid widget for habit tracking
class HabitGrid extends StatefulWidget {
  final List<DateTime> completions;
  final Color habitColor;
  final Function(DateTime, bool)? onCompletionChanged;

  const HabitGrid({
    super.key,
    required this.completions,
    required this.habitColor,
    this.onCompletionChanged,
  });

  @override
  State<HabitGrid> createState() => _HabitGridState();
}

class _HabitGridState extends State<HabitGrid> with TickerProviderStateMixin {
  late Map<DateTime, AnimationController> _animationControllers;
  late Map<DateTime, bool> _normalizedCompletions;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(HabitGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completions != widget.completions ||
        oldWidget.habitColor != widget.habitColor) {
      _disposeControllers();
      _initializeData();
    }
  }

  void _initializeData() {
    _animationControllers = {};
    _normalizedCompletions = {};

    // Create normalized completion map for the last 3 months
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    // Initialize all dates in the last 3 months as not completed
    DateTime current = threeMonthsAgo;
    while (current.isBefore(now) || current.isAtSameMomentAs(now)) {
      final normalized = DateTime(current.year, current.month, current.day);
      _normalizedCompletions[normalized] = false;

      // Create animation controller for this date
      _animationControllers[normalized] = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
        value: 0.0,
      );

      current = current.add(const Duration(days: 1));
    }

    // Mark actual completions and animate them
    for (final completion in widget.completions) {
      final normalized = DateTime(completion.year, completion.month, completion.day);
      if (_normalizedCompletions.containsKey(normalized)) {
        _normalizedCompletions[normalized] = true;
        _animationControllers[normalized]?.value = 1.0;
      }
    }
  }

  void _disposeControllers() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _toggleCompletion(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final isCompleted = _normalizedCompletions[normalized] ?? false;
    final newState = !isCompleted;

    setState(() {
      _normalizedCompletions[normalized] = newState;
    });

    // Animate the change
    final controller = _animationControllers[normalized];
    if (controller != null) {
      if (newState) {
        controller.forward();
      } else {
        controller.reverse();
      }
    }

    // Notify parent of the change
    widget.onCompletionChanged?.call(normalized, newState);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        _buildMonthLabels(),
        const SizedBox(height: 8),
        // Grid
        _buildGrid(),
      ],
    );
  }

  Widget _buildMonthLabels() {
    final now = DateTime.now();
    final months = <String>[];

    // Generate month labels for the last 3 months
    for (int i = 2; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthName = _getMonthName(date.month);
      months.add(monthName);
    }

    return Row(
      children: months.map((month) {
        return Expanded(
          child: Text(
            month,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    // Calculate total weeks needed (approximately)
    final totalDays = now.difference(threeMonthsAgo).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 days per week
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: totalWeeks * 7,
      itemBuilder: (context, index) {
        final weekIndex = index ~/ 7;
        final dayOfWeek = index % 7;

        // Calculate the date for this cell
        final startOfWeek = threeMonthsAgo.add(Duration(days: weekIndex * 7));
        final cellDate = startOfWeek.add(Duration(days: dayOfWeek));

        // Don't show dates in the future
        if (cellDate.isAfter(now)) {
          return const SizedBox.shrink();
        }

        final normalized = DateTime(cellDate.year, cellDate.month, cellDate.day);
        final controller = _animationControllers[normalized];

        if (controller == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _toggleCompletion(cellDate),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0), // Default empty color
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: controller,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.habitColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
}

/// A more efficient version that doesn't create animation controllers for every cell
class OptimizedHabitGrid extends StatelessWidget {
  final List<DateTime> completions;
  final Color habitColor;
  final Function(DateTime, bool)? onCompletionChanged;

  const OptimizedHabitGrid({
    super.key,
    required this.completions,
    required this.habitColor,
    this.onCompletionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthLabels(context),
        const SizedBox(height: 8),
        _buildGrid(context),
      ],
    );
  }

  Widget _buildMonthLabels(BuildContext context) {
    final now = DateTime.now();
    final months = <String>[];

    for (int i = 2; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthName = _getMonthName(date.month);
      months.add(monthName);
    }

    return Row(
      children: months.map((month) {
        return Expanded(
          child: Text(
            month,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    // Create a set of completed dates for O(1) lookup
    final completedDates = completions.map((date) =>
      DateTime(date.year, date.month, date.day)
    ).toSet();

    final totalDays = now.difference(threeMonthsAgo).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: totalWeeks * 7,
      itemBuilder: (context, index) {
        final weekIndex = index ~/ 7;
        final dayOfWeek = index % 7;

        final startOfWeek = threeMonthsAgo.add(Duration(days: weekIndex * 7));
        final cellDate = startOfWeek.add(Duration(days: dayOfWeek));

        if (cellDate.isAfter(now)) {
          return const SizedBox.shrink();
        }

        final normalized = DateTime(cellDate.year, cellDate.month, cellDate.day);
        final isCompleted = completedDates.contains(normalized);

        return GestureDetector(
          onTap: () => onCompletionChanged?.call(normalized, !isCompleted),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCompleted ? habitColor : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
}
