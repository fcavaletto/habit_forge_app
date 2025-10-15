import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../controllers/add_habit_controller.dart';
import '../widgets/forms/icon_selector.dart';
import '../widgets/forms/color_selector.dart';
import '../widgets/forms/frequency_selector.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/constants.dart';

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
  late ScrollController _scrollController;
  late ValueNotifier<Color> _lightColorNotifier;
  late ValueNotifier<Color> _darkColorNotifier;

  @override
  void initState() {
    super.initState();
    _controller = AddHabitController(
      onHabitAdded: widget.onHabitAdded,
      existingHabits: widget.existingHabits,
    );
    _scrollController = ScrollController();
    
    // Initialize with default colors (Slate)
    _lightColorNotifier = ValueNotifier<Color>(const Color(0xFF94a3b8));
    _darkColorNotifier = ValueNotifier<Color>(const Color(0xFF334155));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lightColorNotifier.dispose();
    _darkColorNotifier.dispose();
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
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_controller.errorMessage != null && _controller.errorMessage!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _controller.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Habit Name
            _buildSectionTitle('Habit Name'),
            TextField(
              controller: _controller.nameController,
              decoration: const InputDecoration(
                hintText: 'Enter habit name (e.g., "Drink Water")',
                border: OutlineInputBorder(),
              ),
              onChanged: _controller.onNameChanged,
            ),
            const SizedBox(height: 24),

            // Description
            _buildSectionTitle('Description (Optional)'),
            TextField(
              controller: _controller.descriptionController,
              decoration: const InputDecoration(
                hintText: 'Add a description for your habit',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: _controller.onDescriptionChanged,
            ),
            const SizedBox(height: 24),

            // Icon Selection
            _buildSectionTitle('Icon'),
            IconSelector(
              selectedIconName: _controller.selectedIconName,
              onIconSelected: _controller.onIconChanged,
            ),
            const SizedBox(height: 24),

            // Color Selection
            _buildSectionTitle('Color'),
            ValueListenableBuilder<Color>(
              valueListenable: _lightColorNotifier,
              builder: (context, lightColor, child) {
                return ValueListenableBuilder<Color>(
                  valueListenable: _darkColorNotifier,
                  builder: (context, darkColor, child) {
                    return ColorSelector(
                      selectedLightColor: lightColor,
                      selectedDarkColor: darkColor,
                      onColorSelected: (selectedLightColor, selectedDarkColor) {
                        _lightColorNotifier.value = selectedLightColor;
                        _darkColorNotifier.value = selectedDarkColor;
                        _controller.onColorChanged(selectedLightColor, selectedDarkColor);
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Frequency Selection
            _buildSectionTitle('Frequency'),
            FrequencySelector(
              frequencyData: _controller.frequencyData,
              onFrequencyChanged: _controller.onFrequencyChanged,
            ),
            const SizedBox(height: 24),

            // Target Goal
            _buildSectionTitle('Daily Target'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller.targetGoalController,
                    decoration: const InputDecoration(
                      hintText: '1',
                      border: OutlineInputBorder(),
                      labelText: 'Target per day',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _controller.onTargetGoalChanged,
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: _controller.allowExceedGoal,
                  onChanged: _controller.onAllowExceedGoalChanged,
                ),
                const SizedBox(width: 8),
                const Text('Allow exceeding goal'),
              ],
            ),
            const SizedBox(height: 32),

            // Create Habit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _controller.canCreateHabit ? _createHabit : null,
                child: const Text('Create Habit'),
              ),
            ),
            const SizedBox(height: 16),
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
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  void _createHabit() {
    _controller.createHabit();
  }
}