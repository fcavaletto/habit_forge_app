import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/safe_scrollable_wrapper.dart';
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
/// 4. **Archive Management**: Access archived habits for restoration
/// 5. **Sample Data**: Generate test habits for evaluation
///
/// ## Error Handling:
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

          // PRO Features Section
          Text(
            'PRO Features',
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
                            'PRO Subscription',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Access to advanced analytics, detailed statistics, and premium features',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: appState.isProSubscriptionActive,
                      onChanged: (value) async {
                        await appState.proSubscriptionProvider.toggleProSubscription();
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Streak Calculation Section
          Text(
            'Streak Calculation',
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose how streaks are calculated',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // All Days Option
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All Days',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Count consecutive days regardless of active days',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: !appState.isActiveDaysStreakEnabled,
                          onChanged: (value) async {
                            await appState.streakSettingsProvider.toggleActiveDaysStreak();
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Active Days Only Option
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Days Only',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Count consecutive active days only',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: appState.isActiveDaysStreakEnabled,
                          onChanged: (value) async {
                            await appState.streakSettingsProvider.toggleActiveDaysStreak();
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
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
                            'Display "X out of Y habits shown. Z habits fully completed." text on dashboard\n(X=shown habits, Y=total active habits, Z=completed habits)',
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