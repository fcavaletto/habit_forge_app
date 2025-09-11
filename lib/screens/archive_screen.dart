import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/icon_utils.dart';

/// Archive Screen - Displays archived habits with restore functionality
///
/// Shows a list of all archived habits with options to restore them.
/// Provides an empty state when no habits are archived.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Habit> _archivedHabits = [];
  bool _isLoading = true;
  bool _isManuallyRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadArchivedHabits();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload archived habits when the screen becomes visible
    // This handles cases where user archives/restores habits and returns to this screen
    // Skip if we're in the middle of a manual refresh (like undo)
    if (!_isManuallyRefreshing) {
      _loadArchivedHabits();
    }
  }

  Future<void> _loadArchivedHabits() async {
    setState(() => _isLoading = true);
    try {
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      final archivedHabits = await habitProvider.repository.getArchivedHabits();
      setState(() {
        _archivedHabits = archivedHabits;
        _isLoading = false;
        _isManuallyRefreshing = false; // Reset flag after loading
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isManuallyRefreshing = false; // Reset flag even on error
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load archived habits: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _restoreHabit(Habit habit) async {
    try {
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      await habitProvider.unarchiveHabit(habit.id);
      setState(() {
        _archivedHabits.removeWhere((h) => h.id == habit.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${habit.name}" has been restored'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _undoRestore(habit),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore habit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _undoRestore(Habit habit) async {
    try {
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      await habitProvider.archiveHabit(habit.id);
      _isManuallyRefreshing = true; // Set flag to prevent automatic reload conflicts
      _loadArchivedHabits(); // Reload to show the restored archived habit
    } catch (e) {
      _isManuallyRefreshing = false; // Reset flag on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to undo restore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Habit'),
        content: Text(
          'Are you sure you want to permanently delete "${habit.name}"? '
          'This action cannot be undone and all completion history will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final habitProvider = Provider.of<HabitProvider>(context, listen: false);
        await habitProvider.deleteHabit(habit.id);
        if (mounted) {
          setState(() {
            _archivedHabits.removeWhere((h) => h.id == habit.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${habit.name}" has been permanently deleted'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete habit: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Habits'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archivedHabits.isEmpty
              ? SafeScrollableWrapper(child: _buildEmptyState())
              : SafeScrollView(
                  child: _buildHabitsList(),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Archived Habits',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Habits you archive will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _archivedHabits.length,
      itemBuilder: (context, index) {
        final habit = _archivedHabits[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Habit Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    habit.iconName.toIconData,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Habit Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        habit.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Archived on ${habit.createdAt.toString().split(' ')[0]}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Column(
                  children: [
                    TextButton.icon(
                      onPressed: () => _restoreHabit(habit),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Restore'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _permanentlyDeleteHabit(habit),
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}