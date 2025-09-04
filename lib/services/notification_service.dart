import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/habit.dart';

/// Service for managing local notifications for habit reminders
///
/// This singleton service handles all notification-related operations including:
/// - Daily reminder scheduling for habits
/// - Notification permission management
/// - Timezone-aware scheduling
/// - Notification channel configuration
/// - Cross-platform support (Android/iOS)
///
/// Key responsibilities:
/// 1. Initialize notification framework and permissions
/// 2. Schedule daily reminders for active habits
/// 3. Cancel reminders when habits are completed or disabled
/// 4. Handle notification taps and interactions
/// 5. Provide status checks for notification permissions
///
/// The service uses the timezone package for accurate scheduling
/// and implements robust error handling to prevent app crashes.
class NotificationService {
  /// Singleton instance - ensures only one notification service exists
  static final NotificationService _instance = NotificationService._internal();

  /// Factory constructor for singleton pattern
  factory NotificationService() => _instance;

  /// Private constructor for singleton pattern
  NotificationService._internal();

  /// Flutter Local Notifications plugin instance
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialization status flag
  bool _isInitialized = false;

  /// Maximum timeout for notification operations (in seconds)
  static const int _maxTimeoutSeconds = 10;

  /// Notification ID range for different types
  static const int _habitNotificationIdMin = 100000;
  static const int _habitNotificationIdMax = 999999;
  static const int _testNotificationId = 999999;
  static const int _scheduledTestNotificationId = 999998;

  /// Initialize the notification service without requesting permissions
  ///
  /// Sets up the notification framework with proper timezone handling.
  /// This method should be called once during app startup.
  /// Permissions will be requested only when the user tries to enable reminders.
  ///
  /// Initialization steps:
  /// 1. Initialize timezone database for accurate scheduling
  /// 2. Configure Android notification settings
  /// 3. Configure iOS notification settings
  /// 4. Initialize the Flutter Local Notifications plugin
  /// 5. Create notification channels (Android)
  ///
  /// @throws Exception if initialization fails
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Notification service already initialized');
      return;
    }

    try {
      debugPrint('Initializing timezone data...');
      // Initialize timezone data for accurate scheduling across time zones
      tz.initializeTimeZones();
      // Use a more reliable method to get the local timezone
      final localTimezone = tz.local.name;
      tz.setLocalLocation(tz.getLocation(localTimezone));
      debugPrint('Timezone data initialized for: $localTimezone');

      debugPrint('Setting up notification settings...');
      
      // Create notification channels for Android
      await _createNotificationChannels();
      
      // Configure Android notification settings
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configure iOS notification settings (without automatic permission requests)
      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,   // Don't request permissions automatically
        requestBadgePermission: false,   // Don't request permissions automatically
        requestSoundPermission: false,    // Don't request permissions automatically
      );

      // Combine platform-specific settings
      const InitializationSettings initializationSettings = InitializationSettings(
        android: androidInitializationSettings,
        iOS: iosInitializationSettings,
      );

      debugPrint('Initializing flutter local notifications...');
      // Initialize the plugin with our settings
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      debugPrint('Flutter local notifications initialized');

      _isInitialized = true;
      debugPrint('✅ Notification service initialized (permissions not requested)');
    } catch (e) {
      debugPrint('❌ Failed to initialize notification service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Request notification permissions from the user
  ///
  /// Prompts the user to grant notification permissions for the app.
  /// Handles platform-specific permission requests for iOS and Android.
  ///
  /// For iOS: Requests permissions for alerts, badges, and sounds
  /// For Android: Requests general notification permission
  /// For other platforms: Returns false (notifications not supported)
  ///
  /// @return true if permissions were granted, false otherwise
  Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Request comprehensive permissions for iOS
        final bool? result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,    // Allow notification alerts
              badge: true,    // Allow app icon badges
              sound: true,    // Allow notification sounds
            );
        return result ?? false; // Return false if permission request fails
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Request notification permission for Android
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final bool? granted = await androidImplementation?.requestNotificationsPermission();
        return granted ?? false; // Return false if permission request fails
      }
      // Unsupported platform
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled and request permissions if needed
  ///
  /// This method checks if notifications are enabled and requests permissions
  /// if they're not granted. It's designed to be called when the user tries
  /// to enable reminders for a habit.
  ///
  /// @return true if notifications are enabled, false if permissions were denied
  Future<bool> checkAndRequestPermissionsForReminders() async {
    debugPrint('🔔 Checking notification permissions for reminders...');
    
    // Initialize notification service on demand if not already initialized
    if (!_isInitialized) {
      debugPrint('🔔 Initializing notification service on demand...');
      try {
        await initialize();
      } catch (e) {
        debugPrint('❌ Failed to initialize notification service: $e');
        return false;
      }
    }
    
    // First check if notifications are already enabled
    final isEnabled = await areNotificationsEnabled();
    if (isEnabled) {
      debugPrint('✅ Notifications already enabled');
      return true;
    }

    // Notifications not enabled, request permissions
    debugPrint('🔔 Notifications not enabled, requesting permissions...');
    final granted = await requestPermissions();
    
    if (granted) {
      debugPrint('✅ Notification permissions granted');
      return true;
    } else {
      debugPrint('❌ Notification permissions denied');
      return false;
    }
  }

  /// Schedule daily reminder for a habit
  ///
  /// Schedules a daily reminder notification for the habit at the specified time.
  /// Uses AndroidScheduleMode.exactAllowWhileIdle for better reliability.
  /// Includes comprehensive error handling and timeout protection.
  Future<void> scheduleHabitReminder(Habit habit) async {
    if (!_isInitialized) {
      debugPrint('❌ Notification service not initialized');
      return;
    }

    try {
      if (!habit.enableReminders || habit.reminderTime == null) {
        // Cancel existing notification if reminders are disabled
        await cancelHabitReminder(habit.id);
        return;
      }

      final int notificationId = _getNotificationId(habit.id);

      // Check if habit is already completed today
      final today = DateTime.now();
      final isCompletedToday = habit.isCompleted(today);

      if (isCompletedToday) {
        // Don't schedule if already completed today
        await cancelHabitReminder(habit.id);
        return;
      }

      // Schedule the notification with timeout protection
      final scheduledTime = _getScheduledTime(habit.reminderTime!);

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders for habit completion',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      autoCancel: false,
      ongoing: false,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.reminder,
      channelShowBadge: true,
      ticker: 'Habit reminder: ${habit.name}',
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 1000,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'mark_complete',
          'Mark Complete',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_close'),
          showsUserInterface: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Habit Reminder',
        'Don\'t forget to complete your "${habit.name}" habit!',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'habit_reminder_${habit.id}',
      ).timeout(
        Duration(seconds: _maxTimeoutSeconds),
        onTimeout: () {
          debugPrint('⏰ Timeout scheduling reminder for ${habit.name}');
          throw TimeoutException('Notification scheduling timed out');
        },
      );

      debugPrint('✅ Scheduled reminder for ${habit.name} at ${habit.reminderTime!.hour}:${habit.reminderTime!.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('❌ Failed to schedule reminder for ${habit.name}: $e');
      // Don't rethrow - allow the app to continue without this reminder
    }
  }

  /// Cancel reminder for a specific habit
  Future<void> cancelHabitReminder(String habitId) async {
    try {
      final int notificationId = _getNotificationId(habitId);
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
      debugPrint('✅ Cancelled reminder for habit: $habitId');
    } catch (e) {
      debugPrint('❌ Failed to cancel reminder for habit $habitId: $e');
    }
  }

  /// Cancel all habit reminders
  Future<void> cancelAllReminders() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('✅ Cancelled all habit reminders');
    } catch (e) {
      debugPrint('❌ Failed to cancel all reminders: $e');
    }
  }

  /// Schedule reminders for all habits
  ///
  /// Iterates through all habits and schedules reminders for those
  /// that have reminders enabled. Includes error handling to ensure
  /// one failed habit doesn't prevent others from being scheduled.
  Future<void> scheduleAllReminders(List<Habit> habits) async {
    if (!_isInitialized) {
      debugPrint('❌ Notification service not initialized');
      return;
    }

    debugPrint('🔔 Scheduling reminders for ${habits.length} habits');

    for (final habit in habits) {
      try {
        await scheduleHabitReminder(habit);
      } catch (e) {
        debugPrint('❌ Failed to schedule reminder for habit ${habit.name}: $e');
        // Continue with other habits even if one fails
      }
    }

    debugPrint('✅ Finished scheduling reminders');
  }

  /// Get the scheduled time for a reminder
  ///
  /// Calculates the next occurrence of the reminder time, handling:
  /// - Same-day scheduling if time hasn't passed
  /// - Next-day scheduling if time has passed
  /// - Proper timezone handling to avoid DST issues
  tz.TZDateTime _getScheduledTime(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);

    // Create scheduled time for today
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      return scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Get unique notification ID for a habit
  ///
  /// Uses a more reliable method to generate unique IDs to avoid collisions.
  /// Combines habit ID hash with a fixed offset to ensure uniqueness.
  int _getNotificationId(String habitId) {
    // Use a combination of hash and fixed offset to reduce collision risk
    return (habitId.hashCode.abs() % (_habitNotificationIdMax - _habitNotificationIdMin)) + _habitNotificationIdMin;
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse notificationResponse) {
    debugPrint('📱 Notification tapped: ${notificationResponse.payload}');
    
    // Handle action buttons
    if (notificationResponse.actionId == 'mark_complete') {
      debugPrint('✅ Mark complete action tapped');
      // TODO: Implement mark complete functionality
    } else if (notificationResponse.actionId == 'dismiss') {
      debugPrint('❌ Dismiss action tapped');
      // TODO: Implement dismiss functionality
    }
  }

  /// Show immediate notification (for testing)
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      debugPrint('❌ Notification service not initialized');
      return;
    }

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Channel for test notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        _testNotificationId,
        'Test Notification',
        'This is a test notification from Habit Forge - if you see this, notifications are working!',
        notificationDetails,
      );
      
      debugPrint('✅ Test notification sent with ID: $_testNotificationId');
    } catch (e) {
      debugPrint('❌ Failed to show test notification: $e');
      rethrow;
    }
  }

  /// Schedule a test notification with fallback for exact alarm permissions
  Future<void> scheduleTestNotification(DateTime scheduledTime) async {
    if (!_isInitialized) {
      debugPrint('❌ Notification service not initialized');
      return;
    }

    debugPrint('🕐 Scheduling test notification for: $scheduledTime');

    // Convert DateTime to TZDateTime
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    debugPrint('🕐 TZ scheduled time: $tzScheduledTime');

    // Use a more robust notification configuration
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      autoCancel: true,
      ongoing: false,
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.reminder,
      channelShowBadge: true,
              ticker: 'Test notification from Habit Forge',
      enableLights: true,
      ledColor: Color(0xFF00FF00),
      ledOnMs: 1000,
      ledOffMs: 1000,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'test_dismiss',
          'Dismiss',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_close'),
          showsUserInterface: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _scheduledTestNotificationId,
        'Scheduled Test Notification',
        'This is a scheduled test notification from Habit Forge - if you see this, scheduled notifications are working!',
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'test_scheduled_notification',
      );
      
      debugPrint('✅ Scheduled test notification with ID: $_scheduledTestNotificationId for $tzScheduledTime');
      
      // Also schedule a backup notification using a different approach
      await _scheduleBackupNotification(scheduledTime);
    } catch (e) {
      debugPrint('❌ Failed to schedule test notification: $e');
      
      // If exact alarms are not permitted, try with a different schedule mode
      if (e.toString().contains('exact_alarms_not_permitted')) {
        debugPrint('🔄 Exact alarms not permitted, trying with inexact scheduling...');
        try {
          await _flutterLocalNotificationsPlugin.zonedSchedule(
            _scheduledTestNotificationId,
            'Scheduled Test Notification (Inexact)',
            'This is a scheduled test notification from Habit Forge - if you see this, scheduled notifications are working!',
            tzScheduledTime,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'test_scheduled_notification_inexact',
          );
          
          debugPrint('✅ Scheduled test notification with inexact mode for $tzScheduledTime');
          
          // Also schedule a backup notification using inexact mode
          await _scheduleBackupNotificationInexact(scheduledTime);
        } catch (e2) {
          debugPrint('❌ Failed to schedule inexact notification: $e2');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Schedule a backup notification using exact mode
  Future<void> _scheduleBackupNotification(DateTime scheduledTime) async {
    try {
      const AndroidNotificationDetails backupNotificationDetails =
          AndroidNotificationDetails(
        'backup_channel',
        'Backup Notifications',
        channelDescription: 'Backup channel for critical notifications',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        ongoing: false,
        visibility: NotificationVisibility.public,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.reminder,
        channelShowBadge: true,
        ticker: 'Backup test notification from Habit Forge',
        enableLights: true,
        ledColor: Color(0xFFFF0000),
        ledOnMs: 2000,
        ledOffMs: 1000,
      );

      const DarwinNotificationDetails backupIosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails backupDetails = NotificationDetails(
        android: backupNotificationDetails,
        iOS: backupIosNotificationDetails,
      );

      // Schedule backup notification 30 seconds after the main one
      final backupTime = scheduledTime.add(const Duration(seconds: 30));
      final tzBackupTime = tz.TZDateTime.from(backupTime, tz.local);
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _testNotificationId, // Different ID for backup
        'Backup Test Notification',
        'Backup notification - if you see this, the main notification failed',
        tzBackupTime,
        backupDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'backup_scheduled_notification',
      );

      debugPrint('🔄 Scheduled backup notification for $tzBackupTime');
    } catch (e) {
      debugPrint('❌ Failed to schedule backup notification: $e');
    }
  }

  /// Schedule a backup notification using inexact mode
  Future<void> _scheduleBackupNotificationInexact(DateTime scheduledTime) async {
    try {
      const AndroidNotificationDetails backupNotificationDetails =
          AndroidNotificationDetails(
        'backup_channel',
        'Backup Notifications',
        channelDescription: 'Backup channel for critical notifications',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
        ongoing: false,
        visibility: NotificationVisibility.public,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.reminder,
        channelShowBadge: true,
        ticker: 'Backup test notification from Habit Forge (Inexact)',
        enableLights: true,
        ledColor: Color(0xFFFF0000),
        ledOnMs: 2000,
        ledOffMs: 1000,
      );

      const DarwinNotificationDetails backupIosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails backupDetails = NotificationDetails(
        android: backupNotificationDetails,
        iOS: backupIosNotificationDetails,
      );

      // Schedule backup notification 30 seconds after the main one
      final backupTime = scheduledTime.add(const Duration(seconds: 30));
      final tzBackupTime = tz.TZDateTime.from(backupTime, tz.local);
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _testNotificationId, // Different ID for backup
        'Backup Test Notification (Inexact)',
        'Backup notification - if you see this, the main notification failed',
        tzBackupTime,
        backupDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'backup_scheduled_notification_inexact',
      );

      debugPrint('🔄 Scheduled backup notification (inexact) for $tzBackupTime');
    } catch (e) {
      debugPrint('❌ Failed to schedule backup notification (inexact): $e');
    }
  }

  /// Check if notifications are enabled
  ///
  /// Returns true if notifications are enabled and permissions are granted.
  /// This method properly handles platform differences and null safety.
  Future<bool> areNotificationsEnabled() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iOSImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (iOSImplementation == null) return false;

        final settings = await iOSImplementation.checkPermissions();
        // For iOS, check if notifications are enabled
        return settings?.isEnabled ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation == null) return false;

        final bool? granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  /// Check and request permissions if needed
  ///
  /// This method checks if notifications are enabled and requests permissions
  /// if they're not granted. Useful for on-demand permission requests.
  Future<bool> checkAndRequestPermissions() async {
    final isEnabled = await areNotificationsEnabled();
    if (!isEnabled) {
      debugPrint('🔔 Notifications not enabled, requesting permissions...');
      return await requestPermissions();
    }
    return true;
  }

  /// Get all pending notifications (for debugging)
  ///
  /// This method helps debug notification scheduling by showing what
  /// notifications are currently scheduled.
  Future<void> debugPendingNotifications() async {
    if (!_isInitialized) {
      debugPrint('❌ Notification service not initialized');
      return;
    }

    try {
      final pendingNotifications = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint('📋 Pending notifications count: ${pendingNotifications.length}');
      
      for (final notification in pendingNotifications) {
        debugPrint('  - ID: ${notification.id}, Title: ${notification.title}');
      }
      
      // Also show timezone info
      final now = DateTime.now();
      final tzNow = tz.TZDateTime.now(tz.local);
      debugPrint('🌍 Timezone Debug Info:');
      debugPrint('  - System time: $now (${now.timeZoneName})');
      debugPrint('  - TZ time: $tzNow (${tzNow.timeZoneName})');
      debugPrint('  - TZ location: ${tz.local.name}');
      
      // Check notification channels on Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          final channels = await androidImplementation.getNotificationChannels();
          debugPrint('📱 Android Notification Channels:');
          if (channels != null) {
            for (final channel in channels) {
              debugPrint('  - ${channel.id}: ${channel.name} (importance: ${channel.importance})');
            }
          } else {
            debugPrint('  - No channels found or channels is null');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
    }
  }

  /// Create notification channels for Android
  ///
  /// Creates the necessary notification channels for the app to ensure
  /// notifications are properly displayed on Android 8.0+.
  Future<void> _createNotificationChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation == null) {
        debugPrint('❌ Android implementation not available for channel creation');
        return;
      }

      // Create habit reminders channel
      const habitRemindersChannel = AndroidNotificationChannel(
        'habit_reminders',
        'Habit Reminders',
        description: 'Daily reminders for habit completion',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true, // Enable LED light
        ledColor: Color(0xFF2196F3), // Blue LED color
      );

      // Create test notifications channel
      const testChannel = AndroidNotificationChannel(
        'test_channel',
        'Test Notifications',
        description: 'Channel for test notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true, // Enable LED light
        ledColor: Color(0xFF4CAF50), // Green LED color
      );

      // Create backup notifications channel
      const backupChannel = AndroidNotificationChannel(
        'backup_channel',
        'Backup Notifications',
        description: 'Backup channel for critical notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true, // Enable LED light
        ledColor: Color(0xFFFF0000), // Red LED color
      );

      await androidImplementation.createNotificationChannel(habitRemindersChannel);
      await androidImplementation.createNotificationChannel(testChannel);
      await androidImplementation.createNotificationChannel(backupChannel);
      
      debugPrint('✅ Created notification channels: habit_reminders, test_channel, backup_channel');
    } catch (e) {
      debugPrint('❌ Failed to create notification channels: $e');
    }
  }
}

/// Global instance of notification service
final notificationService = NotificationService();