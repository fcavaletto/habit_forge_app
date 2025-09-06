import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../widgets/forms/frequency_selector.dart';
import '../providers/app_state_provider.dart';

/// Controller class that handles all business logic for adding/editing habits
/// This separates UI concerns from business logic for better testability and maintainability
class AddHabitController {
  final Function(Habit) onHabitAdded;
  final List<Habit> existingHabits;
  final AppState _appState;

  // Form state
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String selectedIconName = 'check_circle';
  int selectedColorIndex = 0;
  FrequencyData frequencyData = FrequencyData.forType(Frequency.everyDay);
  TimeOfDay? reminderTime;
  bool enableReminders = false;

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

  void onColorChanged(int colorIndex) {
    selectedColorIndex = colorIndex;
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

    if (descriptionController.text.trim().isEmpty) {
      errorMessage = 'Habit description is required';
      return false;
    }

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

      final habit = Habit.create(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        colorIndex: selectedColorIndex,
        iconName: selectedIconName,
        reminderTime: enableReminders ? reminderTime : null,
        enableReminders: enableReminders,
        frequencyDays: frequencyData.days,
      );

      debugPrint('🎯 Habit created successfully: ${habit.name}');

      // Actually save the habit to storage
      final saveResult = await _appState.habitProvider.addHabit(habit);
      if (!saveResult.success) {
        errorMessage = saveResult.errorMessage;
        return;
      }

      onHabitAdded(habit); // Call callback after successful persistence

    } catch (e) {
      errorMessage = 'Failed to create habit: $e';
      debugPrint('❌ Error in AddHabitController.saveHabit: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Dispose of resources
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
  }
}
