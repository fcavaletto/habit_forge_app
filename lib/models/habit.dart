

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/virtual_date_service.dart';

/// Represents a completion record for a specific date
/// 
/// Stores both the completion count and the goal that was active
/// when the completion was recorded, enabling accurate historical tracking.
class CompletionRecord {
  final int count;
  final int goalAtCompletion;
  
  const CompletionRecord({
    required this.count,
    required this.goalAtCompletion,
  });
  
  /// Creates a CompletionRecord from JSON data
  factory CompletionRecord.fromJson(Map<String, dynamic> json) {
    return CompletionRecord(
      count: json['count'] as int,
      goalAtCompletion: json['goalAtCompletion'] as int,
    );
  }
  
  /// Converts CompletionRecord to JSON data
  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'goalAtCompletion': goalAtCompletion,
    };
  }
  
  /// Returns the completion percentage (0.0 to 1.0+)
  double get completionPercentage => count / goalAtCompletion;
  
  /// Returns true if the goal was fully achieved
  bool get isGoalAchieved => count >= goalAtCompletion;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletionRecord &&
        other.count == count &&
        other.goalAtCompletion == goalAtCompletion;
  }
  
  @override
  int get hashCode => count.hashCode ^ goalAtCompletion.hashCode;
  
  @override
  String toString() => 'CompletionRecord(count: $count, goalAtCompletion: $goalAtCompletion)';
}

/// Data model for hourly completion histogram analysis
///
/// Represents the distribution of habit completions throughout the day (0-23 hours)
/// with calculated percentages and metadata about the analysis period.
class HourlyHistogramData {
  final Map<int, int> hourlyCompletions; // hour (0-23) -> completion count
  final int totalCompletions;
  final DateTime startDate;
  final DateTime endDate;
  final String timeRange; // "Last 7 Days", "Last 30 Days", "Total"
  
  const HourlyHistogramData({
    required this.hourlyCompletions,
    required this.totalCompletions,
    required this.startDate,
    required this.endDate,
    required this.timeRange,
  });
  
  /// Calculate hourly completion percentages
  ///
  /// Returns a map where keys are hours (0-23) and values are percentages (0.0 to 1.0)
  Map<int, double> get hourlyPercentages {
    if (totalCompletions == 0) {
      return {for (int hour = 0; hour < 24; hour++) hour: 0.0};
    }
    
    return {
      for (int hour = 0; hour < 24; hour++)
        hour: hourlyCompletions[hour]! / totalCompletions
    };
  }
  
  /// Get the hour with the most completions
  int get peakHour {
    int maxHour = 0;
    int maxCount = 0;
    
    for (int hour = 0; hour < 24; hour++) {
      final count = hourlyCompletions[hour]!;
      if (count > maxCount) {
        maxCount = count;
        maxHour = hour;
      }
    }
    
    return maxHour;
  }
  
  /// Get the maximum completion count in any hour
  int get maxCompletionsInHour {
    return hourlyCompletions.values.reduce((a, b) => a > b ? a : b);
  }
  
  /// Get the maximum percentage in any hour
  double get maxPercentage {
    return hourlyPercentages.values.reduce((a, b) => a > b ? a : b);
  }
  
  /// Get hours with completions (non-zero counts)
  List<int> get activeHours {
    return hourlyCompletions.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }
  
  /// Check if there's any completion data
  bool get hasData => totalCompletions > 0;
  
  /// Get formatted time range description
  String get formattedTimeRange {
    switch (timeRange) {
      case 'Last 7 Days':
        return 'Last 7 Days';
      case 'Last 30 Days':
        return 'Last 30 Days';
      case 'Total':
        return 'Total';
      default:
        return 'Custom Range';
    }
  }
  
  /// Get formatted hour label (24-hour format)
  static String formatHour(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }
  
  /// Get short hour label for compact display
  static String formatHourShort(int hour) {
    return hour.toString().padLeft(2, '0');
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HourlyHistogramData &&
        other.hourlyCompletions.toString() == hourlyCompletions.toString() &&
        other.totalCompletions == totalCompletions &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.timeRange == timeRange;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      hourlyCompletions.toString(),
      totalCompletions,
      startDate,
      endDate,
      timeRange,
    );
  }
  
  @override
  String toString() {
    return 'HourlyHistogramData('
        'totalCompletions: $totalCompletions, '
        'timeRange: $timeRange, '
        'activeHours: ${activeHours.length}, '
        'peakHour: ${formatHour(peakHour)}'
        ')';
  }
}

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

  /// Map of completion records where key is date and value is CompletionRecord
  /// Missing entries indicate no completions for that day
  final Map<DateTime, CompletionRecord> completions;

  /// Material Icons name for visual representation
  final String iconName;

  /// Optional time of day for daily reminders (null if reminders disabled)
  final TimeOfDay? reminderTime;

  /// Whether daily reminders are enabled for this habit
  final bool enableReminders;

  /// Whether this habit is archived (hidden from main view but not deleted)
  final bool isArchived;

  /// Display order value for custom ordering (null if not set)
  final double? orderValue;

  /// Frequency data for when the habit should be active
  final Map<String, int> frequencyDays;

  /// Target number of completions per day for this habit
  final int targetGoal;

  /// Maximum number of habit colors available in the theme
  static const int maxColorIndex = 47;

  /// Default icon name for new habits
  static const String defaultIconName = 'check_circle';

  /// Default color index for new habits
  static const int defaultColorIndex = 0;

  /// Default frequency days (every day active)
  static const Map<String, int> defaultFrequencyDays = {
    'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1
  };

  /// Default target goal for new habits
  static const int defaultTargetGoal = 1;

  /// UUID generator instance
  static const _uuid = Uuid();

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
    this.orderValue,
    this.frequencyDays = defaultFrequencyDays,
    this.targetGoal = defaultTargetGoal,
  }) : assert(colorIndex >= 0 && colorIndex <= maxColorIndex,
              'Color index must be between 0 and $maxColorIndex'),
       assert(targetGoal > 0, 'Target goal must be greater than 0');

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
    String description = '',
    int colorIndex = defaultColorIndex,
    String iconName = defaultIconName,
    TimeOfDay? reminderTime,
    bool enableReminders = false,
    bool isArchived = false,
    Map<String, int>? frequencyDays,
    int targetGoal = defaultTargetGoal,
  }) {
    // Generate deterministic ID based on normalized name and icon
    final normalizedName = name.toLowerCase().trim();
    final id = '${normalizedName}_$iconName';

    return Habit(
      id: id, // Deterministic ID based on name + icon
      name: name.trim(), // Clean user input
      description: description.trim(), // Clean user input
      colorIndex: colorIndex.clamp(0, maxColorIndex), // Ensure valid color index
      createdAt: DateTime.now(), // Creation timestamp
      completions: <DateTime, CompletionRecord>{}, // Start with empty completion history
      iconName: iconName,
      reminderTime: reminderTime,
      enableReminders: enableReminders,
      isArchived: isArchived,
      frequencyDays: frequencyDays ?? defaultFrequencyDays,
      targetGoal: targetGoal,
    );
  }

  /// Factory constructor to create a new habit with UUID-based ID generation.
  ///
  /// Generates a unique UUID v4 identifier for the habit, allowing for
  /// flexible editing of name and icon without ID conflicts. This is the
  /// new preferred method for creating habits.
  ///
  /// @param name Required habit name (will be trimmed)
  /// @param description Optional detailed description (will be trimmed)
  /// @param colorIndex Visual color theme index (clamped to valid range 0-47)
  /// @param iconName Material Design icon identifier
  /// @param reminderTime Optional daily reminder time (null disables reminders)
  /// @param enableReminders Whether to enable reminder notifications
  /// @param isArchived Whether habit should start in archived state
  /// @param frequencyDays Map of days when habit is active
  /// @param targetGoal Daily completion target
  /// @return New Habit instance with UUID and current timestamp
  /// @throws AssertionError if colorIndex is outside valid range
  factory Habit.createWithUuid({
    required String name,
    String description = '',
    int colorIndex = defaultColorIndex,
    String iconName = defaultIconName,
    TimeOfDay? reminderTime,
    bool enableReminders = false,
    bool isArchived = false,
    Map<String, int>? frequencyDays,
    int targetGoal = defaultTargetGoal,
  }) {
    // Generate unique UUID v4
    final id = _uuid.v4();

    return Habit(
      id: id, // UUID-based ID
      name: name.trim(), // Clean user input
      description: description.trim(), // Clean user input
      colorIndex: colorIndex.clamp(0, maxColorIndex), // Ensure valid color index
      createdAt: DateTime.now(), // Creation timestamp
      completions: <DateTime, CompletionRecord>{}, // Start with empty completion history
      iconName: iconName,
      reminderTime: reminderTime,
      enableReminders: enableReminders,
      isArchived: isArchived,
      frequencyDays: frequencyDays ?? defaultFrequencyDays,
      targetGoal: targetGoal,
    );
  }

  /// Mark habit with completion count for a specific date
  ///
  /// Creates a new Habit instance with updated completion count.
  /// Uses immutable pattern - returns new instance rather than modifying existing.
  ///
  /// @param date The date to update completion for
  /// @param count The number of completions for this date (0 to remove)
  /// @return New Habit instance with updated completion map
  Habit markCompleted(DateTime date, int count) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final newCompletions = Map<DateTime, CompletionRecord>.from(completions);

    if (count > 0) {
      newCompletions[normalizedDate] = CompletionRecord(
        count: count,
        goalAtCompletion: targetGoal,
      );
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
  /// @return true if habit has at least one completion on this date, false otherwise
  bool isCompleted(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return (completions[normalizedDate]?.count ?? 0) > 0;
  }

  /// Get the completion count for a specific date
  ///
  /// @param date The date to get completion count for
  /// @return The number of completions for this date (0 if none)
  int getCompletionCount(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return completions[normalizedDate]?.count ?? 0;
  }
  
  /// Get the completion record for a specific date
  ///
  /// @param date The date to get completion record for
  /// @return The CompletionRecord for this date (null if none)
  CompletionRecord? getCompletionRecord(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return completions[normalizedDate];
  }
  
  /// Get the goal that was active when completion was recorded for a specific date
  ///
  /// @param date The date to get goal for
  /// @return The goal at completion (current targetGoal if no completion record)
  int getGoalAtCompletion(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return completions[normalizedDate]?.goalAtCompletion ?? targetGoal;
  }

  /// Check if the goal is achieved for a specific date
  ///
  /// @param date The date to check goal achievement for
  /// @return true if completion count >= goal at completion, false otherwise
  bool isGoalAchieved(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final record = completions[normalizedDate];
    if (record == null) return false;
    return record.count >= record.goalAtCompletion;
  }

  /// Calculate current streak of consecutive goal-achieved days
  ///
  /// Counts backward from the virtual current date to find the longest sequence
  /// of consecutive days where this habit achieved its goal.
  ///
  /// @return Number of consecutive days with goal achieved (ending on virtual current date or yesterday)
  int get currentStreak {
    final today = VirtualDateService().currentDate;
    int streak = 0;
    DateTime checkDate = today;

    // Count consecutive goal-achieved days backward from virtual current date
    while (isGoalAchieved(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Get total number of completions for this habit
  ///
  /// Sums all completion counts across all dates.
  /// Represents the total number of completions this habit has recorded.
  ///
  /// @return Total sum of all completion counts across all time
  int get totalCompletions {
    return completions.values.fold(0, (sum, record) => sum + record.count);
  }

  /// Calculate completion rate for the last 30 days
  ///
  /// Measures habit adherence over the most recent 30-day period from the virtual current date.
  /// Each day's completion percentage is calculated based on the target goal.
  /// Used for progress tracking and habit strength assessment.
  ///
  /// @return Ratio between 0.0 and 1.0 representing average completion percentage
  double get completionRate {
    double totalCompletionPercentage = 0.0;
    int daysWithData = 0;
    
    for (int i = 0; i < 30; i++) {
      final date = VirtualDateService().currentDate.subtract(Duration(days: i));
      final record = completions[DateTime(date.year, date.month, date.day)];
      final percentage = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      totalCompletionPercentage += percentage;
      daysWithData++;
    }
    
    return daysWithData > 0 ? totalCompletionPercentage / daysWithData : 0.0;
  }

  /// Generate completion data for the last 7 days
  ///
  /// Used by UI components to display recent progress in compact views.
  /// Returns boolean array where each element represents a day's completion status.
  /// Index 0 = 6 days ago, Index 6 = virtual current date
  ///
  /// @return List of 7 boolean values representing daily completion status
  List<bool> get last7Days {
    final today = VirtualDateService().currentDate;
    return List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index)); // 6 days ago to virtual current date
      return isCompleted(date);
    });
  }

  /// Generate completion data for the last 4 weeks (28 days)
  ///
  /// Creates a 2D array suitable for grid-based calendar visualization.
  /// Each inner list represents a week (7 days), with 4 weeks total.
  /// Used by detailed calendar views and progress charts.
  /// Based on the virtual current date.
  ///
  /// @return 4x7 grid of completion status (week × day)
  List<List<bool>> get last4Weeks {
    final today = VirtualDateService().currentDate;
    return List.generate(4, (weekIndex) { // 4 weeks
      return List.generate(7, (dayIndex) { // 7 days per week
        final date = today.subtract(Duration(
          days: (3 - weekIndex) * 7 + (6 - dayIndex), // Calculate date offset from virtual current date
        ));
        return isCompleted(date);
      });
    });
  }

  /// Get the number of days since the habit was created
  ///
  /// @return Number of days since creation (based on virtual current date)
  int get daysSinceCreation {
    final now = VirtualDateService().currentDate;
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
        .where((entry) => entry.value.count > 0) // At least 1 completion
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
    Map<DateTime, CompletionRecord>? completions,
    String? iconName,
    TimeOfDay? reminderTime,
    bool? enableReminders,
    bool? isArchived,
    double? orderValue,
    Map<String, int>? frequencyDays,
    int? targetGoal,
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
      orderValue: orderValue ?? this.orderValue,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      targetGoal: targetGoal ?? this.targetGoal,
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
      'frequencyDays': frequencyDays,
      'targetGoal': targetGoal,
      // Convert DateTime keys to ISO strings and CompletionRecord to JSON
      'completions': completions.map(
        (key, value) => MapEntry(key.toIso8601String(), value.toJson()),
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
      frequencyDays: (json['frequencyDays'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as int),
      ) ?? defaultFrequencyDays, // Default to every day
      targetGoal: json['targetGoal'] as int? ?? defaultTargetGoal, // Default to 1
      // Reconstruct completion map with DateTime keys and CompletionRecord values
      // Handle backward compatibility: convert old format to CompletionRecord
      completions: (json['completions'] as Map<String, dynamic>).map(
        (key, value) {
          final date = DateTime.parse(key);
          if (value is Map<String, dynamic>) {
            // New format: CompletionRecord
            return MapEntry(date, CompletionRecord.fromJson(value));
          } else if (value is int) {
            // Old format: just count, use current targetGoal
            return MapEntry(date, CompletionRecord(
              count: value,
              goalAtCompletion: json['targetGoal'] as int? ?? defaultTargetGoal,
            ));
          } else if (value is bool) {
            // Very old format: boolean, convert to count
            return MapEntry(date, CompletionRecord(
              count: value ? 1 : 0,
              goalAtCompletion: json['targetGoal'] as int? ?? defaultTargetGoal,
            ));
          } else {
            // Fallback
            return MapEntry(date, CompletionRecord(
              count: 0,
              goalAtCompletion: json['targetGoal'] as int? ?? defaultTargetGoal,
            ));
          }
        },
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
