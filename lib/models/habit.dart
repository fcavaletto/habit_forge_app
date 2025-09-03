

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

  /// Whether this habit is archived (hidden from main view but not deleted)
  final bool isArchived;

  /// Maximum number of habit colors available in the theme
  static const int maxColorIndex = 9;

  /// Default icon name for new habits
  static const String defaultIconName = 'check_circle';

  /// Default color index for new habits
  static const int defaultColorIndex = 0;

  Habit({
    required this.id,
    required this.name,
    required this.description,
    required this.colorIndex,
    required this.createdAt,
    required this.completions,
    this.iconName = defaultIconName,
    this.reminderTime,
    this.enableReminders = false,
    this.isArchived = false,
  }) : assert(colorIndex >= 0 && colorIndex <= maxColorIndex,
              'Color index must be between 0 and $maxColorIndex');

  /// Factory constructor to create a new habit with deterministic ID generation.
  ///
  /// Generates a unique, deterministic ID based on the normalized habit name
  /// and icon combination (format: "normalized_name_icon_name"). This ensures:
  /// - Consistent IDs for habits with the same name and icon
  /// - Reliable duplicate detection across archiving/unarchiving
  /// - Predictable behavior for sample habit management
  ///
  /// The name is normalized by converting to lowercase and trimming whitespace
  /// to ensure case-insensitive matching and handle user input variations.
  ///
  /// @param name Required habit name (will be trimmed and used for ID generation)
  /// @param description Optional detailed description (will be trimmed)
  /// @param colorIndex Visual color theme index (clamped to valid range 0-8)
  /// @param iconName Material Design icon identifier (used for ID generation)
  /// @param reminderTime Optional daily reminder time (null disables reminders)
  /// @param enableReminders Whether to enable reminder notifications
  /// @param isArchived Whether habit should start in archived state
  /// @return New Habit instance with deterministic ID and current timestamp
  /// @throws AssertionError if colorIndex is outside valid range
  factory Habit.create({
    required String name,
    required String description,
    int colorIndex = defaultColorIndex,
    String iconName = defaultIconName,
    TimeOfDay? reminderTime,
    bool enableReminders = false,
    bool isArchived = false,
  }) {
    // Generate deterministic ID based on normalized name and icon
    final normalizedName = name.toLowerCase().trim();
    final id = '${normalizedName}_${iconName}';

    return Habit(
      id: id, // Deterministic ID based on name + icon
      name: name.trim(), // Clean user input
      description: description.trim(), // Clean user input
      colorIndex: colorIndex.clamp(0, maxColorIndex), // Ensure valid color index
      createdAt: DateTime.now(), // Creation timestamp
      completions: {}, // Start with empty completion history
      iconName: iconName,
      reminderTime: reminderTime,
      enableReminders: enableReminders,
      isArchived: isArchived,
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
    
    if (completed) {
      newCompletions[normalizedDate] = true;
    } else {
      newCompletions.remove(normalizedDate);
    }
    
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

  /// Get the number of days since the habit was created
  ///
  /// @return Number of days since creation
  int get daysSinceCreation {
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  /// Check if the habit has been active for at least a minimum period
  ///
  /// @param minimumDays Minimum number of days required
  /// @return true if habit has been active for at least minimumDays
  bool isActiveForAtLeast(int minimumDays) {
    return daysSinceCreation >= minimumDays;
  }

  /// Get the most recent completion date
  ///
  /// @return The most recent date when the habit was completed, or null if never completed
  DateTime? get lastCompletedDate {
    if (completions.isEmpty) return null;

    final completedDates = completions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (completedDates.isEmpty) return null;

    completedDates.sort((a, b) => b.compareTo(a)); // Sort in descending order
    return completedDates.first;
  }

  /// Check if the habit is active (not archived)
  ///
  /// @return true if habit is not archived, false otherwise
  bool get isActive => !isArchived;

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
    bool? isArchived,
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
      isArchived: isArchived ?? this.isArchived,
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
      'isArchived': isArchived,
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
      colorIndex: json['colorIndex'] as int? ?? defaultColorIndex, // Default to first color
      createdAt: DateTime.parse(json['createdAt'] as String),
      iconName: json['iconName'] as String? ?? defaultIconName, // Default icon
      reminderTime: reminderTime,
      enableReminders: json['enableReminders'] as bool? ?? false, // Default disabled
      isArchived: json['isArchived'] as bool? ?? false, // Default to not archived
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
