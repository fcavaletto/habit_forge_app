import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../utils/constants.dart';
import 'archive_screen.dart';

/// Settings Screen - Comprehensive app configuration interface
///
/// This screen provides a centralized interface for managing all application
/// settings, preferences, and data operations. It implements a clean, organized
/// layout with grouped settings and clear user feedback for all operations.
///
/// ## Architecture Pattern:
/// - **Settings Pattern**: Centralized configuration management
/// - **Callback Pattern**: Communicates changes to parent components
/// - **Provider Integration**: Accesses app state for settings persistence
/// - **File Operations**: Handles data import/export with proper error handling
///
/// ## Key Features:
/// - **Theme Management**: Light/dark/system theme switching with persistence
/// - **Data Operations**: Import/export functionality with validation
/// - **Sample Data**: Quick generation of test habits for development
/// - **Archive Access**: Direct navigation to archived habits management
/// - **User Feedback**: Comprehensive success/error messaging
///
/// ## Settings Categories:
/// 1. **Appearance**: Theme mode selection and visual preferences
/// 2. **Data Management**: Import, export, and sample data operations
/// 3. **Habit Management**: Archive access and habit operations
/// 4. **Development**: Sample data generation for testing
///
/// ## User Journey:
/// 1. **Navigation**: Access via settings icon in dashboard
/// 2. **Theme Selection**: Choose preferred theme mode
/// 3. **Data Operations**: Import existing data or export current data
/// 4. **Archive Management**: Access archived habits for restoration
/// 5. **Sample Data**: Generate test habits for evaluation
///
/// ## Error Handling:
/// - **File Operations**: Validates file formats and handles I/O errors
/// - **Data Validation**: Ensures imported data integrity
/// - **User Feedback**: Clear error messages with recovery suggestions
/// - **Graceful Degradation**: Continues operation on non-critical failures
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
          const SnackBar(content: Text(AppConstants.exportingMessage)),
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
          const SnackBar(content: Text(AppConstants.importingMessage)),
        );
      }

      // Capture provider before any async operations
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);

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
        if (!mounted) break; // Check if widget is still mounted
        
        try {
          final habit = Habit.fromJson(habitData as Map<String, dynamic>);
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

          // Display Settings Section
          Text(
            'Display Settings',
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
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show Completion Count',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Display "X of Y habits completed" text on dashboard',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: appState.showCompletionCount,
                      onChanged: (value) async {
                        await appState.completionCountProvider.toggleCompletionCount();
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Extended Color Palette',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Show 48 colors instead of 24 in habit creation',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: appState.isExtendedColorPalette,
                      onChanged: (value) async {
                        await appState.extendedColorPaletteProvider.toggleExtendedColorPalette();
                      },
                    ),
                  ],
                );
              },
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