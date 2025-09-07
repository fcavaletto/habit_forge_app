import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Simple script to verify the SQLite database was created correctly
Future<void> main() async {
  print('🔍 Verifying SQLite migration...');
  
  try {
    // Get database path
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'habit_forge.db');
    
    print('📁 Database path: $dbPath');
    
    // Check if database file exists
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      print('❌ Database file does not exist');
      return;
    }
    
    print('✅ Database file exists');
    
    // Open database
    final database = await openDatabase(dbPath);
    
    // Check tables
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    );
    
    print('📊 Tables found:');
    for (final table in tables) {
      print('  - ${table['name']}');
    }
    
    // Check habits table structure
    final habitsColumns = await database.rawQuery("PRAGMA table_info(habits)");
    print('\n📋 Habits table structure:');
    for (final column in habitsColumns) {
      print('  - ${column['name']} (${column['type']})');
    }
    
    // Check habit_completions table structure
    final completionsColumns = await database.rawQuery("PRAGMA table_info(habit_completions)");
    print('\n📋 Habit completions table structure:');
    for (final column in completionsColumns) {
      print('  - ${column['name']} (${column['type']})');
    }
    
    // Check habit_reminders table structure
    final remindersColumns = await database.rawQuery("PRAGMA table_info(habit_reminders)");
    print('\n📋 Habit reminders table structure:');
    for (final column in remindersColumns) {
      print('  - ${column['name']} (${column['type']})');
    }
    
    // Count records
    final habitsCount = Sqflite.firstIntValue(await database.rawQuery("SELECT COUNT(*) FROM habits")) ?? 0;
    final completionsCount = Sqflite.firstIntValue(await database.rawQuery("SELECT COUNT(*) FROM habit_completions")) ?? 0;
    final remindersCount = Sqflite.firstIntValue(await database.rawQuery("SELECT COUNT(*) FROM habit_reminders")) ?? 0;
    
    print('\n📊 Record counts:');
    print('  - Habits: $habitsCount');
    print('  - Completions: $completionsCount');
    print('  - Reminders: $remindersCount');
    
    await database.close();
    print('\n✅ Migration verification completed successfully!');
    
  } catch (e) {
    print('❌ Error verifying migration: $e');
  }
}
