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
import '../widgets/dialogs/pro_upgrade_dialog.dart';
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
  final Function(Habit)? onHabitUpdated;
  final List<Habit> existingHabits;
  final Habit? habitToEdit;

  const AddHabitView({
    super.key,
    required this.onHabitAdded,
    this.onHabitUpdated,
    required this.existingHabits,
    this.habitToEdit,
  });

  @override
  State<AddHabitView> createState() => _AddHabitViewState();
}

class _AddHabitViewState extends State<AddHabitView> {
  late AddHabitController _controller;
  late ScrollController _scrollController;
  bool _didInitColors = false;
  bool _isPreviewExpanded = true; // Default to expanded
  bool _isAdvancedOptionsExpanded = false; // Default to collapsed

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    
    // Filter out the habit being edited from existing habits for duplicate check
    final filteredHabits = widget.habitToEdit != null
        ? widget.existingHabits.where((h) => h.id != widget.habitToEdit!.id).toList()
        : widget.existingHabits;
    
    _controller = AddHabitController(
      onHabitAdded: widget.onHabitAdded,
      onHabitUpdated: widget.onHabitUpdated,
      existingHabits: filteredHabits,
      appState: appState,
      existingHabit: widget.habitToEdit,
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

    // Initialize random color selection once per screen open (only for create mode)
    if (!_didInitColors && !_controller.isEditMode) {
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
        title: Text(_controller.isEditMode ? 'Edit Habit' : 'Add New Habit'),
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
                          // Hide collapse button and always show collapsed in preview/edit mode
                          hideCollapseButton: true,
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
              maxLines: 1,
              textInputAction: TextInputAction.done,
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

            // Advanced Options (Collapsible)
            _buildAdvancedOptionsSection(),

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
                    : Text(_controller.isEditMode ? 'Save Changes' : 'Create Habit'),
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

  /// Builds the collapsible Advanced Options section
  Widget _buildAdvancedOptionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Collapsible header with toggle button
          InkWell(
            onTap: () {
              setState(() {
                _isAdvancedOptionsExpanded = !_isAdvancedOptionsExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Advanced Options',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Collapse/expand icon with rotation animation
                  AnimatedRotation(
                    turns: _isAdvancedOptionsExpanded ? 0.5 : 0,
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

          // Collapsible advanced options content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: ClipRect(
              child: _isAdvancedOptionsExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Frequency Selection
                          _buildSectionTitle('Frequency'),
                          Builder(
                            builder: (context) {
                              final appState = context.read<AppState>();
                              return FrequencySelector(
                                frequencyData: _controller.frequencyData,
                                isProActive: appState.isProSubscriptionActive,
                                onFrequencyChanged: (freq) {
                                  setState(() {
                                    _controller.onFrequencyChanged(freq);
                                    _updatePreview();
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // Target Goal
                          _buildSectionTitle('Target Goal'),
                          _buildNumericInputWithButtons(),

                          const SizedBox(height: 24),

                          // Allow Exceed Goal
                          Builder(
                            builder: (context) {
                              final appState = context.read<AppState>();
                              final isProActive =
                                  appState.isProSubscriptionActive;

                              return ListTile(
                                title: const Text(
                                  'Allow completions beyond Target Goal',
                                ),
                                subtitle: const Text(
                                  'Track completions even after the goal is met',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isProActive) ...[
                                      Icon(
                                        Icons.lock,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Switch(
                                      value: _controller.allowExceedGoal,
                                      onChanged: (value) {
                                        // Check PRO subscription before allowing toggle
                                        if (value && !isProActive) {
                                          // Show PRO upgrade dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => ProUpgradeDialog(
                                              title: 'Allow Exceed Goal',
                                              message:
                                                  'Unlock advanced tracking with PRO! Upgrade to allow completions beyond your daily target goal.',
                                              onUpgrade: () {
                                                // For now, do nothing when "Upgrade to Pro" is tapped
                                                // TODO: Implement actual upgrade flow
                                              },
                                            ),
                                          );
                                          return;
                                        }

                                        // PRO is active or disabling - allow toggle
                                        setState(() {
                                          _controller.allowExceedGoal = value;
                                          _updatePreview();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Reminder Settings
                          _buildSectionTitle('Reminders'),
                          Builder(
                            builder: (context) {
                              final appState = context.read<AppState>();
                              final isProActive =
                                  appState.isProSubscriptionActive;

                              return ListTile(
                                title: const Text('Enable Daily Reminders'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isProActive) ...[
                                      Icon(
                                        Icons.lock,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Switch(
                                      value: _controller.enableReminders,
                                      onChanged: (value) {
                                        // Check PRO subscription
                                        if (!isProActive) {
                                          // Show PRO upgrade dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => ProUpgradeDialog(
                                              title: 'Daily Reminders',
                                              message:
                                                  'Unlock daily reminders with PRO! Get notified to complete your habits at your preferred time.',
                                              onUpgrade: () {
                                                // TODO: Implement actual upgrade flow
                                              },
                                            ),
                                          );
                                          return;
                                        }

                                        // PRO is active - allow toggle
                                        setState(() {
                                          _controller.enableReminders = value;
                                          if (!value) {
                                            _controller.reminderTime = null;
                                          }
                                          _updatePreview();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          if (_controller.enableReminders) ...[
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final appState = context.read<AppState>();
                                final isProActive =
                                    appState.isProSubscriptionActive;

                                return ListTile(
                                  title: const Text('Reminder Time'),
                                  subtitle: Text(
                                    _controller.reminderTime?.format(context) ??
                                        'Not set',
                                  ),
                                  trailing: const Icon(Icons.access_time),
                                  onTap: () {
                                    // Check PRO subscription
                                    if (!isProActive) {
                                      // Show PRO upgrade dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => ProUpgradeDialog(
                                          title: 'Daily Reminders',
                                          message:
                                              'Unlock daily reminders with PRO! Get notified to complete your habits at your preferred time.',
                                          onUpgrade: () {
                                            // TODO: Implement actual upgrade flow
                                          },
                                        ),
                                      );
                                      return;
                                    }

                                    // PRO is active - show time picker
                                    showTimePicker(
                                      context: context,
                                      initialTime:
                                          _controller.reminderTime ??
                                          TimeOfDay.now(),
                                    ).then((time) {
                                      if (time != null) {
                                        setState(
                                          () => _controller.reminderTime = time,
                                        );
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a numeric input field with increment/decrement buttons
  Widget _buildNumericInputWithButtons() {
    final currentValue = _controller.getCurrentTargetGoal();
    final canDecrement = currentValue > 1;
    final canIncrement = currentValue < 1000;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Numeric input field
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _controller.targetGoalController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '1',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    // Trigger rebuild to update button states
                  });
                  _updatePreview();
                },
              ),
            ),
            const SizedBox(width: 8),
            // Decrement button
            SizedBox(
              width: 48,
              height: 56,
              child: IconButton(
                onPressed: canDecrement
                    ? () {
                        setState(() {
                          _controller.decrementTargetGoal();
                          _updatePreview();
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: canDecrement
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Increment button
            SizedBox(
              width: 48,
              height: 56,
              child: IconButton(
                onPressed: canIncrement
                    ? () {
                        setState(() {
                          _controller.incrementTargetGoal();
                          _updatePreview();
                        });
                      }
                    : null,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: canIncrement
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Text(
            'Daily completion target',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveHabit(BuildContext context) async {
    await _controller.saveHabit(context: context);

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
