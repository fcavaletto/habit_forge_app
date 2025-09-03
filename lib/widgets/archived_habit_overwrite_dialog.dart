import 'package:flutter/material.dart';
import '../models/habit.dart';

/// Dialog shown when attempting to create a habit that matches an archived habit
///
/// This dialog gives users the choice to overwrite (unarchive) the existing archived habit
/// or cancel the creation process. It provides clear information about what will happen
/// if they choose to overwrite.
class ArchivedHabitOverwriteDialog extends StatelessWidget {
  final Habit archivedHabit;
  final VoidCallback onOverwrite;
  final VoidCallback onCancel;

  const ArchivedHabitOverwriteDialog({
    super.key,
    required this.archivedHabit,
    required this.onOverwrite,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Habit Already Exists (Archived)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A habit named "${archivedHabit.name}" with the same icon already exists but is currently archived.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'If you overwrite it:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildConsequenceItem('The habit will be unarchived and appear in your main list'),
          _buildConsequenceItem('Your completion history will be preserved'),
          _buildConsequenceItem('The habit properties will be updated with your new settings'),
          const SizedBox(height: 16),
          const Text(
            'Do you want to overwrite the archived habit?',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOverwrite();
          },
          child: const Text('Overwrite'),
        ),
      ],
    );
  }

  Widget _buildConsequenceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
