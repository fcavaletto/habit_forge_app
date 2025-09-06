import 'package:flutter/material.dart';
import 'dashboard_view.dart';

/// Dashboard Screen - Main habit tracking interface
///
/// This screen now uses the new architecture with:
/// - Provider for state management
/// - Repository pattern for data access
/// - Separated business logic (controller) from UI (view)
/// - Clean separation of concerns
///
/// The screen displays:
/// - List of active habits with completion status
/// - Empty state with sample habit creation
/// - Quick actions for habit management (edit, archive, delete)
/// - Today's progress overview with completion statistics
/// - Navigation to calendar, settings, and habit creation
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardView();
  }
}

