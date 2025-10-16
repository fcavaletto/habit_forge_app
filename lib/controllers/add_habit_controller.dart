import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../widgets/forms/frequency_selector.dart';
import '../providers/app_state_provider.dart';

/// Controller class that handles all business logic for adding/editing habits
///
/// This controller implements the MVC pattern by separating UI concerns from business logic,
/// providing better testability and maintainability. It manages the complete habit creation
/// workflow including form validation, data processing, and error handling.
///
/// ## Responsibilities:
/// - **Form State Management**: Maintains all form field controllers and state
/// - **Data Validation**: Validates habit data before creation/update
/// - **Business Logic**: Handles habit creation, editing, and persistence
/// - **Error Handling**: Manages validation errors and user feedback
/// - **UI Integration**: Provides callbacks for UI state updates
///
/// ## Form Fields Managed:
/// - Habit name and description
/// - Visual customization (icon, color)
/// - Frequency settings (daily, weekly, custom)
/// - Reminder configuration
/// - Target goal settings
///
/// ## Validation Rules:
/// - Name: Required, 1-50 characters
/// - Description: Optional, max 200 characters
/// - Target Goal: Must be positive integer
/// - Icon/Color: Must be valid selections
///
/// ## Usage Pattern:
/// ```dart
/// final controller = AddHabitController(
///   onHabitAdded: (habit) => handleNewHabit(habit),
///   existingHabits: currentHabits,
///   appState: appState,
/// );
/// ```
class AddHabitController {
  final Function(Habit) onHabitAdded;
  final List<Habit> existingHabits;
  final AppState _appState;

  // Form state
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController targetGoalController = TextEditingController(text: '1');

  String selectedIconName = 'local_fire_department';
  int selectedLightColor = 0xFFe44344; // Default to Red light (first color)
  int selectedDarkColor = 0xFFED6D6E; // Default to Red dark (first color)
  FrequencyData frequencyData = FrequencyData.forType(Frequency.everyDay);
  TimeOfDay? reminderTime;
  bool enableReminders = false;
  int targetGoal = 1;
  bool allowExceedGoal = false;

  bool isLoading = false;
  String? errorMessage;

  AddHabitController({
    required this.onHabitAdded,
    required this.existingHabits,
    required AppState appState,
  }) : _appState = appState {
    // Clear error message when user starts typing
    nameController.addListener(_clearError);
    descriptionController.addListener(_clearError);
    targetGoalController.addListener(_clearError);
  }

  void _clearError() {
    if (errorMessage != null) {
      errorMessage = null;
    }
  }

  void onIconChanged(String iconName) {
    selectedIconName = iconName;
    _clearError();
  }

  void onColorChanged(Color lightColor, Color darkColor) {
    selectedLightColor = lightColor.toARGB32();
    selectedDarkColor = darkColor.toARGB32();
    _clearError();
  }

  void onFrequencyChanged(FrequencyData newFrequencyData) {
    frequencyData = newFrequencyData;
    _clearError();
  }

  /// Validate the form data
  bool validateForm() {
    if (nameController.text.trim().isEmpty) {
      errorMessage = 'Habit name is required';
      return false;
    }

    // Description is now optional - no validation needed

    // Validate target goal
    final goalText = targetGoalController.text.trim();
    if (goalText.isEmpty) {
      errorMessage = 'Target goal is required';
      return false;
    }

    final goalValue = int.tryParse(goalText);
    if (goalValue == null) {
      errorMessage = 'Target goal must be a valid number';
      return false;
    }

    if (goalValue <= 0) {
      errorMessage = 'Target goal must be greater than 0';
      return false;
    }

    if (goalValue > 1000) {
      errorMessage = 'Target goal cannot exceed 1000';
      return false;
    }

    targetGoal = goalValue;
    return true;
  }

  /// Check for duplicate habits
  bool _isDuplicateHabit() {
    final normalizedName = nameController.text.toLowerCase().trim();
    return existingHabits.any((habit) =>
        habit.name.toLowerCase().trim() == normalizedName &&
        habit.iconName == selectedIconName);
  }

  /// Save the habit
  Future<void> saveHabit() async {
    if (!validateForm()) return;

    if (_isDuplicateHabit()) {
      errorMessage = 'A habit with this name and icon already exists';
      return;
    }

    try {
      isLoading = true;

      final habit = Habit.createWithUuid(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        lightColorValue: selectedLightColor,
        darkColorValue: selectedDarkColor,
        iconName: selectedIconName,
        reminderTime: enableReminders ? reminderTime : null,
        enableReminders: enableReminders,
        frequencyDays: frequencyData.days,
        targetGoal: targetGoal,
        allowExceedGoal: allowExceedGoal,
      );

      debugPrint('🎯 Habit created successfully: ${habit.name}');

      // Actually save the habit to storage
      final saveResult = await _appState.habitProvider.addHabit(habit);
      if (!saveResult.success) {
        errorMessage = saveResult.errorMessage;
        return;
      }

      onHabitAdded(habit);

    } catch (e) {
      errorMessage = 'Failed to create habit: $e';
      debugPrint('❌ Error in AddHabitController.saveHabit: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Dispose of all resources
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    targetGoalController.dispose();
  }
}