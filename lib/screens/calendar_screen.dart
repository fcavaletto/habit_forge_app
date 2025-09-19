import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';
import '../widgets/year_grid.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import 'package:provider/provider.dart';

/// Calendar Screen - GitHub-style habit tracking calendar
///
/// Features:
/// - Horizontal scrolling year grids for each habit
/// - 7-row layout (Mon-Sun) with 10px squares
/// - Gradient fills for multi-completion visualization
/// - Tooltips showing date and completion count
/// - Tap to toggle completion status
/// - Integrated with habit data model and providers

/// Calendar screen for viewing and managing habit completions
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Habit> _habits = [];
  bool _isLoading = true;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    // Show last 365 days
    final now = DateTime.now();
    _startDate = DateTime(now.year - 1, now.month, now.day + 1);
    _endDate = now;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load habits from provider
      final appState = context.read<AppStateProvider>();
      await appState.habitProvider.loadHabits();
      final habits = appState.habitProvider.habits;

      setState(() {
        _habits = habits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load habits: $e')),
        );
      }
    }
  }

  Future<void> _onCompletionTap(DateTime date, int currentCount, Habit habit) async {
    final appState = context.read<AppStateProvider>();
    // Toggle between 0 and 1 for now (can be enhanced with increment/decrement controls later)
    final newCount = currentCount > 0 ? 0 : 1;
    await appState.habitProvider.updateHabitCompletion(habit.id, date, newCount);
    await _loadData(); // Refresh the view
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Calendar'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? const Center(child: Text('No habits found'))
              : SafeScrollView(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final habit = _habits[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  habit.iconName.toIconData,
                                  color: _getHabitColor(habit.colorIndex),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  habit.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 120, // 7 rows * 10px + some padding
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: YearGrid(
                              habit: habit,
                              startDate: _startDate,
                              endDate: _endDate,
                              onCompletionTap: (date, count) => _onCompletionTap(date, count, habit),
                              squareSize: 10,
                              spacing: 1,
                            ),
                          ),
                          if (index < _habits.length - 1) const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Color _getHabitColor(int colorIndex) {
    return Theme.of(context).colorScheme.habitColor(colorIndex);
  }

}
