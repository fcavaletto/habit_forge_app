

import 'package:flutter/material.dart';

/// Core data model representing a user habit
///
/// A habit encapsulates all information needed to track user behavior,
/// including completion history, visual customization, and reminder settings.
///
/// Key responsibilities:
/// - Store habit metadata (name, description, visual properties)
/// - Track completion history with date-based mapping
/// - Calculate statistics (streaks, completion rates)
/// - Handle serialization for data persistence
/// - Support reminder scheduling and notifications
///
/// The model uses immutable patterns and provides factory constructors
/// for flexible object creation and JSON serialization support.

/// Represents a single habit with tracking data
class Habit {
  /// Unique identifier for this habit (timestamp-based)
  final String id;

  /// User-defined name for the habit (e.g., "Drink Water", "Exercise")
  final String name;

  /// Optional detailed description of the habit
  final String description;

  /// Index into the app's color palette for visual customization
  final int colorIndex;

  /// Timestamp when this habit was first created
  final DateTime createdAt;

  /// Map of completion records where key is date and value is completion status
  /// Only completed days are stored to optimize memory usage
  final Map<DateTime, bool> completions;

  /// Material Icons name for visual representation
  final String iconName;

  /// Optional time of day for daily reminders (null if reminders disabled)
  final TimeOfDay? reminderTime;

  /// Whether daily reminders are enabled for this habit
  final bool enableReminders;

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

  /// Factory constructor to create a new habit
  ///
  /// Generates a unique ID based on current timestamp and initializes
  /// all required fields with sensible defaults.
  ///
  /// @param name Required habit name
  /// @param description Optional detailed description
  /// @param colorIndex Visual color theme (defaults to first color)
  /// @param iconName Material Icon identifier (defaults to check_circle)
  /// @param reminderTime Optional daily reminder time
  /// @param enableReminders Whether to enable reminder notifications
  /// @return New Habit instance with generated ID and current timestamp
  factory Habit.create({
    required String name,
    required String description,
    int colorIndex = 0,
    String iconName = 'check_circle',
    TimeOfDay? reminderTime,
    bool enableReminders = false,
  }) {
    return Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Unique timestamp-based ID
      name: name.trim(), // Clean user input
      description: description.trim(), // Clean user input
      colorIndex: colorIndex,
      createdAt: DateTime.now(), // Creation timestamp
      completions: {}, // Start with empty completion history
      iconName: iconName,
      reminderTime: reminderTime,
      enableReminders: enableReminders,
    );
  }

  /// Mark habit as completed or incomplete for a specific date
  ///
  /// Creates a new Habit instance with updated completion status.
  /// Uses immutable pattern - returns new instance rather than modifying existing.
  ///
  /// @param date The date to update completion for
  /// @param completed Whether the habit was completed on this date
  /// @return New Habit instance with updated completion map
  Habit markCompleted(DateTime date, bool completed) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final newCompletions = Map<DateTime, bool>.from(completions);
    newCompletions[normalizedDate] = completed;
    return copyWith(completions: newCompletions);
  }

  /// Check if habit was completed on a specific date
  ///
  /// Normalizes the input date to remove time components and
  /// checks against the completion history map.
  ///
  /// @param date The date to check completion status for
  /// @return true if habit was completed on this date, false otherwise
  bool isCompleted(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return completions[normalizedDate] ?? false;
  }

  /// Calculate current streak of consecutive completed days
  ///
  /// Counts backward from today to find the longest sequence
  /// of consecutive days where this habit was completed.
  ///
  /// @return Number of consecutive days completed (ending today or yesterday)
  int get currentStreak {
    final today = DateTime.now();
    int streak = 0;
    DateTime checkDate = today;

    // Count consecutive completed days backward from today
    while (isCompleted(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Get total number of completed days for this habit
  ///
  /// Counts all entries in the completions map where the value is true.
  /// Represents the total number of days this habit has been successfully completed.
  ///
  /// @return Total count of completed days across all time
  int get totalCompletions {
    return completions.values.where((completed) => completed).length;
  }

  /// Calculate completion rate for the last 30 days
  ///
  /// Measures habit adherence over the most recent 30-day period.
  /// Used for progress tracking and habit strength assessment.
  ///
  /// @return Ratio between 0.0 and 1.0 representing completion percentage
  double get completionRate {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentCompletions = completions.entries
        .where((entry) => entry.key.isAfter(thirtyDaysAgo) || entry.key.isAtSameMomentAs(thirtyDaysAgo))
        .where((entry) => entry.value)
        .length;
    return recentCompletions / 30.0; // Return as fraction for percentage calculation
  }

  /// Generate completion data for the last 7 days
  ///
  /// Used by UI components to display recent progress in compact views.
  /// Returns boolean array where each element represents a day's completion status.
  /// Index 0 = 6 days ago, Index 6 = today
  ///
  /// @return List of 7 boolean values representing daily completion status
  List<bool> get last7Days {
    final today = DateTime.now();
    return List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index)); // 6 days ago to today
      return isCompleted(date);
    });
  }

  /// Generate completion data for the last 4 weeks (28 days)
  ///
  /// Creates a 2D array suitable for grid-based calendar visualization.
  /// Each inner list represents a week (7 days), with 4 weeks total.
  /// Used by detailed calendar views and progress charts.
  ///
  /// @return 4x7 grid of completion status (week × day)
  List<List<bool>> get last4Weeks {
    final today = DateTime.now();
    return List.generate(4, (weekIndex) { // 4 weeks
      return List.generate(7, (dayIndex) { // 7 days per week
        final date = today.subtract(Duration(
          days: (3 - weekIndex) * 7 + (6 - dayIndex), // Calculate date offset
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

  /// Serialize habit to JSON format for data persistence
  ///
  /// Converts all habit properties to a JSON-compatible Map structure.
  /// Handles special serialization for:
  /// - DateTime objects (converted to ISO strings)
  /// - TimeOfDay objects (converted to hour/minute map)
  /// - Completion map (DateTime keys converted to ISO strings)
  ///
  /// @return JSON-compatible Map containing all habit data
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'colorIndex': colorIndex,
      'createdAt': createdAt.toIso8601String(), // ISO 8601 format for dates
      'iconName': iconName,
      // Handle nullable TimeOfDay serialization
      'reminderTime': reminderTime != null
          ? {'hour': reminderTime!.hour, 'minute': reminderTime!.minute}
          : null,
      'enableReminders': enableReminders,
      // Convert DateTime keys to ISO strings for JSON compatibility
      'completions': completions.map(
        (key, value) => MapEntry(key.toIso8601String(), value),
      ),
    };
  }

  /// Deserialize habit from JSON format
  ///
  /// Reconstructs a Habit instance from stored JSON data.
  /// Handles special deserialization for:
  /// - ISO date strings back to DateTime objects
  /// - TimeOfDay reconstruction from hour/minute data
  /// - Completion map reconstruction with DateTime keys
  ///
  /// Provides backward compatibility for missing fields with sensible defaults.
  ///
  /// @param json JSON Map containing habit data
  /// @return Reconstructed Habit instance
  factory Habit.fromJson(Map<String, dynamic> json) {
    // Handle nullable TimeOfDay deserialization
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
      colorIndex: json['colorIndex'] as int? ?? 0, // Default to first color
      createdAt: DateTime.parse(json['createdAt'] as String),
      iconName: json['iconName'] as String? ?? 'check_circle', // Default icon
      reminderTime: reminderTime,
      enableReminders: json['enableReminders'] as bool? ?? false, // Default disabled
      // Reconstruct completion map with DateTime keys
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
