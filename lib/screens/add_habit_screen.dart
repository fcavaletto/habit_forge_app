import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'add_habit_view.dart';

/// Add Habit Screen - Main screen for creating new habits
///
/// This screen now uses the new architecture with:
/// - Provider for state management
/// - Repository pattern for data access
/// - Separated business logic (controller) from UI (view)
/// - Clean separation of concerns
///
/// The screen displays:
/// - Form fields for habit name and description
/// - Icon and color selection
/// - Frequency configuration
/// - Reminder settings
/// - Validation and error handling
class AddHabitScreen extends StatelessWidget {
  final Function(Habit) onHabitAdded;
  final List<Habit> existingHabits;

  const AddHabitScreen({
    super.key,
    required this.onHabitAdded,
    required this.existingHabits,
  });

  @override
  Widget build(BuildContext context) {
    return AddHabitView(
      onHabitAdded: onHabitAdded,
      existingHabits: existingHabits,
    );
  }
}