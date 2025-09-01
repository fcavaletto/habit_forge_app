import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/habit.dart';

/// Service for managing local notifications for habit reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Notification service already initialized');
      return;
    }

    debugPrint('Initializing timezone data...');
    // Initialize timezone data
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    debugPrint('Timezone data initialized');

    debugPrint('Setting up notification settings...');
    // Initialize notification settings
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    debugPrint('Initializing flutter local notifications...');
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    debugPrint('Flutter local notifications initialized');

    _isInitialized = true;

    debugPrint('Requesting notification permissions...');
    // Request permissions
    await requestPermissions();
    debugPrint('Notification service fully initialized');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// Schedule daily reminder for a habit
  Future<void> scheduleHabitReminder(Habit habit) async {
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

    // Schedule the notification
    final scheduledTime = _getScheduledTime(habit.reminderTime!);

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders for habit completion',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
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

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Habit Reminder',
      'Don\'t forget to complete your "${habit.name}" habit!',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('Scheduled reminder for ${habit.name} at ${habit.reminderTime!.hour}:${habit.reminderTime!.minute.toString().padLeft(2, '0')}');
  }

  /// Cancel reminder for a specific habit
  Future<void> cancelHabitReminder(String habitId) async {
    final int notificationId = _getNotificationId(habitId);
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
    debugPrint('Cancelled reminder for habit: $habitId');
  }

  /// Cancel all habit reminders
  Future<void> cancelAllReminders() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('Cancelled all habit reminders');
  }

  /// Schedule reminders for all habits
  Future<void> scheduleAllReminders(List<Habit> habits) async {
    for (final habit in habits) {
      await scheduleHabitReminder(habit);
    }
  }

  /// Get the scheduled time for a reminder
  tz.TZDateTime _getScheduledTime(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      return scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Get unique notification ID for a habit
  int _getNotificationId(String habitId) {
    return habitId.hashCode.abs();
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse notificationResponse) {
    debugPrint('Notification tapped: ${notificationResponse.payload}');
    // Handle notification tap - could navigate to habit screen
  }

  /// Show immediate notification (for testing)
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.max,
      priority: Priority.high,
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
      0,
      'Test Notification',
      'This is a test notification',
      notificationDetails,
    );
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return settings?.isEnabled ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.areNotificationsEnabled();
      return granted ?? false;
    }
    return false;
  }
}

/// Global instance of notification service
final notificationService = NotificationService();