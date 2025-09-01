

import 'package:flutter/material.dart';

/// Represents a single habit with tracking data
class Habit {
  final String id;
  final String name;
  final String description;
  final int colorIndex; // Index for habit color from theme
  final DateTime createdAt;
  final Map<DateTime, bool> completions; // Date -> completed (true/false)
  final String iconName; // Icon name from Material Icons
  final TimeOfDay? reminderTime; // Optional reminder time
  final bool enableReminders; // Whether to enable reminders for this habit

  Habit({
    required this.id,
    required this.name,
    required this.description,
    required this.colorIndex,
    required this.createdAt,
    required this.completions,
    this.iconName = 'check_circle',
    this.reminderTime,
    this.enableReminders = false,
  });

  /// Create a new habit
  factory Habit.create({
    required String name,
    required String description,
    int colorIndex = 0,
    String iconName = 'check_circle',
    TimeOfDay? reminderTime,
    bool enableReminders = false,
  }) {
    return Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      colorIndex: colorIndex,
      createdAt: DateTime.now(),
      completions: {},
      iconName: iconName,
      reminderTime: reminderTime,
      enableReminders: enableReminders,
    );
  }

  /// Mark habit as completed for a specific date
  Habit markCompleted(DateTime date, bool completed) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final newCompletions = Map<DateTime, bool>.from(completions);
    newCompletions[normalizedDate] = completed;
    return copyWith(completions: newCompletions);
  }

  /// Check if habit is completed for a specific date
  bool isCompleted(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return completions[normalizedDate] ?? false;
  }

  /// Get current streak (consecutive days completed)
  int get currentStreak {
    final today = DateTime.now();
    int streak = 0;
    DateTime checkDate = today;

    while (isCompleted(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Get total completions count
  int get totalCompletions {
    return completions.values.where((completed) => completed).length;
  }

  /// Get completion rate for the last 30 days
  double get completionRate {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentCompletions = completions.entries
        .where((entry) => entry.key.isAfter(thirtyDaysAgo) || entry.key.isAtSameMomentAs(thirtyDaysAgo))
        .where((entry) => entry.value)
        .length;
    return recentCompletions / 30;
  }

  /// Get completion data for the last 7 days (for grid chart)
  List<bool> get last7Days {
    final today = DateTime.now();
    return List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return isCompleted(date);
    });
  }

  /// Get completion data for the last 4 weeks (28 days, 7x4 grid)
  List<List<bool>> get last4Weeks {
    final today = DateTime.now();
    return List.generate(4, (weekIndex) {
      return List.generate(7, (dayIndex) {
        final date = today.subtract(Duration(
          days: (3 - weekIndex) * 7 + (6 - dayIndex),
        ));
        return isCompleted(date);
      });
    });
  }

  /// Copy with updated fields
  Habit copyWith({
    String? id,
    String? name,
    String? description,
    int? colorIndex,
    DateTime? createdAt,
    Map<DateTime, bool>? completions,
    String? iconName,
    TimeOfDay? reminderTime,
    bool? enableReminders,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      completions: completions ?? this.completions,
      iconName: iconName ?? this.iconName,
      reminderTime: reminderTime ?? this.reminderTime,
      enableReminders: enableReminders ?? this.enableReminders,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'colorIndex': colorIndex,
      'createdAt': createdAt.toIso8601String(),
      'iconName': iconName,
      'reminderTime': reminderTime != null
          ? {'hour': reminderTime!.hour, 'minute': reminderTime!.minute}
          : null,
      'enableReminders': enableReminders,
      'completions': completions.map(
        (key, value) => MapEntry(key.toIso8601String(), value),
      ),
    };
  }

  /// Create from JSON
  factory Habit.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminderTime;
    if (json['reminderTime'] != null) {
      final timeMap = json['reminderTime'] as Map<String, dynamic>;
      reminderTime = TimeOfDay(
        hour: timeMap['hour'] as int,
        minute: timeMap['minute'] as int,
      );
    }

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      iconName: json['iconName'] as String? ?? 'check_circle',
      reminderTime: reminderTime,
      enableReminders: json['enableReminders'] as bool? ?? false,
      completions: (json['completions'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(DateTime.parse(key), value as bool),
      ),
    );
  }

  @override
  String toString() {
    return 'Habit(id: $id, name: $name, streak: $currentStreak)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Habit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
