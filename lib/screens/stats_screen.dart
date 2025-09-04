import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/habit.dart';
import '../models/habit_storage.dart';
import '../screens/add_habit_screen.dart';

/// Stats Screen - Displays analytics and charts for habit tracking
///
/// Shows comprehensive statistics including:
/// - Completion streaks
/// - Completion rates over time
/// - Habit performance metrics
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
  late HabitStorage _habitStorage;
  Map<DateTime, bool> _completions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _habitStorage = HabitStorage();
    _loadHabitData();
  }

  Future<void> _loadHabitData() async {
    setState(() => _isLoading = true);
    try {
      final habits = await _habitStorage.getHabits(includeArchived: true);
      final habit = habits.firstWhere(
        (h) => h.id == widget.habit.id,
        orElse: () => widget.habit,
      );
      setState(() {
        _completions = habit.completions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load habit data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Habit Header
                  _buildHabitHeader(),
                  const SizedBox(height: 24),

                  // Current Streak
                  _buildCurrentStreak(),
                  const SizedBox(height: 24),

                  // Completion Rate Chart
                  _buildCompletionRateChart(),
                  const SizedBox(height: 24),

                  // Weekly Overview
                  _buildWeeklyOverview(),
                  const SizedBox(height: 24),

                  // Monthly Calendar
                  _buildMonthlyCalendar(),
                ],
              ),
            ),
    );
  }

  Widget _buildHabitHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.habit.iconName.toIconData,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 4),
                  Text(
                    widget.habit.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

  Widget _buildCurrentStreak() {
    final currentStreak = _calculateCurrentStreak();
    final longestStreak = _calculateLongestStreak();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Streaks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        currentStreak.toString(),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Current Streak',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        longestStreak.toString(),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Longest Streak',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRateChart() {
    final last30Days = _getLast30DaysData();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Rate (Last 30 Days)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.now().subtract(Duration(days: 29 - value.toInt()));
                          return Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: last30Days.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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

  Widget _buildWeeklyOverview() {
    final weeklyData = _getWeeklyData();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .asMap()
                  .entries
                  .map((entry) {
                final dayName = entry.value;
                final completed = weeklyData[entry.key];
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: completed
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        completed ? Icons.check : Icons.close,
                        color: completed
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Calendar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280, // Fixed height for the calendar
              child: PageView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 12, // Show 12 months
                itemBuilder: (context, monthIndex) {
                  final currentDate = DateTime.now();
                  final targetMonth = DateTime(currentDate.year, currentDate.month + monthIndex, 1);
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

    // Calculate the weekday offset (0 = Sunday, 1 = Monday, etc.)
    final firstWeekday = firstDayOfMonth.weekday;
    final offset = (firstWeekday - 1) % 7; // Adjust so Monday is 0

    return Column(
      children: [
        // Month and year header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
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

        const SizedBox(height: 8),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: 42, // 6 weeks × 7 days
            itemBuilder: (context, index) {
              final dayNumber = index - offset + 1;

              if (dayNumber < 1 || dayNumber > lastDayOfMonth.day) {
                // Empty cell
                return Container();
              }

              final date = DateTime(monthDate.year, monthDate.month, dayNumber);
              final isCompleted = _completions[DateTime(date.year, date.month, date.day)] ?? false;
              final isToday = date.year == DateTime.now().year &&
                             date.month == DateTime.now().month &&
                             date.day == DateTime.now().day;

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

  int _calculateCurrentStreak() {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final isCompleted = _completions[DateTime(date.year, date.month, date.day)] ?? false;

      if (isCompleted) {
        streak++;
      } else if (i == 0) {
        // Don't break streak for today if not completed yet
        continue;
      } else {
        break;
      }
    }

    return streak;
  }

  int _calculateLongestStreak() {
    int longestStreak = 0;
    int currentStreak = 0;

    final dates = _completions.keys.toList()..sort();

    for (final date in dates) {
      if (_completions[date] == true) {
        currentStreak++;
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return longestStreak;
  }

  List<double> _getLast30DaysData() {
    final data = <double>[];
    final now = DateTime.now();

    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final isCompleted = _completions[DateTime(date.year, date.month, date.day)] ?? false;
      final rate = isCompleted ? 1.0 : 0.0;
      data.add(rate);
    }

    return data;
  }

  List<bool> _getWeeklyData() {
    final data = <bool>[];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final isCompleted = _completions[DateTime(date.year, date.month, date.day)] ?? false;
      data.add(isCompleted);
    }

    return data;
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }
}
