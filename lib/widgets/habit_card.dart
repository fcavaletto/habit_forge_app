import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme.dart';

/// A card widget displaying a habit with its progress chart and controls
class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSettings;

  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onComplete,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = colorScheme.habitColor(habit.colorIndex);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Habit icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(habit.iconName),
                  color: habitColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Habit details and chart
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Habit name
                    Text(
                      habit.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Habit description
                    Text(
                      habit.description,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Progress chart (7 days grid)
                    SizedBox(
                      height: 50,
                      child: Row(
                        children: habit.last7Days.map((completed) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: completed
                                    ? habitColor
                                    : habitColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: completed
                                  ? Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Streak counter and complete button
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Streak counter
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: habitColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        habit.currentStreak.toString(),
                        style: TextStyle(
                          color: habitColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Complete button
                  InkWell(
                    onTap: onComplete,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: colorScheme.onSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get IconData from icon name string
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
      default:
        return Icons.check_circle;
    }
  }
}

/// A more detailed habit card with 4-week grid chart for expanded view
class DetailedHabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onComplete;
  final VoidCallback? onClose;

  const DetailedHabitCard({
    super.key,
    required this.habit,
    this.onComplete,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = colorScheme.habitColor(habit.colorIndex);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon, title, and close button
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(habit.iconName),
                    color: habitColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        habit.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context,
                  'Current Streak',
                  '${habit.currentStreak} days',
                  habitColor,
                ),
                _buildStatItem(
                  context,
                  'Total Completions',
                  habit.totalCompletions.toString(),
                  habitColor,
                ),
                _buildStatItem(
                  context,
                  'Completion Rate',
                  '${(habit.completionRate * 100).round()}%',
                  habitColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4-week grid chart
            Text(
              'Last 4 Weeks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 160,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 28,
                itemBuilder: (context, index) {
                  final weekIndex = index ~/ 7;
                  final dayIndex = index % 7;
                  final completed = habit.last4Weeks[weekIndex][dayIndex];

                  return Container(
                    decoration: BoxDecoration(
                      color: completed
                          ? habitColor
                          : habitColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: completed
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Complete today button
            if (onComplete != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onComplete,
                  icon: Icon(_getIconData(habit.iconName)),
                  label: Text('Mark as Complete Today'),
                  style: FilledButton.styleFrom(
                    backgroundColor: habitColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
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
      default:
        return Icons.check_circle;
    }
  }
}
