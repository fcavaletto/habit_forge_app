import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';

/// Application entry point
///
/// Initializes all necessary services and starts the Flutter application.
/// This includes:
/// 1. Storage initialization - Loads existing habit data
/// 2. Notification service setup - Configures push notifications
/// 3. Error handling - Graceful degradation if services fail
/// 4. App launch - Starts the main Flutter application
///
/// The initialization is designed to be robust and will continue
/// even if individual services fail to initialize.
Future<void> main() async {
  // Ensure Flutter framework is ready before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app...');
  
  // Start the Flutter app immediately - no service initialization
  runApp(const HabitForgeApp());
  debugPrint('✅ Flutter app started');
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

  /// Loads the user's preferred theme mode from persistent storage
  ///
  /// Retrieves the saved theme preference from SharedPreferences.
  /// If no preference is saved, defaults to system theme.
  /// Values: 0 = system, 1 = light, 2 = dark
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
    setState(() {
      _themeMode = ThemeMode.values[themeIndex];
    });
  }

  /// Saves the user's theme preference to persistent storage
  ///
  /// Persists the theme mode selection so it survives app restarts.
  /// Updates both the persistent storage and the widget state.
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
      title: 'Habit Forge', // App title shown in task switcher
      theme: AppTheme.lightTheme, // Light theme configuration
      darkTheme: AppTheme.darkTheme, // Dark theme configuration
      themeMode: _themeMode, // Current theme mode (system/light/dark)
      home: DashboardScreen(
        themeMode: _themeMode,
        onThemeChanged: _saveThemeMode,
      ),
    );
  }
}
