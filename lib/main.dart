import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'providers/app_state_provider.dart';
import 'widgets/error_boundary.dart';

/// Application entry point
///
/// Initializes all necessary services and starts the Flutter application.
/// This includes:
/// 1. Storage initialization - Loads existing habit data
/// 2. Notification service setup - Configures push notifications
/// 3. State management setup - Initializes Provider architecture
/// 4. Error handling - Graceful degradation if services fail
/// 5. App launch - Starts the main Flutter application
///
/// The initialization is designed to be robust and will continue
/// even if individual services fail to initialize.
Future<void> main() async {
  // Ensure Flutter framework is ready before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app...');

  // Set up global error handling
  GlobalErrorHandler.setup();

  // Initialize the app state provider
  final appStateProvider = AppStateProvider.create();

  // Start the Flutter app with provider setup and error boundary
  runApp(
    ErrorBoundary(
      onError: (error) {
        debugPrint('Global error caught: ${error.exception}');
      },
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appStateProvider),
        ],
        child: const HabitForgeApp(),
      ),
    ),
  );

  debugPrint('✅ Flutter app started with state management and error handling');
}

/// Root application widget with theme management
///
/// This widget manages the application's theme state and provides
/// the MaterialApp configuration. It handles:
/// - Theme mode persistence (light/dark/system)
/// - Theme switching functionality
/// - Material 3 design system integration
/// - Navigation to the main dashboard (DashboardScreen)
class HabitForgeApp extends StatefulWidget {
  const HabitForgeApp({super.key});

  @override
  State<HabitForgeApp> createState() => _HabitForgeAppState();
}

class _HabitForgeAppState extends State<HabitForgeApp> {
  /// Current theme mode - defaults to system preference
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  /// Loads the user's preferred theme mode
  ///
  /// For now, defaults to system theme. In the future, this could be
  /// stored in SQLite database or other persistent storage.
  void _loadThemeMode() {
    // Default to system theme for now
    setState(() {
      _themeMode = ThemeMode.system;
    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Forge', // App title shown in task switcher
      theme: AppTheme.lightTheme, // Light theme configuration
      darkTheme: AppTheme.darkTheme, // Dark theme configuration
      themeMode: _themeMode, // Current theme mode (system/light/dark)
      home: const DashboardScreen(),
    );
  }
}
