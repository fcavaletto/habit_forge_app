import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme.dart';

/// Interactive card widget displaying a habit with progress visualization
///
/// This is the primary UI component for displaying habits in the main dashboard.
/// Each card shows the habit's name, description, progress grid, streak counter,
/// and provides interactive controls for completion and detailed viewing.
///
/// Key Features:
/// - Material 3 card design with theme-aware styling
/// - 7-day progress grid showing recent completion status
/// - Streak counter with visual prominence
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

  /// Callback for settings/accessibility actions (currently unused)
  final VoidCallback? onSettings;

  /// Callback when the habit should be archived
  final VoidCallback? onArchive;

  /// Callback when the habit should be deleted
  final VoidCallback? onDelete;

  /// Callback when the habit should be edited
  final VoidCallback? onEdit;

  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onComplete,
    this.onSettings,
    this.onArchive,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Get theme colors and habit-specific color
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = colorScheme.habitColor(habit.colorIndex);

    return Card(
      // Card styling with consistent margins and elevation
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        // Tap handler for opening detailed view
        onTap: onTap,
        // Long press handler for context menu
        onLongPress: () => _showContextMenu(context),
        // Rounded corners for modern Material 3 design
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Habit icon with themed background
              // Shows Material Icon with habit's assigned color
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  // Semi-transparent background using habit color
                  color: habitColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(habit.iconName), // Convert string to IconData
                  color: habitColor, // Use full opacity for icon
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

                    // Progress chart - Visual representation of recent habit completion
                    // Uses habit.last7Days computed property for efficient data access
                    SizedBox(
                      height: 50, // Fixed height for consistent layout
                      child: Row(
                        // Map each day to a visual indicator
                        children: habit.last7Days.map((completed) {
                          return Expanded( // Equal width for each day
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1), // Small gaps between days
                              decoration: BoxDecoration(
                                // Completed days: full habit color, incomplete: very light tint
                                color: completed
                                    ? habitColor
                                    : habitColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2), // Rounded corners
                              ),
                              child: completed
                                  ? Icon( // Check mark for completed days
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
                        _getIconData(habit.iconName),
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
