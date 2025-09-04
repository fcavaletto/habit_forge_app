/// Application-wide constants for consistent configuration
///
/// This file centralizes all magic numbers, default values, and configuration
/// constants used throughout the Habit Forge application.
class AppConstants {
  // App Information
  static const String appName = 'Habit Forge';
  static const String appVersion = '1.0.0';

  // UI Dimensions
  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;
  static const double cardElevation = 0.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  // Habit Card
  static const double habitCardHeight = 120.0;
  static const double habitIconSize = 40.0;
  static const double habitCompletionButtonSize = 32.0;

  // Calendar
  static const int calendarTotalMonths = 24; // 12 past + 12 future
  static const int calendarInitialPage = 12; // Start at current month
  static const int calendarGridColumns = 7; // Days in a week
  static const int calendarGridRows = 6; // Maximum weeks in a month
  static const double calendarHeight = 300.0;
  static const double calendarCellSize = 36.0;
  static const double calendarSpacing = 2.0;

  // Charts and Analytics
  static const int chartDaysCount = 30;
  static const int weeklyOverviewDays = 7;
  static const double chartHeight = 200.0;
  static const double chartBarWidth = 3.0;
  static const double chartGridSpacing = 20.0;

  // Import/Export
  static const String exportVersion = '1.0';
  static const String exportFileExtension = 'json';
  static const String exportSubject = 'My Habit Data';
  static const String exportText = 'Habit Forge Data Export';

  // Timeouts and Limits
  static const Duration snackbarDuration = Duration(seconds: 4);
  static const Duration loadingTimeout = Duration(seconds: 30);
  static const int maxImportBatchSize = 50;

  // Animation Durations
  static const Duration quickAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Network connection failed. Please check your connection.';
  static const String fileNotFoundError = 'File not found. Please select a valid file.';
  static const String permissionDeniedError = 'Permission denied. Please grant necessary permissions.';
  static const String invalidFileFormatError = 'Invalid file format. Please select a valid export file.';

  // Success Messages
  static const String exportSuccessMessage = 'Data exported successfully';
  static const String importSuccessMessage = 'Import completed successfully';
  static const String restoreSuccessMessage = 'Habit restored successfully';
  static const String deleteSuccessMessage = 'Habit permanently deleted';

  // Loading Messages
  static const String loadingMessage = 'Loading...';
  static const String exportingMessage = 'Exporting data...';
  static const String importingMessage = 'Importing data...';
  static const String processingMessage = 'Processing...';

  // Navigation Hints
  static const String swipeToNavigateHint = 'Swipe to navigate months';
  static const String tapToViewDetailsHint = 'Tap to view details';
  static const String longPressForOptionsHint = 'Long press for options';

  // Date Formatting
  static const String dateFormatShort = 'MMM dd';
  static const String dateFormatLong = 'MMMM dd, yyyy';
  static const String timeFormat12 = 'hh:mm a';
  static const String timeFormat24 = 'HH:mm';
}

/// Theme-aware color utilities and constants
class ColorConstants {
  // These would be defined in the theme, but we keep references here
  static const String primaryColorKey = 'primary';
  static const String secondaryColorKey = 'secondary';
  static const String errorColorKey = 'error';
  static const String surfaceColorKey = 'surface';
  static const String onSurfaceColorKey = 'onSurface';

  // Opacity values
  static const double lowOpacity = 0.3;
  static const double mediumOpacity = 0.5;
  static const double highOpacity = 0.7;
  static const double fullOpacity = 1.0;
}

/// Route names for consistent navigation
class RouteConstants {
  static const String home = '/';
  static const String addHabit = '/add-habit';
  static const String editHabit = '/edit-habit';
  static const String archive = '/archive';
  static const String settings = '/settings';
  static const String calendar = '/calendar';
  static const String stats = '/stats';
}

/// SharedPreferences keys for consistent data storage
class StorageKeys {
  static const String habits = 'habits';
  static const String themeMode = 'theme_mode';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String firstLaunch = 'first_launch';
  static const String appVersion = 'app_version';
}

/// API and external service constants
class ApiConstants {
  // Notification channels
  static const String habitReminderChannelId = 'habit_reminders';
  static const String habitReminderChannelName = 'Habit Reminders';
  static const String habitReminderChannelDescription = 'Daily habit completion reminders';

  // File types
  static const String jsonMimeType = 'application/json';
  static const String textMimeType = 'text/plain';
}

/// Validation rules and constraints
class ValidationConstants {
  static const int minHabitNameLength = 1;
  static const int maxHabitNameLength = 50;
  static const int minHabitDescriptionLength = 0;
  static const int maxHabitDescriptionLength = 200;
  static const int maxStreaksToShow = 1000;
  static const int maxExportFileSizeMB = 10;
}

/// Animation and transition constants
class AnimationConstants {
  // Note: Curves cannot be const as they are not compile-time constants
  static const String defaultCurveName = 'easeInOut';
  static const String bounceCurveName = 'elasticOut';
  static const String sharpCurveName = 'fastOutSlowIn';

  // Animation durations
  static const int quickAnimationMs = 200;
  static const int normalAnimationMs = 300;
  static const int slowAnimationMs = 500;
}
