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
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app immediately...');

  GlobalErrorHandler.setup();

  try {
    final appState = await AppStateProvider.preload();
    runApp(
      ErrorBoundary(
        onError: (error) {
          debugPrint('Global error caught: ${error.exception}');
        },
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
          ],
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              return MaterialApp(
                title: 'Habit Forge',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: appState.themeMode,
                home: const DashboardScreen(),
              );
            },
          ),
        ),
      ),
    );
  } catch (error) {
    debugPrint('❌ Preload failed: $error');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Initialization failed: $error'),
          ),
        ),
      ),
    );
  }

  debugPrint('✅ Flutter app started');
}
