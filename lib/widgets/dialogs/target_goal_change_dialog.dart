import 'package:flutter/material.dart';

/// Result of target goal change dialog interaction
enum TargetGoalChangeResult {
  updatePast, // Update past completion records with new goal
  keepPast, // Keep existing goal_at_completion values
  cancel, // Cancel the edit
}

/// Dialog shown when target goal is changed during habit editing
///
/// Explains the consequences of changing the target goal and provides
/// options for how to handle past completion records.
class TargetGoalChangeDialog extends StatelessWidget {
  final int oldGoal;
  final int newGoal;

  const TargetGoalChangeDialog({
    super.key,
    required this.oldGoal,
    required this.newGoal,
  });

  /// Show the dialog and return the user's choice
  static Future<TargetGoalChangeResult?> show(
    BuildContext context, {
    required int oldGoal,
    required int newGoal,
  }) async {
    return showDialog<TargetGoalChangeResult>(
      context: context,
      barrierDismissible: false, // Must choose an option
      builder: (context) => TargetGoalChangeDialog(
        oldGoal: oldGoal,
        newGoal: newGoal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Target Goal Changed'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changing the target goal from $oldGoal to $newGoal will affect '
              'how past completions are evaluated for streaks and completion rates.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'How would you like to handle past completion records?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Update Past Completions: Recalculate all past completion '
              'records to use the new goal. This will affect your current streak '
              'and completion rate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Keep Past Completions: Leave existing completion records '
              'unchanged. They will continue to use the goal that was active '
              'when they were recorded.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(TargetGoalChangeResult.cancel),
          child: const Text('Cancel'),
        ),
        // Keep Past button
        TextButton(
          onPressed: () => Navigator.of(context).pop(TargetGoalChangeResult.keepPast),
          child: const Text('Keep Past'),
        ),
        // Update Past button (primary action)
        FilledButton(
          onPressed: () => Navigator.of(context).pop(TargetGoalChangeResult.updatePast),
          child: const Text('Update Past'),
        ),
      ],
    );
  }
}

