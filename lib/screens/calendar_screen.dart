import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/habit.dart';
import '../models/habit_storage.dart';
import '../theme.dart';

/// Calendar Screen - GitHub-style habit tracking calendar
///
/// Features:
/// - Monthly calendar view with TableCalendar widget
/// - Days highlighted with colored dots for completed habits
/// - Tap on day to select and view habit completions
/// - Interactive habit completion toggling
/// - Light theme with navigation arrows
/// - Integrated with habit data model and storage
/// - Responsive design with day details view
///
/// Usage:
/// Navigate from dashboard using calendar icon button.
/// Tap any day to see completed habits and toggle their status.
/// Use navigation arrows to browse different months.
/// Color dots represent different habits using their assigned colors.

/// Calendar screen for viewing and managing habit completions
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<HabitCompletion>> _completions = {};
  List<Habit> _habits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    // Store colors outside async gap to avoid using context across async
    final colorScheme = Theme.of(context).colorScheme;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final habits = await habitStorage.getHabits();
    final completions = <DateTime, List<HabitCompletion>>{};

    // Process all habits and their completions
    for (final habit in habits) {
      for (final completion in habit.completions.entries) {
        final date = DateTime(
          completion.key.year,
          completion.key.month,
          completion.key.day,
        );

        if (completion.value) { // Only add completed habits
          completions[date] ??= [];
          completions[date]!.add(HabitCompletion(
            habitId: habit.id,
            habitName: habit.name,
            color: colorScheme.habitColors[habit.colorIndex],
            iconName: habit.iconName,
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _habits = habits;
        _completions = completions;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCompletion(DateTime day, String habitId) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final habit = _habits.firstWhere((h) => h.id == habitId);
    final isCompleted = habit.isCompleted(normalizedDay);

    // Update the habit
    await habitStorage.updateHabitCompletion(habitId, normalizedDay, !isCompleted);

    // Reload data to refresh the calendar
    await _loadData();
  }

  List<HabitCompletion> _getCompletionsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _completions[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Habit Calendar',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const Divider(height: 1),
                Expanded(
                  child: _buildDayDetails(),
                ),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: Colors.black,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: Colors.black,
          ),
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: const TextStyle(color: Colors.black),
          defaultTextStyle: const TextStyle(color: Colors.black),
          selectedTextStyle: const TextStyle(color: Colors.white),
          todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Colors.transparent,
          ),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            final completions = _getCompletionsForDay(day);
            if (completions.isEmpty) return null;

            return Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: completions.take(3).map((completion) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: completion.color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayDetails() {
    final completions = _getCompletionsForDay(_selectedDay);
    final dayHabits = _habits.where((habit) {
      final normalizedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      return habit.completions.containsKey(normalizedDay);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatSelectedDate(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${completions.length} habit${completions.length != 1 ? 's' : ''} completed',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (dayHabits.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No habits completed this day',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: dayHabits.length,
                itemBuilder: (context, index) {
                  final habit = dayHabits[index];
                  final normalizedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                  final isCompleted = habit.isCompleted(normalizedDay);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.habitColors[habit.colorIndex].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(habit.iconName),
                            color: Theme.of(context).colorScheme.habitColors[habit.colorIndex],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                habit.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                habit.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _toggleCompletion(_selectedDay, habit.id),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Theme.of(context).colorScheme.habitColors[habit.colorIndex]
                                  : Colors.transparent,
                              border: Border.all(
                                color: isCompleted
                                    ? Theme.of(context).colorScheme.habitColors[habit.colorIndex]
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatSelectedDate() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return '${months[_selectedDay.month - 1]} ${_selectedDay.day}, ${_selectedDay.year}';
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'local_drink':
        return Icons.local_drink;
      case 'book':
        return Icons.book;
      case 'bed':
        return Icons.bed;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_run':
        return Icons.directions_run;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'favorite':
        return Icons.favorite;
      case 'music_note':
        return Icons.music_note;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'spa':
        return Icons.spa;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'create':
        return Icons.create;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'nature':
        return Icons.nature;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.check_circle;
    }
  }
}

/// Data class for habit completions on calendar
class HabitCompletion {
  final String habitId;
  final String habitName;
  final Color color;
  final String iconName;

  HabitCompletion({
    required this.habitId,
    required this.habitName,
    required this.color,
    required this.iconName,
  });
}
