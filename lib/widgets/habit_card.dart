import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme.dart';
import '../utils/icon_utils.dart';
import '../screens/stats_screen.dart';
import '../services/virtual_date_service.dart';

/// Smart completion button that adapts its appearance and behavior
/// based on the habit's goal and current completion state.
class SmartCompletionButton extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const SmartCompletionButton({
    super.key,
    required this.habit,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final todayCount = habit.getCompletionCount(VirtualDateService().currentDate);
    final isCompleted = habit.isGoalAchieved(VirtualDateService().currentDate);
    final habitColor = Theme.of(context).colorScheme.habitColor(habit.colorIndex);

    // Determine button state
    final buttonState = _getButtonState(todayCount, isCompleted);

    return Semantics(
      label: _getAccessibilityLabel(todayCount, isCompleted),
      hint: _getAccessibilityHint(todayCount, isCompleted),
      button: true,
      child: InkWell(
        onTap: () => _handleButtonPress(todayCount, isCompleted),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getButtonColor(habitColor, buttonState),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress circle for multi-completion habits (goal > 1)
              if (habit.targetGoal > 1 && buttonState != ButtonState.completed) ...[
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: todayCount / habit.targetGoal,
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(habitColor.withValues(alpha: 0.8)),
                    backgroundColor: habitColor.withValues(alpha: 0.2),
                  ),
                ),
              ],
              // Main icon
              Icon(
                _getButtonIcon(buttonState),
                color: Colors.white,
                size: _getIconSize(buttonState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonState _getButtonState(int todayCount, bool isCompleted) {
    if (todayCount == 0) return ButtonState.empty;
    if (isCompleted) return ButtonState.completed;
    return ButtonState.inProgress;
  }

  Color _getButtonColor(Color habitColor, ButtonState state) {
    final alpha = state == ButtonState.empty ? 0.3 : 1.0;
    return habitColor.withValues(alpha: alpha);
  }

  IconData _getButtonIcon(ButtonState state) {
    switch (state) {
      case ButtonState.empty:
      case ButtonState.inProgress:
        return Icons.add;
      case ButtonState.completed:
        return Icons.check;
    }
  }

  double _getIconSize(ButtonState state) {
    return state == ButtonState.completed ? 28 : 24;
  }

  String _getAccessibilityLabel(int todayCount, bool isCompleted) {
    if (todayCount == 0) {
      return 'Add first completion for ${habit.name}';
    }
    if (isCompleted) {
      return 'Completed ${habit.name} - tap to reset';
    }
    return '${habit.name}: $todayCount of ${habit.targetGoal} completions - tap to add';
  }

  String _getAccessibilityHint(int todayCount, bool isCompleted) {
    if (todayCount == 0) {
      return 'Tap to add your first completion today';
    }
    if (isCompleted) {
      return 'Tap to remove all completions and start over';
    }
    return 'Tap to add another completion';
  }

  void _handleButtonPress(int todayCount, bool isCompleted) {
    if (todayCount == 0) {
      // Add first completion
      onIncrement?.call();
    } else if (isCompleted) {
      // Reset all completions
      onDecrement?.call();
    } else {
      // Add another completion
      onIncrement?.call();
    }
  }
}

enum ButtonState {
  empty,        // No completions
  inProgress,   // Some completions, not complete
  completed,    // Goal achieved
}

/// Interactive card widget displaying a habit with progress visualization
///
/// This is the primary UI component for displaying habits in the main dashboard.
/// Each card shows the habit's name, description, progress grid,
/// and provides interactive controls for completion and detailed viewing.
///
/// Key Features:
/// - Material 3 card design with theme-aware styling
/// - 7-day progress grid showing recent completion status
/// - Quick completion toggle button
/// - Tap-to-view detailed habit information
/// - Responsive design for various screen sizes
///
/// The card uses the habit's assigned color from the theme palette
/// and provides visual feedback for all user interactions.
class HabitCard extends StatelessWidget {
  /// The habit data to display in this card
  final Habit habit;

  /// Callback when the card is tapped (typically opens detailed view)
  final VoidCallback? onTap;

  /// Callback when the completion button is pressed
  final VoidCallback? onComplete;

  /// Callback when completion count should be incremented
  final VoidCallback? onIncrement;

  /// Callback when completion count should be decremented
  final VoidCallback? onDecrement;

  /// Callback for settings/accessibility actions (currently unused)
  final VoidCallback? onSettings;

  /// Callback when the habit should be archived
  final VoidCallback? onArchive;

  /// Callback when the habit should be deleted
  final VoidCallback? onDelete;

  /// Callback when the habit should be edited
  final VoidCallback? onEdit;

  /// Callback when stats should be viewed
  final VoidCallback? onStats;

  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onComplete,
    this.onIncrement,
    this.onDecrement,
    this.onSettings,
    this.onArchive,
    this.onDelete,
    this.onEdit,
    this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    // Get theme colors and habit-specific color
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = colorScheme.habitColor(habit.colorIndex);

    // Create accessibility labels - memoized for performance
    final todayCount = habit.getCompletionCount(VirtualDateService().currentDate);
    final completionStatus = todayCount > 0 ? '$todayCount completion${todayCount != 1 ? 's' : ''}' : 'not completed';
    final accessibilityLabel = '${habit.name}. ${habit.description}. Today: $completionStatus.';

    return Card(
      // Remove card margins to prevent overflow - grid handles spacing
      margin: EdgeInsets.zero,
      child: Semantics(
        label: accessibilityLabel,
        hint: 'Tap for options, long press to drag and reorder',
        button: true,
        child: InkWell(
          // Short tap shows context menu, long press handled by ReorderableListView
          onTap: () => _showContextMenu(context),
          // Rounded corners for modern Material 3 design
          borderRadius: BorderRadius.circular(12),
          focusColor: habitColor.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.all(12), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon and action buttons
                Row(
                  children: [
                    // Habit icon with themed background
                    Semantics(
                      label: 'Habit icon',
                      excludeSemantics: true,
                      child: Container(
                        width: 48, // 50% bigger (32 * 1.5)
                        height: 48,
                        decoration: BoxDecoration(
                          color: habitColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9), // Slightly larger radius
                        ),
                        child: Icon(
                          habit.iconName.toIconData,
                          color: habitColor,
                          size: 30, // 50% bigger (20 * 1.5)
                        ),
                      ),
                    ),

                    const Spacer(), // Push buttons to the right

                    // Action buttons row
                    Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stats button
                      Semantics(
                        label: 'View ${habit.name} statistics',
                        hint: 'Opens detailed statistics for this habit',
                        button: true,
                        child: InkWell(
                          onTap: onStats ?? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StatsScreen(habit: habit),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(24), // 50% bigger radius
                          child: Container(
                            width: 42, // 50% bigger (28 * 1.5)
                            height: 42,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bar_chart,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                              size: 24, // 50% bigger (16 * 1.5)
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Smart completion button - single button that adapts to state
                      SmartCompletionButton(
                        habit: habit,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Habit details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Habit text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Habit name
                        Text(
                          habit.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // Habit description
                        Text(
                          habit.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                ],
              ),

              const SizedBox(height: 8),

              // Progress chart - Compact version with completion intensity
              SizedBox(
                height: 32, // Smaller height
                child: Row(
                  children: List.generate(7, (index) {
                    final date = VirtualDateService().currentDate.subtract(Duration(days: 6 - index));
                    final count = habit.getCompletionCount(date);
                    final intensity = count > 0 ? (count / habit.targetGoal).clamp(0.0, 1.0) : 0.0; // Use actual goal for visualization

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: count > 0
                              ? habitColor.withValues(alpha: intensity)
                              : habitColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: habit.isGoalAchieved(date)
                            ? const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              )
                            : count > 0
                            ? Center(
                                child: Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// Show context menu for habit management actions
  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.habitColor(habit.colorIndex).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        habit.iconName.toIconData,
                        color: Theme.of(context).colorScheme.habitColor(habit.colorIndex),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            habit.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Menu items
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Habit'),
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit?.call();
                },
              ),

              ListTile(
                leading: const Icon(Icons.archive),
                title: const Text('Archive Habit'),
                subtitle: const Text('Hide from main view'),
                onTap: () {
                  Navigator.of(context).pop();
                  onArchive?.call();
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Habit',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                subtitle: const Text('Permanently remove'),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete?.call();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }


}

/// A more detailed habit card with 4-week grid chart for expanded view
class DetailedHabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onClose;

  const DetailedHabitCard({
    super.key,
    required this.habit,
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
                    habit.iconName.toIconData,
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
                        ? const Icon(
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

}
