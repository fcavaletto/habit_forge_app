import 'habit.dart';

/// Result of a habit save operation
class HabitSaveResult {
  final bool success;
  final String? errorMessage;
  final Habit? savedHabit;
  final Habit? conflictingHabit; // For archived duplicate case

  const HabitSaveResult._({
    required this.success,
    this.errorMessage,
    this.savedHabit,
    this.conflictingHabit,
  });

  /// Successfully saved the habit
  factory HabitSaveResult.success(Habit habit) {
    return HabitSaveResult._(success: true, savedHabit: habit);
  }

  /// Failed to save due to duplicate habit
  factory HabitSaveResult.duplicate(String existingHabitName) {
    return HabitSaveResult._(
      success: false,
      errorMessage: 'A habit with the name "$existingHabitName" and the same icon already exists',
    );
  }

  /// Failed to save due to archived duplicate habit (requires user confirmation)
  factory HabitSaveResult.duplicateArchived(Habit conflictingHabit) {
    return HabitSaveResult._(
      success: false,
      errorMessage: 'A habit with the name "${conflictingHabit.name}" and the same icon exists but is archived',
      conflictingHabit: conflictingHabit,
    );
  }

  /// Failed to save due to other error
  factory HabitSaveResult.error(String message) {
    return HabitSaveResult._(success: false, errorMessage: message);
  }
}
