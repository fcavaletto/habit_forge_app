import 'package:flutter/material.dart';
import 'habit_grid.dart';

/// Example usage of HabitGrid widget
class HabitGridExample extends StatefulWidget {
  const HabitGridExample({super.key});

  @override
  State<HabitGridExample> createState() => _HabitGridExampleState();
}

class _HabitGridExampleState extends State<HabitGridExample> {
  List<DateTime> completions = [
    // Add some sample completed dates
    DateTime.now().subtract(const Duration(days: 1)),
    DateTime.now().subtract(const Duration(days: 3)),
    DateTime.now().subtract(const Duration(days: 5)),
    DateTime.now().subtract(const Duration(days: 7)),
    DateTime.now().subtract(const Duration(days: 10)),
    DateTime.now().subtract(const Duration(days: 14)),
    DateTime.now().subtract(const Duration(days: 21)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Grid Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interactive Habit Grid',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap cells to toggle completion',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HabitGrid(
                  completions: completions,
                  habitColor: Colors.green,
                  onCompletionChanged: (date, completed) {
                    setState(() {
                      if (completed) {
                        completions.add(date);
                      } else {
                        completions.removeWhere((d) =>
                          d.year == date.year &&
                          d.month == date.month &&
                          d.day == date.day);
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Optimized Version (Better Performance)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OptimizedHabitGrid(
                  completions: completions,
                  habitColor: Colors.blue,
                  onCompletionChanged: (date, completed) {
                    setState(() {
                      if (completed) {
                        completions.add(date);
                      } else {
                        completions.removeWhere((d) =>
                          d.year == date.year &&
                          d.month == date.month &&
                          d.day == date.day);
                      }
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
