import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/constants.dart';
import 'archive_screen.dart';

/// Settings Screen - Full-page settings interface
///
/// Provides access to app settings and preferences including:
/// - Theme mode selection (light/dark/system)
/// - Sample data generation for testing
/// - Archive management
/// - Data import/export functionality
///
/// Uses a full-screen layout with proper navigation instead of
/// a modal bottom sheet, providing more space and better UX.
class SettingsScreen extends StatefulWidget {
  /// Current theme mode for UI state display
  final ThemeMode currentThemeMode;

  /// Callback for theme mode changes
  final ValueChanged<ThemeMode> onThemeChanged;

  /// Callback for adding sample habits
  final VoidCallback onAddSampleHabits;


  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    required this.onAddSampleHabits,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _exportData() async {
    try {
      // Show initial progress message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppConstants.exportingMessage)),
        );
      }

      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      final habits = await habitProvider.repository.getAllHabits();
      final exportData = {
        'version': AppConstants.exportVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'habits': habits.map((habit) => habit.toJson()).toList(),
      };

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'habit_forge_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(jsonEncode(exportData));

      // Try to share with improved error handling
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: AppConstants.exportText,
          subject: AppConstants.exportSubject,
        );

        // Since shareXFiles doesn't provide completion feedback,
        // we'll show an informative message instead of claiming success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Export file prepared. Please select "Save to Files" or your preferred app to complete the export.'
              ),
              duration: AppConstants.snackbarDuration,
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {
                  // User acknowledged the message
                },
              ),
            ),
          );
        }
      } catch (shareError) {
        // If sharing fails, inform user about alternative
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Share failed: ${shareError.toString()}. File saved to app storage.'
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: AppConstants.snackbarDuration,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Imports habits from a JSON file with conflict resolution
  ///
  /// This method:
  /// 1. Opens a file picker for JSON files
  /// 2. Validates the file format
  /// 3. Imports habits while skipping duplicates
  /// 4. Provides detailed feedback about import results
  Future<void> _importData() async {
    try {
      // Show initial progress message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppConstants.importingMessage)),
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [AppConstants.exportFileExtension],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        // User cancelled the file picker
        return;
      }

      final file = File(result.files.single.path!);

      if (!await file.exists()) {
        throw AppConstants.fileNotFoundError;
      }

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      // Validate file format
      if (data['habits'] == null || data['habits'] is! List) {
        throw AppConstants.invalidFileFormatError;
      }

      final habitsData = data['habits'] as List<dynamic>;
      int importedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      // Process each habit with error handling
      for (final habitData in habitsData) {
        try {
          final habit = Habit.fromJson(habitData as Map<String, dynamic>);
          final habitProvider = Provider.of<HabitProvider>(context, listen: false);
          final saveResult = await habitProvider.repository.saveHabit(habit);

          if (saveResult.success) {
            importedCount++;
          } else if (saveResult.errorMessage?.contains('already exists') == true ||
                     saveResult.conflictingHabit != null) {
            skippedCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          // Skip invalid habits but count them
          errorCount++;
          continue;
        }
      }

      // Show detailed results
      if (mounted) {
        final message = StringBuffer();
        message.write('$importedCount imported');

        if (skippedCount > 0) {
          message.write(', $skippedCount skipped (already exist)');
        }

        if (errorCount > 0) {
          message.write(', $errorCount errors');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import complete: $message'),
            duration: AppConstants.snackbarDuration,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToArchive() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ArchiveScreen(),
        settings: const RouteSettings(name: '/archive'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
          // Theme Section
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
          Row(
            children: [
              Expanded(
                      child: Text(
                        'Theme Mode',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    DropdownButton<ThemeMode>(
                      value: widget.currentThemeMode,
                      onChanged: (ThemeMode? newMode) {
                        if (newMode != null) {
                          widget.onThemeChanged(newMode);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(
                            'System',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(
                  'Light',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(
                  'Dark',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Sample Data Section
          Text(
            'Sample Data',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.onAddSampleHabits,
            icon: const Icon(Icons.add),
            label: const Text('Add Sample Habits'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),


          const SizedBox(height: 32),

          // Archive Section
          Text(
            'Archive',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _navigateToArchive,
            icon: const Icon(Icons.archive),
            label: const Text('View Archived Habits'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 32),

          // Data Management Section
          Text(
            'Data Management',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Data'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _importData,
                  icon: const Icon(Icons.upload),
                  label: const Text('Import Data'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // About Section
          Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habit Forge',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A comprehensive habit tracking application with GitHub-style progress visualization, daily reminders, and Material 3 design.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}