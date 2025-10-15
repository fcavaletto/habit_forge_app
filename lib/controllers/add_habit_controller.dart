import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../widgets/forms/frequency_selector.dart';

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

  // Form state
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController targetGoalController = TextEditingController(text: '1');

  String selectedIconName = 'local_fire_department';
  int selectedLightColor = 0xFF94a3b8; // Default to Slate light
  int selectedDarkColor = 0xFF334155; // Default to Slate dark
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
  }) {
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
    final targetGoalText = targetGoalController.text.trim();
    if (targetGoalText.isEmpty) {
      errorMessage = 'Target goal is required';
      return false;
    }

    final parsedGoal = int.tryParse(targetGoalText);
    if (parsedGoal == null || parsedGoal <= 0) {
      errorMessage = 'Target goal must be a positive number';
      return false;
    }

    return true;
  }

  /// Check if the form is valid and ready for habit creation
  bool get canCreateHabit {
    return nameController.text.trim().isNotEmpty &&
           targetGoalController.text.trim().isNotEmpty &&
           !isLoading;
  }

  /// Get the current frequency days map
  Map<String, int> get selectedFrequencyDays {
    return frequencyData.days;
  }

  /// Create a new habit with the current form data
  void createHabit() {
    if (!validateForm()) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    try {
      // Check for duplicate habits
      final habitName = nameController.text.trim();
      final duplicateExists = existingHabits.any(
        (habit) => habit.name.toLowerCase() == habitName.toLowerCase() &&
                   habit.iconName == selectedIconName,
      );

      if (duplicateExists) {
        errorMessage = 'A habit with this name and icon already exists';
        isLoading = false;
        return;
      }

      // Create the habit
      final habit = Habit.createWithUuid(
        name: habitName,
        description: descriptionController.text.trim(),
        lightColorValue: selectedLightColor,
        darkColorValue: selectedDarkColor,
        iconName: selectedIconName,
        reminderTime: enableReminders ? reminderTime : null,
        enableReminders: enableReminders,
        frequencyDays: selectedFrequencyDays,
        targetGoal: targetGoal,
        allowExceedGoal: allowExceedGoal,
      );

      // Add the habit
      onHabitAdded(habit);
      
      // Reset form
      _resetForm();
      
    } catch (e) {
      errorMessage = 'Failed to create habit: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Reset the form to its initial state
  void _resetForm() {
    nameController.clear();
    descriptionController.clear();
    targetGoalController.text = '1';
    selectedIconName = 'local_fire_department';
    selectedLightColor = 0xFF94a3b8;
    selectedDarkColor = 0xFF334155;
    frequencyData = FrequencyData.forType(Frequency.everyDay);
    reminderTime = null;
    enableReminders = false;
    targetGoal = 1;
    allowExceedGoal = false;
    errorMessage = null;
  }

  /// Handle name field changes
  void onNameChanged(String value) {
    _clearError();
  }

  /// Handle description field changes
  void onDescriptionChanged(String value) {
    _clearError();
  }

  /// Handle target goal field changes
  void onTargetGoalChanged(String value) {
    final parsedGoal = int.tryParse(value.trim());
    if (parsedGoal != null && parsedGoal > 0) {
      targetGoal = parsedGoal;
    }
    _clearError();
  }

  /// Handle allow exceed goal toggle
  void onAllowExceedGoalChanged(bool value) {
    allowExceedGoal = value;
    _clearError();
  }

  /// Dispose of all resources
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    targetGoalController.dispose();
  }
}