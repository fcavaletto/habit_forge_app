import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'theme.dart';
import 'screens/dashboard_view.dart';
import 'providers/app_state_provider.dart';
import 'providers/habit_provider.dart';
import 'widgets/error_boundary.dart';
import 'services/service_factory.dart';

/// Application entry point with persistent cache preloading
///
/// This implementation ensures zero loading screens by preloading all cached
/// data BEFORE showing the UI. The app stays on the splash screen until data
/// is ready, then shows the dashboard fully populated.
///
/// ## Key Benefits:
/// - No loading spinner ever shown to user
/// - No empty dashboard flash
/// - Dashboard appears fully populated immediately
/// - Background refresh for fresh data without UI disruption
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Flutter app with cache preloading...');

  GlobalErrorHandler.setup();
  
  // Initialize ServiceFactory before creating any providers
  debugPrint('🏭 Initializing ServiceFactory...');
  await ServiceFactory.initialize();
  debugPrint('✅ ServiceFactory initialized successfully');

  // CRITICAL: Preload cache data BEFORE showing UI
  // This keeps app on splash screen until data is ready
  debugPrint('📦 Preloading cache data before UI initialization...');
  final appState = await AppStateProvider.preload();
  debugPrint('✅ Cache preloaded with ${appState.habits.length} habits');
  
  // Start the app - data is ALREADY loaded, no loading screen needed
  runApp(
    ErrorBoundary(
      onError: (error) {
        debugPrint('Global error caught: ${error.exception}');
      },
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProxyProvider<AppState, HabitProvider>(
            create: (context) => appState.habitProvider,
            update: (context, appState, previous) => appState.habitProvider,
          ),
        ],
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            return MaterialApp(
              title: 'Habit Forge',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: appState.themeMode,
                home: const DashboardView(),
            );
          },
        ),
      ),
    ),
  );

  // Refresh data from database in background (silent, no loading state)
  // Only refresh if data was loaded from cache (skip if we just loaded from DB)
  if (appState.habitProvider.loadedFromCache) {
    debugPrint('🔄 Data was from cache, starting background refresh');
    _refreshDataInBackground(appState);
  } else {
    debugPrint('⏭️ Data was from database, skipping redundant refresh');
  }

  debugPrint('✅ Flutter app started with preloaded data');
}

/// Refreshes data from database in background without showing loading UI
///
/// This method silently updates data from the database after the UI has been
/// shown with cached data. Updates are applied smoothly without loading screens.
/// Secondary services are also initialized here without blocking the UI.
Future<void> _refreshDataInBackground(AppState appState) async {
  try {
    debugPrint('🔄 Starting silent background data refresh...');

    // Small delay to let UI render first
    await Future.delayed(const Duration(milliseconds: 100));

    // Refresh data from database silently (without setting loading states)
    await appState.habitProvider.refreshDataSilently();

    // Initialize secondary services in parallel
    debugPrint('🔧 Initializing secondary services in background...');
    await Future.wait([
      appState.notificationProvider.initialize(),
      appState.proSubscriptionProvider.loadProSubscriptionSetting(),
      appState.streakSettingsProvider.loadStreakSetting(),
      appState.loadTimeOverrideSetting(),
    ]).timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('⚠️ Secondary services initialization timed out');
        return List<void>.filled(6, null); // Return empty list on timeout
      },
    );

    debugPrint('✅ Background refresh completed successfully');
  } catch (error) {
    debugPrint('❌ Background refresh failed: $error');
    debugPrint('⚠️ App continues with cached data, will retry on next interaction');
  }
}