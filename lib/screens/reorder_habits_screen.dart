import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';

class ReorderHabitsScreen extends StatefulWidget {
  const ReorderHabitsScreen({super.key});

  @override
  State<ReorderHabitsScreen> createState() => _ReorderHabitsScreenState();
}

class _ReorderHabitsScreenState extends State<ReorderHabitsScreen> {
  late ScrollController _scrollController;
  late List<Habit> _localHabits;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final hp = context.read<AppState>().habitProvider;
    _localHabits = List.of(hp.filteredHabits);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;

    final moved = _localHabits.removeAt(oldIndex);
    _localHabits.insert(newIndex, moved);
    setState(() {});

    final appState = context.read<AppState>();
    final hp = appState.habitProvider;
    final visibleIds = hp.getVisibleHabitIds();

    try {
      await hp.reorderHabitsInContext(moved.id, newIndex, visibleIds);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      _localHabits = List.of(hp.filteredHabits);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Habits'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        scrollController: _scrollController,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        itemCount: _localHabits.length,
        onReorder: _onReorder,
        itemBuilder: (context, index) {
          final habit = _localHabits[index];
          return _ReorderHabitTile(
            key: ValueKey(habit.id),
            habit: habit,
            index: index,
            theme: theme,
          );
        },
      ),
    );
  }
}

class _ReorderHabitTile extends StatelessWidget {
  final Habit habit;
  final int index;
  final ThemeData theme;

  const _ReorderHabitTile({
    super.key,
    required this.habit,
    required this.index,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final habitColor = theme.brightness == Brightness.light
        ? Color(habit.lightColorValue)
        : Color(habit.darkColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: theme.brightness == Brightness.light ? 1 : 0.5,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: habitColor, width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(habit.iconName.toIconData, color: habitColor, size: 22),
        ),
        title: Text(
          habit.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        dense: true,
      ),
    );
  }
}


