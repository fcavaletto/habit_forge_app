import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'theme.dart';
import 'models/habit.dart';
import 'models/habit_storage.dart';
import 'widgets/habit_card.dart';
import 'screens/add_habit_screen.dart';
import 'screens/calendar_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Starting app initialization...');

  // Initialize storage
  debugPrint('Initializing storage...');
  await habitStorage.getHabits(); // Warm up storage
  debugPrint('Storage initialized');

  // Initialize notifications with error handling and timeout
  try {
    debugPrint('Initializing notifications...');
    await notificationService.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('Notification initialization timed out');
        return;
      },
    );
    debugPrint('Notifications initialized successfully');
  } catch (e) {
    // If notification initialization fails, continue without it
    debugPrint('Failed to initialize notifications: $e');
  }

  debugPrint('Starting Flutter app...');
  runApp(const HabitForgeApp());
}

class HabitForgeApp extends StatefulWidget {
  const HabitForgeApp({super.key});

  @override
  State<HabitForgeApp> createState() => _HabitForgeAppState();
}

class _HabitForgeAppState extends State<HabitForgeApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitKit',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: HabitDashboard(
        themeMode: _themeMode,
        onThemeChanged: _saveThemeMode,
      ),
    );
  }
}

class HabitDashboard extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HabitDashboard({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HabitDashboard> createState() => _HabitDashboardState();
}

class _HabitDashboardState extends State<HabitDashboard> {
  List<Habit> _habits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _checkOverdueHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    final habits = await habitStorage.getHabits();
    setState(() {
      _habits = habits;
      _isLoading = false;
    });

    // Check for overdue habits after loading
    _checkOverdueHabits();
  }

  void _checkOverdueHabits() {
    final now = DateTime.now();
    final overdueHabits = _habits.where((habit) {
      if (!habit.enableReminders) return false;

      // Check if habit was supposed to be completed yesterday or earlier
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      return !habit.isCompleted(yesterday) || !habit.isCompleted(now);
    }).toList();

    if (overdueHabits.isNotEmpty) {
      // Show banner for the first overdue habit
      final overdueHabit = overdueHabits.first;
      _showOverdueBanner(overdueHabit);
    }
  }

  void _showOverdueBanner(Habit habit) {
    // Use Future.delayed to ensure the widget is fully built
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"${habit.name}" is overdue! Complete it now.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Complete',
            textColor: Colors.white,
            onPressed: () {
              _markHabitComplete(habit);
            },
          ),
        ),
      );
    });
  }

  Future<void> _addSampleHabits() async {
    final sampleHabits = [
      Habit.create(
        name: 'Drink Water',
        description: 'Drink 8 glasses of water daily',
        colorIndex: 0,
        iconName: 'local_drink',
      ),
      Habit.create(
        name: 'Exercise',
        description: '30 minutes of physical activity',
        colorIndex: 1,
        iconName: 'fitness_center',
      ),
      Habit.create(
        name: 'Read Book',
        description: 'Read for at least 20 minutes',
        colorIndex: 2,
        iconName: 'book',
      ),
      Habit.create(
        name: 'Sleep Early',
        description: 'Go to bed by 10 PM',
        colorIndex: 3,
        iconName: 'bed',
      ),
    ];

    for (final habit in sampleHabits) {
      await habitStorage.saveHabit(habit);
    }

    await _loadHabits();
  }

  Future<void> _markHabitComplete(Habit habit) async {
    final today = DateTime.now();
    final isCompleted = habit.isCompleted(today);

    await habitStorage.updateHabitCompletion(
      habit.id,
      today,
      !isCompleted, // Toggle completion
    );

    // If habit is now completed, reschedule the reminder for tomorrow
    // If habit is marked incomplete, schedule reminder for today
    if (!isCompleted && habit.enableReminders) {
      await notificationService.scheduleHabitReminder(habit);
    }

    await _loadHabits();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SettingsBottomSheet(
        currentThemeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onAddSampleHabits: _addSampleHabits,
      ),
    );
  }

  void _showAddHabitDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitScreen(
        onHabitAdded: (habit) {
          _loadHabits();
        },
        existingHabits: _habits,
      ),
    );
  }

  void _showHabitDetails(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: DetailedHabitCard(
            habit: habit,
            onComplete: () => _markHabitComplete(habit),
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HabitKit'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CalendarScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_today),
          ),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: _showAddHabitDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? _buildEmptyState()
              : _buildHabitList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.track_changes,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No habits yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first habit to get started!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddHabitDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Habit'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _addSampleHabits,
            child: const Text('Add Sample Habits'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitList() {
    return RefreshIndicator(
      onRefresh: _loadHabits,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _habits.length,
        itemBuilder: (context, index) {
          final habit = _habits[index];
          return HabitCard(
            habit: habit,
            onTap: () => _showHabitDetails(habit),
            onComplete: () => _markHabitComplete(habit),
          );
        },
      ),
    );
  }
}

class SettingsBottomSheet extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onAddSampleHabits;

  const SettingsBottomSheet({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    required this.onAddSampleHabits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeOption(
                  context,
                  'Light',
                  ThemeMode.light,
                  Icons.light_mode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  context,
                  'Dark',
                  ThemeMode.dark,
                  Icons.dark_mode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  context,
                  'System',
                  ThemeMode.system,
                  Icons.settings_suggest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              onAddSampleHabits();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Sample Habits'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    IconData icon,
  ) {
    final isSelected = currentThemeMode == mode;
    return InkWell(
      onTap: () {
        onThemeChanged(mode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DEPRECATED: Old AddHabitDialog class - replaced with AddHabitScreen modal bottom sheet
// This class is no longer used but kept for reference
/*
class AddHabitDialog extends StatefulWidget {
  final VoidCallback onHabitAdded;

  const AddHabitDialog({super.key, required this.onHabitAdded});

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedColorIndex = 0;
  String _selectedIcon = 'check_circle';

  final List<String> _availableIcons = [
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
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveHabit() async {
    if (_nameController.text.trim().isEmpty) return;

    final habit = Habit.create(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      colorIndex: _selectedColorIndex,
      iconName: _selectedIcon,
    );

    await habitStorage.saveHabit(habit);
    widget.onHabitAdded();

    // Use a post-frame callback to ensure context is still valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Add New Habit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                hintText: 'e.g., Drink Water',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Drink 8 glasses daily',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: colorScheme.habitColors.length,
                itemBuilder: (context, index) {
                  final color = colorScheme.habitColors[index];
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Icon',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final iconName = _availableIcons[index];
                  final isSelected = _selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveHabit,
          child: const Text('Add Habit'),
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
*/