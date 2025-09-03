import 'lib/models/habit.dart';

void main() {
  print('🧪 Testing new deterministic ID generation...\n');

  // Test sample habits
  final drinkWater = Habit.create(
    name: 'Drink Water',
    description: 'Drink 8 glasses of water daily',
    iconName: 'local_drink',
  );

  final exercise = Habit.create(
    name: 'Exercise',
    description: '30 minutes of physical activity',
    iconName: 'fitness_center',
  );

  final readBook = Habit.create(
    name: 'Read Book',
    description: 'Read for at least 20 minutes',
    iconName: 'book',
  );

  // Test deterministic ID generation
  print('📋 Sample Habit IDs:');
  print('Drink Water: "${drinkWater.id}"');
  print('Exercise: "${exercise.id}"');
  print('Read Book: "${readBook.id}"\n');

  // Test case insensitivity
  final drinkWaterUpper = Habit.create(
    name: 'DRINK WATER',
    description: 'Same habit with uppercase',
    iconName: 'local_drink',
  );

  print('🔄 Case Insensitivity Test:');
  print('Original: "${drinkWater.id}"');
  print('Uppercase: "${drinkWaterUpper.id}"');
  print('Same ID: ${drinkWater.id == drinkWaterUpper.id}\n');

  // Test different habit with same name but different icon
  final drinkWaterDifferentIcon = Habit.create(
    name: 'Drink Water',
    description: 'Same name, different icon',
    iconName: 'water_drop',
  );

  print('🎨 Different Icon Test:');
  print('Original: "${drinkWater.id}"');
  print('Different icon: "${drinkWaterDifferentIcon.id}"');
  print('Different ID: ${drinkWater.id != drinkWaterDifferentIcon.id}\n');

  print('✅ ID generation test completed successfully!');
}
