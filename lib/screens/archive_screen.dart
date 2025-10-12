import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/app_state_provider.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/icon_utils.dart';
import '../services/service_factory.dart';
import '../services/atomic_data_service.dart';

/// Archive Screen - Displays archived habits with restore functionality
///
/// Shows a list of all archived habits with options to restore them.
/// Provides an empty state when no habits are archived.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with WidgetsBindingObserver {
  List<Habit> _archivedHabits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadArchivedHabits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload archived habits when the app resumes
    // This handles cases where user archives/restores habits and returns to this screen
    if (state == AppLifecycleState.resumed) {
      _loadArchivedHabits();
    }
  }

  Future<void> _loadArchivedHabits() async {
    debugPrint('🔄 Archive Screen: Starting to load archived habits...');
    setState(() => _isLoading = true);
    try {
      // Use the new ArchiveDataPreparationService for optimized loading
      final result = await ServiceFactory.archiveDataService.getArchivedHabits(
        context: DataAccessContext(
          component: 'ArchiveScreen',
          operation: 'loadArchivedHabits',
        ),
      );
      
      if (result.success && result.data != null) {
        final archivedHabits = result.data!;
        debugPrint('🔄 Archive Screen: Retrieved ${archivedHabits.length} archived habits via DataPreparationService');
        
        // Log each habit for debugging
        for (int i = 0; i < archivedHabits.length; i++) {
          final habit = archivedHabits[i];
          debugPrint('📦 Archived Habit $i: ${habit.name} (ID: ${habit.id}, Archived: ${habit.isArchived})');
        }
        
        setState(() {
          _archivedHabits = archivedHabits;
          _isLoading = false;
        });
        debugPrint('✅ Archive Screen: Successfully loaded ${_archivedHabits.length} archived habits');
      } else {
        setState(() => _isLoading = false);
        debugPrint('❌ Archive Screen: Failed to load archived habits: ${result.errorMessage}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Archive Screen: Failed to load archived habits: $e');
      debugPrint('❌ Archive Screen: Error type: ${e.runtimeType}');
      debugPrint('❌ Archive Screen: Stack trace: ${StackTrace.current}');
    }
  }


  Future<void> _restoreHabit(Habit habit) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final habitProvider = appState.habitProvider;
      await habitProvider.unarchiveHabit(habit.id);
      setState(() {
        _archivedHabits.removeWhere((h) => h.id == habit.id);
      });
      
      // Use post-frame callback to show success message
      SchedulerBinding.instance.addPostFrameCallback((_) {
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
      });
    } catch (e) {
      // Use post-frame callback to show error message
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore habit: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _undoRestore(Habit habit) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final habitProvider = appState.habitProvider;
      await habitProvider.archiveHabit(habit.id);
      _loadArchivedHabits(); // Reload to show the restored archived habit
    } catch (e) {
      // Use post-frame callback to show error message
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to undo restore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
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

          if (confirmed == true && mounted) {
            try {
              final appState = Provider.of<AppState>(context, listen: false);
              final habitProvider = appState.habitProvider;
              await habitProvider.deleteHabit(habit.id);
              setState(() {
                _archivedHabits.removeWhere((h) => h.id == habit.id);
              });
              
              // Use post-frame callback to show success message
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${habit.name}" has been permanently deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            } catch (e) {
              // Use post-frame callback to show error message
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete habit: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
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
              : SafeCustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
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
                          childCount: _archivedHabits.length,
                        ),
                      ),
                    ),
                  ],
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

}