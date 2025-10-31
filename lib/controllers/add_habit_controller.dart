import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../widgets/forms/frequency_selector.dart';
import '../providers/app_state_provider.dart';
import '../services/haptic_feedback_service.dart';
import '../widgets/dialogs/target_goal_change_dialog.dart';

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
/// - Name: Required, 1-40 characters
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
///
/// Note: Initial color selection should be handled by the view using
/// `onColorChanged()` method after the controller is constructed.
class AddHabitController {
  final Function(Habit) onHabitAdded;
  final Function(Habit)? onHabitUpdated;
  final List<Habit> existingHabits;
  final AppState _appState;
  final Habit? existingHabit; // For edit mode

  // Form state
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController targetGoalController = TextEditingController(
    text: '1',
  );

  String selectedIconName = 'local_fire_department';
  int selectedLightColor = 0xFFEF4444; // Default to Coral Red (first color)
  int selectedDarkColor = 0xFFFC8181; // Default to Coral Red dark variant
  FrequencyData frequencyData = FrequencyData.forType(Frequency.everyDay);
  TimeOfDay? reminderTime;
  bool enableReminders = false;
  int targetGoal = 1;
  int? originalTargetGoal; // Store original goal for change detection
  bool allowExceedGoal = false;

  bool isLoading = false;
  String? errorMessage;

  /// Whether this controller is in edit mode
  bool get isEditMode => existingHabit != null;

  AddHabitController({
    required this.onHabitAdded,
    this.onHabitUpdated,
    required this.existingHabits,
    required AppState appState,
    this.existingHabit,
  }) : _appState = appState {
    // Initialize form fields from existing habit if in edit mode
    if (existingHabit != null) {
      _initializeFromExistingHabit(existingHabit!);
    }

    // Clear error message when user starts typing
    nameController.addListener(_clearError);
    descriptionController.addListener(_clearError);
    targetGoalController.addListener(_clearError);
  }

  /// Initialize form fields from existing habit
  void _initializeFromExistingHabit(Habit habit) {
    nameController.text = habit.name;
    descriptionController.text = habit.description;
    selectedIconName = habit.iconName;
    selectedLightColor = habit.lightColorValue;
    selectedDarkColor = habit.darkColorValue;
    
    // Determine frequency type from days
    frequencyData = _frequencyDataFromDays(habit.frequencyDays);
    
    targetGoalController.text = habit.targetGoal.toString();
    targetGoal = habit.targetGoal;
    originalTargetGoal = habit.targetGoal;
    allowExceedGoal = habit.allowExceedGoal;
    enableReminders = habit.enableReminders;
    reminderTime = habit.reminderTime;
  }

  /// Create FrequencyData from days map by inferring the type
  FrequencyData _frequencyDataFromDays(Map<String, int> days) {
    // Check for every day
    final everyDayPattern = {
      'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1,
      'fri': 1, 'sat': 1, 'sun': 1,
    };
    if (_mapsEqual(days, everyDayPattern)) {
      return FrequencyData.forType(Frequency.everyDay);
    }

    // Check for workdays
    final workdaysPattern = {
      'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1,
      'sat': 0, 'sun': 0,
    };
    if (_mapsEqual(days, workdaysPattern)) {
      return FrequencyData.forType(Frequency.workdays);
    }

    // Check for weekend
    final weekendPattern = {
      'mon': 0, 'tue': 0, 'wed': 0, 'thu': 0, 'fri': 0,
      'sat': 1, 'sun': 1,
    };
    if (_mapsEqual(days, weekendPattern)) {
      return FrequencyData.forType(Frequency.weekend);
    }

    // Default to custom
    return FrequencyData(Frequency.custom, Map<String, int>.from(days));
  }

  /// Helper to compare maps
  bool _mapsEqual(Map<String, int> map1, Map<String, int> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
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

  /// Increment target goal by 1 (max 1000)
  void incrementTargetGoal() {
    final current = int.tryParse(targetGoalController.text.trim()) ?? 1;
    final newValue = (current + 1).clamp(1, 1000);
    targetGoalController.text = newValue.toString();
    targetGoal = newValue;
    _clearError();
  }

  /// Decrement target goal by 1 (min 1)
  void decrementTargetGoal() {
    final current = int.tryParse(targetGoalController.text.trim()) ?? 1;
    final newValue = (current - 1).clamp(1, 1000);
    targetGoalController.text = newValue.toString();
    targetGoal = newValue;
    _clearError();
  }

  /// Get current target goal value for button state checks
  int getCurrentTargetGoal() {
    final current = int.tryParse(targetGoalController.text.trim()) ?? 1;
    return current.clamp(1, 1000);
  }

  /// Builds a preview Habit object from current form state
  ///
  /// Used for real-time preview in the UI before saving.
  /// Returns a Habit instance with current form values, defaulting to
  /// placeholder values when fields are empty or invalid.
  Habit buildPreviewHabit() {
    // Get current values, with safe defaults
    final name = nameController.text.trim().isEmpty
        ? 'Habit Name'
        : nameController.text.trim();
    final description = descriptionController.text.trim();

    // Parse target goal safely
    final goalText = targetGoalController.text.trim();
    final goal = int.tryParse(goalText) ?? 1;
    final safeGoal = goal <= 0 ? 1 : (goal > 1000 ? 1000 : goal);

    // In edit mode, preserve the original habit's ID and creation date
    if (isEditMode && existingHabit != null) {
      return existingHabit!.copyWith(
        name: name,
        description: description,
        lightColorValue: selectedLightColor,
        darkColorValue: selectedDarkColor,
        iconName: selectedIconName,
        frequencyDays: frequencyData.days,
        targetGoal: safeGoal,
        allowExceedGoal: allowExceedGoal,
        enableReminders: enableReminders,
        reminderTime: reminderTime,
        completions: <DateTime, CompletionRecord>{}, // Clear completions for preview
      );
    }

    // Create mode - new habit
    return Habit.createWithUuid(
      name: name,
      description: description,
      lightColorValue: selectedLightColor,
      darkColorValue: selectedDarkColor,
      iconName: selectedIconName,
      frequencyDays: frequencyData.days,
      targetGoal: safeGoal,
      allowExceedGoal: allowExceedGoal,
      // No reminders for preview - keep it simple
      enableReminders: false,
      reminderTime: null,
    );
  }

  /// Validate the form data
  bool validateForm() {
    if (nameController.text.trim().isEmpty) {
      errorMessage = 'Habit name is required';
      HapticFeedbackService.error();
      return false;
    }

    // Validate habit name length
    if (nameController.text.trim().length > 40) {
      errorMessage = 'Habit name must be 40 characters or less';
      HapticFeedbackService.error();
      return false;
    }

    // Validate description length
    if (descriptionController.text.trim().length > 200) {
      errorMessage = 'Description must be 200 characters or less';
      HapticFeedbackService.error();
      return false;
    }

    // Validate target goal
    final goalText = targetGoalController.text.trim();
    if (goalText.isEmpty) {
      errorMessage = 'Target goal is required';
      HapticFeedbackService.error();
      return false;
    }

    final goalValue = int.tryParse(goalText);
    if (goalValue == null) {
      errorMessage = 'Target goal must be a valid number';
      HapticFeedbackService.error();
      return false;
    }

    if (goalValue <= 0) {
      errorMessage = 'Target goal must be greater than 0';
      HapticFeedbackService.error();
      return false;
    }

    if (goalValue > 1000) {
      errorMessage = 'Target goal cannot exceed 1000';
      HapticFeedbackService.error();
      return false;
    }

    targetGoal = goalValue;
    return true;
  }

  /// Check for duplicate habits
  /// Excludes current habit when in edit mode
  bool _isDuplicateHabit() {
    final normalizedName = nameController.text.toLowerCase().trim();
    return existingHabits.any((habit) {
      // Exclude current habit in edit mode
      if (isEditMode && existingHabit != null && habit.id == existingHabit!.id) {
        return false;
      }
      return habit.name.toLowerCase().trim() == normalizedName &&
          habit.iconName == selectedIconName;
    });
  }

  /// Save the habit (create or update)
  /// 
  /// [context] is required to show the target goal change dialog in edit mode
  Future<void> saveHabit({BuildContext? context}) async {
    if (!validateForm()) return;

    if (_isDuplicateHabit()) {
      errorMessage = 'A habit with this name and icon already exists';
      HapticFeedbackService.error();
      return;
    }

    try {
      isLoading = true;

      if (isEditMode && existingHabit != null) {
        // Check if target goal changed
        if (originalTargetGoal != null && 
            targetGoal != originalTargetGoal && 
            context != null) {
          // Show dialog to handle goal change
          final result = await TargetGoalChangeDialog.show(
            context,
            oldGoal: originalTargetGoal!,
            newGoal: targetGoal,
          );

          if (result == null || result == TargetGoalChangeResult.cancel) {
            // User canceled - don't save
            isLoading = false;
            return;
          }

          // Proceed with update
          final updatedHabit = existingHabit!.copyWith(
            name: nameController.text.trim().length > 40
                ? nameController.text.trim().substring(0, 40)
                : nameController.text.trim(),
            description: descriptionController.text.trim().length > 200
                ? descriptionController.text.trim().substring(0, 200)
                : descriptionController.text.trim(),
            lightColorValue: selectedLightColor,
            darkColorValue: selectedDarkColor,
            iconName: selectedIconName,
            reminderTime: enableReminders ? reminderTime : null,
            enableReminders: enableReminders,
            frequencyDays: frequencyData.days,
            targetGoal: targetGoal,
            allowExceedGoal: allowExceedGoal,
          );

          debugPrint('🔄 Habit updated: ${updatedHabit.name}');

          // Update the habit in storage
          final updateResult = await _appState.habitProvider.updateHabit(updatedHabit);
          if (!updateResult.success) {
            errorMessage = updateResult.errorMessage;
            isLoading = false;
            return;
          }

          // If user chose to update past completions, do that now
          if (result == TargetGoalChangeResult.updatePast) {
            try {
              await _appState.habitProvider.updatePastCompletionGoals(
                existingHabit!.id,
                targetGoal,
              );
              debugPrint('✅ Updated past completion goals for habit ${existingHabit!.id}');
            } catch (e) {
              debugPrint('❌ Failed to update past completion goals: $e');
              // Non-fatal - metadata was already updated
            }
          }

          if (onHabitUpdated != null) {
            onHabitUpdated!(updatedHabit);
          }
          HapticFeedbackService.light();
          isLoading = false;
          return;
        }

        // Update existing habit (no goal change or no context provided)
        // Update existing habit
        final updatedHabit = existingHabit!.copyWith(
          name: nameController.text.trim().length > 40
              ? nameController.text.trim().substring(0, 40)
              : nameController.text.trim(),
          description: descriptionController.text.trim().length > 200
              ? descriptionController.text.trim().substring(0, 200)
              : descriptionController.text.trim(),
          lightColorValue: selectedLightColor,
          darkColorValue: selectedDarkColor,
          iconName: selectedIconName,
          reminderTime: enableReminders ? reminderTime : null,
          enableReminders: enableReminders,
          frequencyDays: frequencyData.days,
          targetGoal: targetGoal,
          allowExceedGoal: allowExceedGoal,
        );

        debugPrint('🔄 Habit updated: ${updatedHabit.name}');

        // Update the habit in storage
        final updateResult = await _appState.habitProvider.updateHabit(updatedHabit);
        if (!updateResult.success) {
          errorMessage = updateResult.errorMessage;
          return;
        }

        if (onHabitUpdated != null) {
          onHabitUpdated!(updatedHabit);
        }
        HapticFeedbackService.light();
      } else {
        // Create new habit
        final habit = Habit.createWithUuid(
          name: nameController.text.trim().length > 40
              ? nameController.text.trim().substring(0, 40)
              : nameController.text.trim(),
          description: descriptionController.text.trim().length > 200
              ? descriptionController.text.trim().substring(0, 200)
              : descriptionController.text.trim(),
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
        HapticFeedbackService.light();
      }
    } catch (e) {
      errorMessage = isEditMode
          ? 'Failed to update habit: $e'
          : 'Failed to create habit: $e';
      HapticFeedbackService.error();
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
