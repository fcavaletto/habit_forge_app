import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_storage.dart';
import '../services/notification_service.dart';

/// Modal bottom sheet for adding a new habit
class AddHabitScreen extends StatefulWidget {
  final Function(Habit) onHabitAdded;
  final List<Habit> existingHabits;

  const AddHabitScreen({
    super.key,
    required this.onHabitAdded,
    required this.existingHabits,
  });

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIconName = 'check_circle';
  int _selectedColorIndex = 0;
  Frequency _selectedFrequency = Frequency.daily;
  TimeOfDay? _reminderTime;
  bool _enableReminders = false;

  bool _isLoading = false;

  /// Check if a habit with the same name and icon already exists
  bool _isDuplicateHabit(String name, String iconName) {
    return widget.existingHabits.any((habit) =>
      habit.name.toLowerCase() == name.toLowerCase().trim() &&
      habit.iconName == iconName
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() => _reminderTime = pickedTime);
    }
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional duplicate check (in case validation passed but duplicate still exists)
    if (_isDuplicateHabit(_nameController.text, _selectedIconName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A habit with this name and icon already exists'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final habit = Habit.create(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        colorIndex: _selectedColorIndex,
        iconName: _selectedIconName,
        reminderTime: _reminderTime,
        enableReminders: _enableReminders,
      );

      await habitStorage.saveHabit(habit);

      // Schedule reminder notification if enabled (with timeout to prevent hanging)
      if (_enableReminders && _reminderTime != null) {
        try {
          await notificationService.scheduleHabitReminder(habit).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('Notification scheduling timed out, but habit was saved');
            },
          );
        } catch (e) {
          debugPrint('Failed to schedule notification: $e');
          // Don't fail the habit creation if notification scheduling fails
        }
      }

      widget.onHabitAdded(habit);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Habit "${habit.name}" added successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Ensure modal closes even if there were issues
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving habit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Add New Habit',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.black),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Habit Name
                    Text(
                      'Habit Name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'e.g., Drink Water, Exercise',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a habit name';
                        }
                        if (value.trim().length < 2) {
                          return 'Habit name must be at least 2 characters';
                        }
                        if (_isDuplicateHabit(value, _selectedIconName)) {
                          return 'A habit with this name and icon already exists';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Description
                    Text(
                      'Description (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Add more details about your habit...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Icon Selection
                    Text(
                      'Icon',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IconSelector(
                      selectedIconName: _selectedIconName,
                      onIconSelected: (iconName) {
                        setState(() => _selectedIconName = iconName);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Color Selection
                    Text(
                      'Color',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ColorSelector(
                      selectedColorIndex: _selectedColorIndex,
                      onColorSelected: (index) {
                        setState(() => _selectedColorIndex = index);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Frequency Selection
                    Text(
                      'Frequency',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FrequencySelector(
                      selectedFrequency: _selectedFrequency,
                      onFrequencySelected: (frequency) {
                        setState(() => _selectedFrequency = frequency);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Reminder Settings
                    Text(
                      'Reminders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Enable Reminders Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Enable Daily Reminders',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Switch(
                            value: _enableReminders,
                            onChanged: (value) {
                              setState(() => _enableReminders = value);
                            },
                            activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Time Picker (only shown when reminders are enabled)
                    if (_enableReminders)
                      GestureDetector(
                        onTap: _selectReminderTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _reminderTime != null ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: _reminderTime != null ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _reminderTime != null
                                      ? 'Reminder at ${_reminderTime!.format(context)}'
                                      : 'Select reminder time',
                                  style: TextStyle(
                                    color: _reminderTime != null ? Colors.black : Colors.grey[600],
                                    fontWeight: _reminderTime != null ? FontWeight.w500 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveHabit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Habit',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon selector widget
class IconSelector extends StatelessWidget {
  final String selectedIconName;
  final Function(String) onIconSelected;

  const IconSelector({
    super.key,
    required this.selectedIconName,
    required this.onIconSelected,
  });

  static const List<String> availableIcons = [
    'check_circle',
    'fitness_center',
    'local_drink',
    'book',
    'bed',
    'restaurant',
    'directions_run',
    'school',
    'work',
    'favorite',
    'music_note',
    'self_improvement',
    'spa',
    'sports_soccer',
    'palette',
    'code',
    'create',
    'lightbulb',
    'nature',
    'pets',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: availableIcons.map((iconName) {
        final isSelected = iconName == selectedIconName;
        return GestureDetector(
          onTap: () => onIconSelected(iconName),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              _getIconData(iconName),
              color: isSelected ? Colors.blue : Colors.black,
              size: 24,
            ),
          ),
        );
      }).toList(),
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
      case 'music_note':
        return Icons.music_note;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'spa':
        return Icons.spa;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'create':
        return Icons.create;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'nature':
        return Icons.nature;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.check_circle;
    }
  }
}

/// Color selector widget
class ColorSelector extends StatelessWidget {
  final int selectedColorIndex;
  final Function(int) onColorSelected;

  const ColorSelector({
    super.key,
    required this.selectedColorIndex,
    required this.onColorSelected,
  });

  static const List<Color> habitColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFC107), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFFE91E63), // Pink
    Color(0xFF607D8B), // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(habitColors.length, (index) {
        final color = habitColors[index];
        final isSelected = index == selectedColorIndex;

        return GestureDetector(
          onTap: () => onColorSelected(index),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 4,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      }),
    );
  }
}

/// Frequency selector widget
class FrequencySelector extends StatelessWidget {
  final Frequency selectedFrequency;
  final Function(Frequency) onFrequencySelected;

  const FrequencySelector({
    super.key,
    required this.selectedFrequency,
    required this.onFrequencySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: Frequency.values.map((frequency) {
        final isSelected = frequency == selectedFrequency;
        return GestureDetector(
          onTap: () => onFrequencySelected(frequency),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frequency.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        frequency.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Frequency enum for habit scheduling
enum Frequency {
  daily('Daily', 'Every day'),
  threeTimesWeek('3x per week', 'Three times per week'),
  custom('Custom', 'Set your own schedule');

  const Frequency(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Extension to get icon from habit icon name
extension HabitIconExtension on String {
  IconData get toIconData {
    switch (this) {
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
      case 'music_note':
        return Icons.music_note;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'spa':
        return Icons.spa;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'create':
        return Icons.create;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'nature':
        return Icons.nature;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.check_circle;
    }
  }
}
