import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'providers/app_state_provider.dart';
import 'widgets/error_boundary.dart';

/// Application entry point
///
/// Starts the Flutter application immediately with a loading screen,
/// then initializes services in the background to prevent ANR issues.
/// This approach ensures the app shows its UI quickly while services
/// initialize asynchronously.
Future<void> main() async {
  // Ensure Flutter framework is ready before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app immediately...');

  // Set up global error handling
  GlobalErrorHandler.setup();

  // Start the Flutter app immediately with loading screen
  runApp(
    ErrorBoundary(
      onError: (error) {
        debugPrint('Global error caught: ${error.exception}');
      },
      child: const HabitForgeApp(),
    ),
  );

  debugPrint('✅ Flutter app started with loading screen');
}

/// Root application widget with theme management and async initialization
///
/// This widget manages the application's theme state and provides
/// the MaterialApp configuration. It handles:
/// - Async initialization of services to prevent ANR
/// - Loading screen during initialization
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
  AppState? _appState;
  bool _isInitializing = true;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize the app state provider asynchronously
  /// This prevents blocking the main thread and causing ANR issues
  Future<void> _initializeApp() async {
    try {
      debugPrint('🔄 Starting async app initialization...');
      
      // Create the app state provider
      final appStateProvider = AppStateProvider.create();
      
      // Initialize all services in the background
      await appStateProvider.initialize();
      
      // Update the UI with the initialized state
      if (mounted) {
        setState(() {
          _appState = appStateProvider;
          _isInitializing = false;
        });
        debugPrint('✅ App initialization completed successfully');
      }
    } catch (error) {
      debugPrint('❌ App initialization failed: $error');
      if (mounted) {
        setState(() {
          _initializationError = error.toString();
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen during initialization
    if (_isInitializing) {
      return MaterialApp(
        title: 'Habit Forge',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const _LoadingScreen(),
      );
    }

    // Show error screen if initialization failed
    if (_initializationError != null) {
      return MaterialApp(
        title: 'Habit Forge',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: _ErrorScreen(
          error: _initializationError!,
          onRetry: () {
            setState(() {
              _isInitializing = true;
              _initializationError = null;
            });
            _initializeApp();
          },
        ),
      );
    }

    // Show main app with initialized state
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: _appState!),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Habit Forge', // App title shown in task switcher
            theme: AppTheme.lightTheme, // Light theme configuration
            darkTheme: AppTheme.darkTheme, // Dark theme configuration
            themeMode: appState.themeMode, // Current theme mode from provider
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}

/// Loading screen shown during app initialization
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading Habit Forge...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up your habit tracking experience',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen shown when initialization fails
class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(height: 24),
              Text(
                'Failed to Start',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Habit Forge encountered an error during startup. Please try again.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  foregroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ),
              const SizedBox(height: 16),
              if (kDebugMode) ...[
                Text(
                  'Debug Info: $error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
