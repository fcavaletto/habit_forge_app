import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'providers/app_state_provider.dart';
import 'widgets/error_boundary.dart';

/// Application entry point
///
/// Starts the Flutter application immediately and initializes services in the background.
/// This approach prevents black screen issues by ensuring the UI is rendered
/// before any potentially blocking service initialization occurs.
///
/// Key improvements:
/// 1. Immediate app launch - No waiting for services
/// 2. Background service initialization - Non-blocking
/// 3. Graceful error handling - App continues even if services fail
/// 4. Timeout protection - Prevents hanging during initialization
Future<void> main() async {
  // Ensure Flutter framework is ready before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app immediately...');

  // Set up global error handling
  GlobalErrorHandler.setup();

  // Initialize the app state provider
  final appStateProvider = AppStateProvider.create();

  // Start the Flutter app immediately - don't wait for services
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

  debugPrint('✅ Flutter app started - initializing services in background');

  // Initialize services in the background to prevent blocking
  _initializeServicesInBackground(appStateProvider);
}

/// Initialize all services in the background with timeout protection
///
/// This method runs after the Flutter app has started, ensuring the UI
/// is responsive while services initialize. It includes comprehensive
/// error handling and timeout protection to prevent any service from
/// hanging the app.
Future<void> _initializeServicesInBackground(AppStateProvider appStateProvider) async {
  debugPrint('🔄 Starting background service initialization...');

  try {
    // Initialize services with timeout protection
    await appStateProvider.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⏰ Service initialization timed out - continuing with partial initialization');
        return;
      },
    );
    
    debugPrint('✅ All services initialized successfully in background');
  } catch (e) {
    debugPrint('❌ Service initialization failed: $e');
    debugPrint('⚠️ App will continue with limited functionality');
  }
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

class _HabitForgeAppState extends State<HabitForgeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes to handle background/foreground transitions
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - refreshing data');
        // Refresh data when app comes back to foreground
        _refreshDataOnResume();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached');
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  /// Refresh data when app resumes to ensure fresh state
  Future<void> _refreshDataOnResume() async {
    try {
      final appState = context.read<AppState>();
      await appState.refreshAllData(forceRefresh: true);
    } catch (e) {
      debugPrint('❌ Failed to refresh data on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Habit Forge', // App title shown in task switcher
          theme: AppTheme.lightTheme, // Light theme configuration
          darkTheme: AppTheme.darkTheme, // Dark theme configuration
          themeMode: appState.themeMode, // Current theme mode from provider
          home: const DashboardScreen(),
          // Add debug banner in debug mode only
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
