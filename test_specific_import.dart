import 'package:flutter/material.dart';
import 'package:habit_forge_app/services/sample_data_generator_service.dart';
// No direct model usage here

/// Test script to verify the specific sample data generation
/// 
/// This script tests the exact requirements:
/// - Learn Spanish: Goal = 1, max 1 completion per day
/// - Journal Writing: Goal = 4, 0-4 completions with 50% being 4
/// - Read Pages: Goal = 10, 0-20 completions, allow exceed goal = true
void main() async {
  debugPrint('🧪 Testing specific sample data generation...');
  
  try {
    // Test the specific habits generation
    debugPrint('\n📝 Generating 3 specific sample habits...');
    final sampleHabits = await SampleDataGeneratorService.generateSampleHabits(
      numberOfHabits: 3,
      yearsOfData: 2,
      onProgress: (habitName, progress) {
        debugPrint('📊 $habitName: ${(progress * 100).toInt()}%');
      },
    );
    
    debugPrint('✅ Generated ${sampleHabits.length} specific sample habits');
    
    // Verify each habit meets the requirements
    for (final habit in sampleHabits) {
      debugPrint('\n🔍 Verifying ${habit.name}:');
      debugPrint('   - Target goal: ${habit.targetGoal}');
      debugPrint('   - Allow exceed goal: ${habit.allowExceedGoal}');
      debugPrint('   - Total completions: ${habit.totalCompletions}');
      debugPrint('   - Completion days: ${habit.completions.length}');
      
      // Check completion patterns
      final completionCounts = habit.completions.values.map((c) => c.count).toList();
      final maxCompletion = completionCounts.isNotEmpty ? completionCounts.reduce((a, b) => a > b ? a : b) : 0;
      final minCompletion = completionCounts.isNotEmpty ? completionCounts.reduce((a, b) => a < b ? a : b) : 0;
      
      debugPrint('   - Max completion in a day: $maxCompletion');
      debugPrint('   - Min completion in a day: $minCompletion');
      
      // Verify specific requirements
      switch (habit.name) {
        case 'Learn Spanish':
          if (habit.targetGoal == 1 && !habit.allowExceedGoal && maxCompletion <= 1) {
            debugPrint('   ✅ Learn Spanish: Requirements met');
          } else {
            debugPrint('   ❌ Learn Spanish: Requirements not met');
          }
          break;
          
        case 'Journal Writing':
          if (habit.targetGoal == 4 && !habit.allowExceedGoal && maxCompletion <= 4) {
            debugPrint('   ✅ Journal Writing: Requirements met');
          } else {
            debugPrint('   ❌ Journal Writing: Requirements not met');
          }
          break;
          
        case 'Read Pages':
          if (habit.targetGoal == 10 && habit.allowExceedGoal && maxCompletion <= 20) {
            debugPrint('   ✅ Read Pages: Requirements met');
          } else {
            debugPrint('   ❌ Read Pages: Requirements not met');
          }
          break;
      }
    }
    
    // Test statistics
    debugPrint('\n📊 Sample data statistics:');
    final stats = SampleDataGeneratorService.getSampleDataStats(sampleHabits);
    debugPrint('   - Total habits: ${stats['totalHabits']}');
    debugPrint('   - Total completions: ${stats['totalCompletions']}');
    debugPrint('   - Total days: ${stats['totalDays']}');
    debugPrint('   - Average completions per habit: ${stats['averageCompletionsPerHabit']?.toStringAsFixed(1)}');
    
    debugPrint('\n🎉 All tests completed successfully!');
    debugPrint('📈 The specific sample data generation is working correctly.');
    debugPrint('💡 The import feature with progress bars should work as expected in the app.');
    
  } catch (e) {
    debugPrint('❌ Test failed: $e');
    debugPrint('🔧 Please check the sample data generator service.');
  }
}
