import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'habit_card.dart';

/// Optimized habit list widget using ListView.builder for better performance
/// with large numbers of habits. Includes virtualization and efficient rendering.
class OptimizedHabitList extends StatelessWidget {
  final List<Habit> habits;
  final Function(Habit) onHabitTap;
  final Function(Habit) onMarkCompleted;
  final Function(Habit) onEdit;
  final Function(Habit) onArchive;
  final Function(Habit) onDelete;
  final Function(Habit) onStats;

  const OptimizedHabitList({
    super.key,
    required this.habits,
    required this.onHabitTap,
    required this.onMarkCompleted,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: habits.length,
      // Performance optimizations
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final habit = habits[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: HabitCard(
            key: ValueKey(habit.id), // Stable key for performance
            habit: habit,
            onTap: () => onHabitTap(habit),
            onComplete: () => onMarkCompleted(habit),
            onEdit: () => onEdit(habit),
            onArchive: () => onArchive(habit),
            onDelete: () => onDelete(habit),
            onStats: () => onStats(habit),
          ),
        );
      },
    );
  }
}

/// Alternative grid layout with virtualization
class OptimizedHabitGrid extends StatelessWidget {
  final List<Habit> habits;
  final Function(Habit) onHabitTap;
  final Function(Habit) onMarkCompleted;
  final Function(Habit) onEdit;
  final Function(Habit) onArchive;
  final Function(Habit) onDelete;
  final Function(Habit) onStats;

  const OptimizedHabitGrid({
    super.key,
    required this.habits,
    required this.onHabitTap,
    required this.onMarkCompleted,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: habits.length,
      // Performance optimizations
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final habit = habits[index];
        return HabitCard(
          key: ValueKey(habit.id), // Stable key for performance
          habit: habit,
          onTap: () => onHabitTap(habit),
          onComplete: () => onMarkCompleted(habit),
          onEdit: () => onEdit(habit),
          onArchive: () => onArchive(habit),
          onDelete: () => onDelete(habit),
          onStats: () => onStats(habit),
        );
      },
    );
  }
}

/// Adaptive habit list that switches between list and grid based on habit count
class AdaptiveHabitList extends StatelessWidget {
  final List<Habit> habits;
  final Function(Habit) onHabitTap;
  final Function(Habit) onMarkCompleted;
  final Function(Habit) onEdit;
  final Function(Habit) onArchive;
  final Function(Habit) onDelete;
  final Function(Habit) onStats;

  const AdaptiveHabitList({
    super.key,
    required this.habits,
    required this.onHabitTap,
    required this.onMarkCompleted,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    // Use grid for small lists, list for larger lists
    if (habits.length <= 6) {
      return OptimizedHabitGrid(
        habits: habits,
        onHabitTap: onHabitTap,
        onMarkCompleted: onMarkCompleted,
        onEdit: onEdit,
        onArchive: onArchive,
        onDelete: onDelete,
        onStats: onStats,
      );
    } else {
      return OptimizedHabitList(
        habits: habits,
        onHabitTap: onHabitTap,
        onMarkCompleted: onMarkCompleted,
        onEdit: onEdit,
        onArchive: onArchive,
        onDelete: onDelete,
        onStats: onStats,
      );
    }
  }
}
