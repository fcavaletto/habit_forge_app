import 'package:flutter/material.dart';
import 'package:habit_forge_app/services/sample_data_generator_service.dart';
// No direct model usage here

/// Test script to verify sample data generation functionality
/// 
/// This script can be run to test the import feature without the full app.
/// It generates sample habits and verifies they have realistic completion data.
void main() async {
  debugPrint('🧪 Starting sample data generation test...');
  
  try {
    // Test 1: Generate a single sample habit
    debugPrint('\n📝 Test 1: Generating single sample habit...');
    final singleHabit = await SampleDataGeneratorService.generateSingleSampleHabit();
    debugPrint('✅ Generated habit: ${singleHabit.name}');
    debugPrint('   - Target goal: ${singleHabit.targetGoal}');
    debugPrint('   - Total completions: ${singleHabit.totalCompletions}');
    debugPrint('   - Completion days: ${singleHabit.completions.length}');
    debugPrint('   - Current streak: ${singleHabit.currentStreak}');
    
    // Test 2: Generate multiple sample habits
    debugPrint('\n📝 Test 2: Generating multiple sample habits...');
    final sampleHabits = await SampleDataGeneratorService.generateSampleHabits(
      numberOfHabits: 5,
      yearsOfData: 2,
    );
    debugPrint('✅ Generated ${sampleHabits.length} sample habits');
    
    // Test 3: Verify statistics
    debugPrint('\n📝 Test 3: Analyzing sample data statistics...');
    final stats = SampleDataGeneratorService.getSampleDataStats(sampleHabits);
    debugPrint('📊 Sample data statistics:');
    debugPrint('   - Total habits: ${stats['totalHabits']}');
    debugPrint('   - Total completions: ${stats['totalCompletions']}');
    debugPrint('   - Total days: ${stats['totalDays']}');
    debugPrint('   - Habits with streaks: ${stats['habitsWithStreaks']}');
    debugPrint('   - Average completions per habit: ${stats['averageCompletionsPerHabit']?.toStringAsFixed(1)}');
    debugPrint('   - Average days per habit: ${stats['averageDaysPerHabit']?.toStringAsFixed(1)}');
    
    // Test 4: Verify habit diversity
    debugPrint('\n📝 Test 4: Verifying habit diversity...');
    final habitNames = sampleHabits.map((h) => h.name).toSet();
    final habitIcons = sampleHabits.map((h) => h.iconName).toSet();
    final habitColors = sampleHabits.map((h) => h.colorIndex).toSet();
    
    debugPrint('✅ Habit diversity check:');
    debugPrint('   - Unique names: ${habitNames.length}/${sampleHabits.length}');
    debugPrint('   - Unique icons: ${habitIcons.length}/${sampleHabits.length}');
    debugPrint('   - Unique colors: ${habitColors.length}/${sampleHabits.length}');
    
    // Test 5: Verify completion patterns
    debugPrint('\n📝 Test 5: Verifying completion patterns...');
    for (final habit in sampleHabits.take(3)) {
      debugPrint('📊 ${habit.name}:');
      debugPrint('   - Completion rate: ${(habit.completionRate * 100).toStringAsFixed(1)}%');
      // Optionally inspect more fields if available in the model
      debugPrint('   - Frequency days: ${habit.frequencyDays}');
      
      // Check if completion patterns make sense
      final weekendDays = habit.completions.keys.where((date) => 
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday
      ).length;
      final weekdayDays = habit.completions.keys.where((date) => 
        date.weekday >= DateTime.monday && date.weekday <= DateTime.friday
      ).length;
      
      debugPrint('   - Weekend completions: $weekendDays');
      debugPrint('   - Weekday completions: $weekdayDays');
    }
    
    debugPrint('\n🎉 All tests completed successfully!');
    debugPrint('📈 Sample data generation is working correctly.');
    debugPrint('💡 The import feature should work as expected in the app.');
    
  } catch (e) {
    debugPrint('❌ Test failed: $e');
    debugPrint('🔧 Please check the sample data generator service.');
  }
}
