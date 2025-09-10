import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../controllers/add_habit_controller.dart';
import '../widgets/forms/icon_selector.dart';
import '../widgets/forms/color_selector.dart';
import '../widgets/forms/frequency_selector.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/constants.dart';
import '../providers/app_state_provider.dart';

/// Add Habit View - Pure UI component for adding new habits
///
/// This widget contains only the UI rendering logic and delegates all
/// business logic to the AddHabitController. It uses the extracted
/// form widgets for a clean, maintainable structure.
class AddHabitView extends StatefulWidget {
  final Function(Habit) onHabitAdded;
  final List<Habit> existingHabits;

  const AddHabitView({
    super.key,
    required this.onHabitAdded,
    required this.existingHabits,
  });

  @override
  State<AddHabitView> createState() => _AddHabitViewState();
}

class _AddHabitViewState extends State<AddHabitView> {
  late AddHabitController _controller;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _controller = AddHabitController(
      onHabitAdded: widget.onHabitAdded,
      existingHabits: widget.existingHabits,
      appState: appState,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Habit'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SafeScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Error message
          if (_controller.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _controller.errorMessage!,
                style: TextStyle(color: Colors.red[800]),
              ),
            ),

          // Habit Name
          _buildSectionTitle('Habit Name'),
          TextFormField(
            controller: _controller.nameController,
            decoration: const InputDecoration(
              hintText: 'Enter habit name',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // Habit Description
          _buildSectionTitle('Description (Optional)'),
          TextFormField(
            controller: _controller.descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe your habit (optional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // Icon Selection
          _buildSectionTitle('Icon'),
          IconSelector(
            selectedIconName: _controller.selectedIconName,
            onIconSelected: (icon) => setState(() => _controller.onIconChanged(icon)),
          ),

          const SizedBox(height: 24),

          // Color Selection
          _buildSectionTitle('Color'),
          ColorSelector(
            selectedColorIndex: _controller.selectedColorIndex,
            onColorSelected: (color) => setState(() => _controller.onColorChanged(color)),
          ),

          const SizedBox(height: 24),

          // Target Goal
          _buildSectionTitle('Target Goal'),
          TextFormField(
            controller: _controller.targetGoalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter target completions per day',
              border: OutlineInputBorder(),
              helperText: 'How many times do you want to complete this habit daily?',
            ),
          ),

          const SizedBox(height: 24),

          // Frequency Selection
          _buildSectionTitle('Frequency'),
          FrequencySelector(
            frequencyData: _controller.frequencyData,
            onFrequencyChanged: (freq) => setState(() => _controller.onFrequencyChanged(freq)),
          ),

          const SizedBox(height: 24),

          // Reminder Settings
          _buildSectionTitle('Reminders'),
          SwitchListTile(
            title: const Text('Enable Daily Reminders'),
            value: _controller.enableReminders,
            onChanged: (value) => setState(() => _controller.enableReminders = value),
          ),

          if (_controller.enableReminders) ...[
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Reminder Time'),
              subtitle: Text(_controller.reminderTime?.format(context) ?? 'Not set'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _controller.reminderTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _controller.reminderTime = time);
                }
              },
            ),
          ],

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _controller.isLoading ? null : () => _saveHabit(context),
              child: _controller.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Habit'),
            ),
          ),

          const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _saveHabit(BuildContext context) async {
    await _controller.saveHabit();

    if (_controller.errorMessage == null) {
      // Success - close the screen
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Error - refresh UI to show error message
      setState(() {});
    }
  }
}
