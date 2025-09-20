import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'add_habit_view.dart';

/// Add Habit Screen - Main interface for creating and editing habits
///
/// This screen implements a clean architecture pattern with separated concerns,
/// providing a comprehensive interface for habit creation and modification.
/// It delegates UI rendering to AddHabitView while maintaining a simple
/// facade interface for parent components.
///
/// ## Architecture Pattern:
/// - **Facade Pattern**: Simple interface hiding complex implementation
/// - **MVC Pattern**: Separates business logic (controller) from UI (view)
/// - **Provider Pattern**: Reactive state management integration
/// - **Repository Pattern**: Clean data access abstraction
///
/// ## Key Responsibilities:
/// - **Screen Coordination**: Manages navigation and screen lifecycle
/// - **Data Flow**: Coordinates between parent callbacks and view components
/// - **Parameter Validation**: Ensures required parameters are provided
/// - **Error Propagation**: Handles and propagates errors appropriately
///
/// ## Form Features:
/// - **Habit Configuration**: Name, description, and categorization
/// - **Visual Customization**: Icon and color selection with preview
/// - **Frequency Settings**: Daily, weekly, or custom frequency patterns
/// - **Reminder Configuration**: Notification timing and preferences
/// - **Target Goals**: Completion targets and progress tracking
/// - **Validation**: Real-time validation with user feedback
///
/// ## User Journey:
/// 1. **Navigation**: Access via floating action button or empty state
/// 2. **Form Completion**: Fill in habit details with guided assistance
/// 3. **Visual Preview**: See real-time preview of habit appearance
/// 4. **Validation**: Receive immediate feedback on form completion
/// 5. **Creation**: Submit form and return to dashboard with new habit
///
/// ## Error Handling:
/// - **Form Validation**: Prevents submission of invalid data
/// - **Duplicate Detection**: Warns about similar existing habits
/// - **User Feedback**: Clear error messages with correction suggestions
/// - **Graceful Recovery**: Maintains form state during error conditions
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