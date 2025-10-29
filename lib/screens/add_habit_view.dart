import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/habit.dart';
import '../controllers/add_habit_controller.dart';
import '../widgets/forms/icon_selector.dart';
import '../widgets/forms/color_selector.dart';
import '../widgets/forms/frequency_selector.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../widgets/habit_card.dart';
import '../utils/constants.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';

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
  bool _didInitColors = false;
  bool _isPreviewExpanded = true; // Default to expanded

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _controller = AddHabitController(
      onHabitAdded: widget.onHabitAdded,
      existingHabits: widget.existingHabits,
      appState: appState,
    );
    _scrollController = ScrollController();

    // Add listeners to trigger preview updates
    _controller.nameController.addListener(_updatePreview);
    _controller.descriptionController.addListener(_updatePreview);
    _controller.targetGoalController.addListener(_updatePreview);
  }

  void _updatePreview() {
    setState(() {
      // Trigger rebuild of preview section
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize random color selection once per screen open
    if (!_didInitColors) {
      final colorScheme = Theme.of(context).colorScheme;
      final random = math.Random();
      final randomIndex = random.nextInt(20); // 0-19 (20 predefined colors)
      final colorPair = colorScheme.habitColorPairs[randomIndex];

      _controller.onColorChanged(colorPair.light, colorPair.dark);
      _didInitColors = true;
    }
  }

  @override
  void dispose() {
    // Remove listeners
    _controller.nameController.removeListener(_updatePreview);
    _controller.descriptionController.removeListener(_updatePreview);
    _controller.targetGoalController.removeListener(_updatePreview);

    _controller.dispose();
    _scrollController.dispose();
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
      body: Column(
        children: [
          // Fixed preview section at top
          _buildPreviewSection(),

          // Scrollable form content below
          Expanded(child: _buildScrollableForm()),
        ],
      ),
    );
  }

  /// Builds the fixed, collapsible habit preview card section
  Widget _buildPreviewSection() {
    final previewHabit = _controller.buildPreviewHabit();
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapsible header with toggle button
          InkWell(
            onTap: () {
              setState(() {
                _isPreviewExpanded = !_isPreviewExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.preview,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Preview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'How it will look',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  // Collapse/expand icon with rotation animation
                  AnimatedRotation(
                    turns: _isPreviewExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible preview card content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: ClipRect(
              child: _isPreviewExpanded
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Opacity(
                        opacity: 0.95,
                        child: HabitCard(
                          habit: previewHabit,
                          // Disable all interactions
                          onTap: null,
                          onComplete: null,
                          onIncrement: null,
                          onDecrement: null,
                          onCustomCompletion: null,
                          onEdit: null,
                          onArchive: null,
                          onDelete: null,
                          onStats: null,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the scrollable form content (without preview)
  Widget _buildScrollableForm() {
    return SafeScrollView(
      controller: _scrollController,
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
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'Enter habit name',
                border: OutlineInputBorder(),
                counterText: '', // Hide character counter
              ),
            ),
            const SizedBox(height: 24),

            // Habit Description
            _buildSectionTitle('Description (Optional)'),
            TextFormField(
              controller: _controller.descriptionController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Describe your habit (optional)',
                border: OutlineInputBorder(),
                counterText: '', // Hide character counter
              ),
            ),
            const SizedBox(height: 24),

            // Icon Selection
            _buildSectionTitle('Icon'),
            IconSelector(
              selectedIconName: _controller.selectedIconName,
              onIconSelected: (icon) {
                setState(() {
                  _controller.onIconChanged(icon);
                  _updatePreview();
                });
              },
            ),
            const SizedBox(height: 24),

            // Color Selection
            _buildSectionTitle('Color'),
            ColorSelector(
              selectedLightColor: Color(_controller.selectedLightColor),
              selectedDarkColor: Color(_controller.selectedDarkColor),
              onColorSelected: (lightColor, darkColor) {
                setState(() {
                  _controller.onColorChanged(lightColor, darkColor);
                  _updatePreview();
                });
              },
            ),
            const SizedBox(height: 24),

            // Frequency Selection
            _buildSectionTitle('Frequency'),
            FrequencySelector(
              frequencyData: _controller.frequencyData,
              onFrequencyChanged: (freq) {
                setState(() {
                  _controller.onFrequencyChanged(freq);
                  _updatePreview();
                });
              },
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
                helperText:
                    'How many times do you want to complete this habit daily?',
              ),
            ),

            const SizedBox(height: 24),

            // Allow Exceed Goal
            _buildSectionTitle('Advanced Options'),
            CheckboxListTile(
              title: const Text('Allow completions beyond target goal'),
              subtitle: const Text(
                'Continue tracking completions even after reaching your daily goal',
              ),
              value: _controller.allowExceedGoal,
              onChanged: (value) {
                setState(() {
                  _controller.allowExceedGoal = value ?? false;
                  _updatePreview();
                });
              },
            ),

            const SizedBox(height: 24),

            // Reminder Settings
            _buildSectionTitle('Reminders'),
            SwitchListTile(
              title: const Text('Enable Daily Reminders'),
              value: _controller.enableReminders,
              onChanged: (value) =>
                  setState(() => _controller.enableReminders = value),
            ),

            if (_controller.enableReminders) ...[
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Reminder Time'),
                subtitle: Text(
                  _controller.reminderTime?.format(context) ?? 'Not set',
                ),
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
                onPressed: _controller.isLoading
                    ? null
                    : () => _saveHabit(context),
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
    // Extract theme outside to make widget more efficient
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
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
      // Error - refresh UI to show error message and scroll to top
      setState(() {});

      // Scroll to top to make error message visible
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }
}
