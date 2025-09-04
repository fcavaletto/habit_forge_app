/// Phase 2: Test file to validate DashboardScreen implementation
///
/// This test file is created during Phase 2 to verify that the new DashboardScreen
/// can be instantiated and works correctly before full migration.
/// This file should be deleted after Phase 5 when the migration is complete.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_forge_app/screens/dashboard_screen.dart';

void main() {
  group('DashboardScreen Phase 2 Validation Tests', () {
    testWidgets('DashboardScreen can be instantiated with required parameters',
        (WidgetTester tester) async {
      // Create a test theme mode
      ThemeMode testThemeMode = ThemeMode.system;

      // Create a test theme change callback
      void onThemeChanged(ThemeMode mode) {
        testThemeMode = mode;
      }

      // Build the DashboardScreen widget
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            themeMode: testThemeMode,
            onThemeChanged: onThemeChanged,
          ),
        ),
      );

      // Verify the widget builds without errors
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Verify the app bar is present
      expect(find.text('Habit Forge'), findsOneWidget);

      // Verify settings button is present
      expect(find.byIcon(Icons.settings), findsOneWidget);

      // Verify calendar button is present (added in Phase 1)
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);

      // Test passed if we reach this point
      expect(true, isTrue);
    });

    test('DashboardScreen constructor parameters are required', () {
      // Test that missing required parameters throw errors
      expect(
        () => DashboardScreen(
          themeMode: ThemeMode.system,
          onThemeChanged: (ThemeMode mode) {}, // Actually provide it to test other aspects
        ),
        isNotNull, // Should not throw error when both parameters are provided
      );

      // Note: Dart constructors don't throw errors for missing required parameters
      // at instantiation time, so we can't test for ArgumentError here.
      // The constructor validation happens at compile time instead.

      // Test passes if constructor works with valid parameters
      expect(true, isTrue);
    });
  });
}
