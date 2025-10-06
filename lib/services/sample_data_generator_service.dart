import 'dart:math';
import 'package:flutter/material.dart';
import '../models/habit.dart';
// Removed unused import

/// Service for generating specific sample habits with historical completion data
///
/// This service creates exactly 3 habits with specific completion patterns
/// as requested: Learn Spanish, Journal Writing, and Read Pages.
class SampleDataGeneratorService {
  static final Random _random = Random();
  
  // Specific habit templates as requested
  static const List<Map<String, dynamic>> _habitTemplates = [
    {
      'name': 'Learn Spanish',
      'description': 'Practice Spanish vocabulary and grammar',
      'iconName': 'translate',
      'colorIndex': 0,
      'targetGoal': 1,
      'frequencyDays': {'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1},
      'completionPattern': 'max_1_per_day',
      'allowExceedGoal': false,
    },
    {
      'name': 'Journal Writing',
      'description': 'Reflect on daily experiences',
      'iconName': 'edit_note',
      'colorIndex': 1,
      'targetGoal': 4,
      'frequencyDays': {'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1},
      'completionPattern': 'weighted_0_to_4',
      'allowExceedGoal': false,
    },
    {
      'name': 'Read Pages',
      'description': 'Read books to expand knowledge',
      'iconName': 'menu_book',
      'colorIndex': 2,
      'targetGoal': 10,
      'frequencyDays': {'mon': 1, 'tue': 1, 'wed': 1, 'thu': 1, 'fri': 1, 'sat': 1, 'sun': 1},
      'completionPattern': 'random_0_to_20',
      'allowExceedGoal': true,
    },
  ];

  /// Generate the 3 specific sample habits with 2 years of completion data
  static Future<List<Habit>> generateSampleHabits({
    int numberOfHabits = 3, // Always 3 specific habits
    int yearsOfData = 2,
    Function(String habitName, double progress)? onProgress,
  }) async {
    debugPrint('🎲 Generating 3 specific sample habits with $yearsOfData years of data...');
    
    final habits = <Habit>[];
    final endDate = DateTime.now();
    final startDate = DateTime(endDate.year - yearsOfData, endDate.month, endDate.day);
    
    // Generate each specific habit
    for (int i = 0; i < _habitTemplates.length; i++) {
      final template = _habitTemplates[i];
      final habitName = template['name'] as String;
      
      // Report progress
      onProgress?.call(habitName, 0.0);
      
      final habit = await _generateHabitFromTemplate(template, startDate, endDate, onProgress);
      habits.add(habit);
      
      // Report completion
      onProgress?.call(habitName, 1.0);
    }
    
    debugPrint('✅ Generated ${habits.length} specific sample habits');
    return habits;
  }

  /// Generate a single habit from template with specific completion patterns
  static Future<Habit> _generateHabitFromTemplate(
    Map<String, dynamic> template,
    DateTime startDate,
    DateTime endDate,
    Function(String habitName, double progress)? onProgress,
  ) async {
    final habitName = template['name'] as String;
    final habit = Habit.createWithUuid(
      name: habitName,
      description: template['description'] as String,
      iconName: template['iconName'] as String,
      colorIndex: template['colorIndex'] as int,
      targetGoal: template['targetGoal'] as int,
      frequencyDays: Map<String, int>.from(template['frequencyDays'] as Map),
      allowExceedGoal: template['allowExceedGoal'] as bool,
    );

    // Generate completion data based on specific patterns
    final completions = <DateTime, CompletionRecord>{};
    final frequencyDays = Map<String, int>.from(template['frequencyDays'] as Map);
    final completionPattern = template['completionPattern'] as String;
    final targetGoal = template['targetGoal'] as int;
    
    DateTime currentDate = startDate;
    int totalDays = endDate.difference(startDate).inDays + 1;
    int processedDays = 0;
    
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      // Check if this day is active for this habit
      final dayName = _getDayName(currentDate.weekday);
      final isActiveDay = frequencyDays[dayName] == 1;
      
      if (isActiveDay) {
        int completionCount = _generateCompletionCount(completionPattern, targetGoal);
        
        if (completionCount > 0) {
          completions[currentDate] = CompletionRecord(
            count: completionCount,
            goalAtCompletion: targetGoal,
          );
        }
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
      processedDays++;
      
      // Report progress
      final progress = processedDays / totalDays;
      onProgress?.call(habitName, progress);
    }
    
    // Create habit with generated completions
    return Habit(
      id: habit.id,
      name: habit.name,
      description: habit.description,
      colorIndex: habit.colorIndex,
      createdAt: startDate.add(Duration(days: _random.nextInt(30))), // Random creation date within first month
      completions: completions,
      iconName: habit.iconName,
      reminderTime: _random.nextBool() ? TimeOfDay(hour: _random.nextInt(12) + 6, minute: _random.nextInt(60)) : null,
      enableReminders: _random.nextBool(),
      isArchived: false,
      frequencyDays: habit.frequencyDays,
      targetGoal: habit.targetGoal,
      allowExceedGoal: habit.allowExceedGoal,
    );
  }

  /// Generate completion count based on specific patterns
  static int _generateCompletionCount(String pattern, int targetGoal) {
    switch (pattern) {
      case 'max_1_per_day':
        // Learn Spanish: Randomly create maximum 1 completion per day
        return _random.nextBool() ? 1 : 0;
        
      case 'weighted_0_to_4':
        // Journal Writing: Randomly assign completions from 0 to 4, but 50% should be 4
        final roll = _random.nextDouble();
        if (roll < 0.5) {
          return 4; // 50% chance of 4
        } else {
          return _random.nextInt(4); // 0, 1, 2, or 3
        }
        
      case 'random_0_to_20':
        // Read Pages: Randomly assign completions from 0 to 20
        return _random.nextInt(21); // 0 to 20 inclusive
        
      default:
        return 0;
    }
  }

  /// Convert weekday number to day name
  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  /// Generate a single sample habit for testing
  static Future<Habit> generateSingleSampleHabit() async {
    final habits = await generateSampleHabits(numberOfHabits: 1);
    return habits.first;
  }

  /// Get statistics about generated sample data
  static Map<String, dynamic> getSampleDataStats(List<Habit> habits) {
    int totalCompletions = 0;
    int totalDays = 0;
    int habitsWithStreaks = 0;
    
    for (final habit in habits) {
      totalCompletions += habit.totalCompletions;
      totalDays += habit.completions.length;
      if (habit.currentStreak > 0) {
        habitsWithStreaks++;
      }
    }
    
    return {
      'totalHabits': habits.length,
      'totalCompletions': totalCompletions,
      'totalDays': totalDays,
      'habitsWithStreaks': habitsWithStreaks,
      'averageCompletionsPerHabit': habits.isNotEmpty ? totalCompletions / habits.length : 0,
      'averageDaysPerHabit': habits.isNotEmpty ? totalDays / habits.length : 0,
    };
  }
}
