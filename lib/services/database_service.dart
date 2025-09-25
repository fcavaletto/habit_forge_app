import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Service class for managing SQLite database operations
///
/// Handles database initialization, schema creation, and provides
/// a centralized interface for all database operations.
///
/// Features:
/// - Database initialization with proper schema
/// - Migration support for future schema changes
/// - Connection management and error handling
/// - Transaction support for data consistency
class DatabaseService {
  static const String _databaseName = 'habit_forge.db';
  static const int _databaseVersion = 4;
  
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();
  
  factory DatabaseService() => _instance;
  
  DatabaseService._internal();
  
  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  /// Initialize the database with proper schema
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);
      
      debugPrint('🗄️ Initializing database at: $path');
      
      // Add timeout to prevent hanging during database initialization
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Database initialization timed out', const Duration(seconds: 10));
        },
      );
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');
      rethrow;
    }
  }
  
  /// Create database schema on first run
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🗄️ Creating database schema (version $version)');
    
    await db.transaction((txn) async {
      // Create habits table
      await txn.execute('''
        CREATE TABLE habits (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          color_index INTEGER NOT NULL,
          icon_name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_archived INTEGER NOT NULL DEFAULT 0,
          frequency_days TEXT NOT NULL,
          target_goal INTEGER NOT NULL DEFAULT 1
        )
      ''');
      
      // Create habit_completions table with goal tracking
      await txn.execute('''
        CREATE TABLE habit_completions (
          habit_id TEXT NOT NULL,
          completion_date INTEGER NOT NULL,
          completion_count INTEGER NOT NULL DEFAULT 0,
          goal_at_completion INTEGER NOT NULL,
          PRIMARY KEY (habit_id, completion_date),
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      // Create habit_completion_timestamps table for individual completion tracking
      await txn.execute('''
        CREATE TABLE habit_completion_timestamps (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id TEXT NOT NULL,
          completion_timestamp INTEGER NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      // Create habit_reminders table
      await txn.execute('''
        CREATE TABLE habit_reminders (
          habit_id TEXT PRIMARY KEY,
          reminder_time_hour INTEGER,
          reminder_time_minute INTEGER,
          enable_reminders INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      // Create app_settings table
      await txn.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      // Create habit_display_order table for custom ordering
      await txn.execute('''
        CREATE TABLE habit_display_order (
          habit_id TEXT PRIMARY KEY,
          order_value REAL NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      // Create indexes for better performance
      await txn.execute('''
        CREATE INDEX idx_habit_completions_date 
        ON habit_completions(completion_date)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habit_completions_habit_id 
        ON habit_completions(habit_id)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habit_completion_timestamps_habit_id 
        ON habit_completion_timestamps(habit_id)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habit_completion_timestamps_timestamp 
        ON habit_completion_timestamps(completion_timestamp)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habits_archived 
        ON habits(is_archived)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habit_order_value 
        ON habit_display_order(order_value)
      ''');
    });
    
    debugPrint('✅ Database schema created successfully');
  }
  
  /// Handle database upgrades for future schema changes
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🗄️ Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      await _migrateToVersion2(db);
    }
    
    if (oldVersion < 3) {
      await _migrateToVersion3(db);
    }
    
    if (oldVersion < 4) {
      await _migrateToVersion4(db);
    }
  }
  
  /// Migrate database to version 2 - Add habit ordering support
  Future<void> _migrateToVersion2(Database db) async {
    debugPrint('🔄 Migrating to version 2: Adding habit ordering support');
    
    await db.transaction((txn) async {
      // Create habit_display_order table
      await txn.execute('''
        CREATE TABLE habit_display_order (
          habit_id TEXT PRIMARY KEY,
          order_value REAL NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      // Create index for ordering queries
      await txn.execute('''
        CREATE INDEX idx_habit_order_value 
        ON habit_display_order(order_value)
      ''');
      
      // Migrate existing habits with proper ordering (newest first)
      // Use rowid * 1000 to create large gaps for future insertions
      await txn.execute('''
        INSERT INTO habit_display_order (habit_id, order_value, created_at)
        SELECT id, CAST(rowid AS REAL) * 1000.0, created_at 
        FROM habits 
        WHERE is_archived = 0 
        ORDER BY created_at DESC
      ''');
      
      debugPrint('✅ Migration to version 2 completed successfully');
    });
  }
  
  /// Migrate database to version 3 - Fresh start with UUID-based IDs
  Future<void> _migrateToVersion3(Database db) async {
    debugPrint('🔄 Migrating to version 3: Fresh start with UUID-based IDs');
    
    // Since we're in early development, just recreate the database with new schema
    await db.transaction((txn) async {
      // Drop all existing tables
      await txn.execute('DROP TABLE IF EXISTS habit_display_order');
      await txn.execute('DROP TABLE IF EXISTS habit_reminders');
      await txn.execute('DROP TABLE IF EXISTS habit_completions');
      await txn.execute('DROP TABLE IF EXISTS habits');
      await txn.execute('DROP TABLE IF EXISTS app_settings');
      
      // Create new tables with UUID primary keys
      await txn.execute('''
        CREATE TABLE habits (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          color_index INTEGER NOT NULL,
          icon_name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_archived INTEGER NOT NULL DEFAULT 0,
          frequency_days TEXT NOT NULL,
          target_goal INTEGER NOT NULL DEFAULT 1
        )
      ''');
      
      // Create habit_completions table with goal tracking
      await txn.execute('''
        CREATE TABLE habit_completions (
          habit_id TEXT NOT NULL,
          completion_date INTEGER NOT NULL,
          completion_count INTEGER NOT NULL DEFAULT 0,
          goal_at_completion INTEGER NOT NULL,
          PRIMARY KEY (habit_id, completion_date),
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      // Create habit_completion_timestamps table for individual completion tracking
      await txn.execute('''
        CREATE TABLE habit_completion_timestamps (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id TEXT NOT NULL,
          completion_timestamp INTEGER NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
        )
      ''');
      
      await txn.execute('''
        CREATE TABLE habit_reminders (
          habit_id TEXT PRIMARY KEY,
          reminder_time_hour INTEGER,
          reminder_time_minute INTEGER,
          enable_reminders INTEGER NOT NULL DEFAULT 0
        )
      ''');
      
      await txn.execute('''
        CREATE TABLE habit_display_order (
          habit_id TEXT PRIMARY KEY,
          order_value REAL NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      
      await txn.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      // Create indexes
      await txn.execute('''
        CREATE INDEX idx_habit_completions_date 
        ON habit_completions(completion_date)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habit_completions_habit_id 
        ON habit_completions(habit_id)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habits_archived 
        ON habits(is_archived)
      ''');
      
      await txn.execute('''
        CREATE INDEX idx_habit_order_value 
        ON habit_display_order(order_value)
      ''');
      
      debugPrint('✅ Migration to version 3 completed successfully - Fresh database created');
    });
  }
  
  /// Migrate database to version 4 - Add timezone handling
  Future<void> _migrateToVersion4(Database db) async {
    debugPrint('🔄 Migrating to version 4: Adding timezone handling');
    
    await db.transaction((txn) async {
      // Create app_metadata table to track data format
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS app_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      
      // Mark existing data as legacy (local timezone)
      await txn.insert('app_metadata', {
        'key': 'timestamp_format',
        'value': 'legacy_local'
      });
      
      // Add index for better performance
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_app_metadata_key 
        ON app_metadata(key)
      ''');
      
      debugPrint('✅ Migration to version 4 completed successfully - Timezone handling added');
    });
  }
  
  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    debugPrint('🗄️ Database opened successfully');
    
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }
  
  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('🗄️ Database connection closed');
    }
  }
  
  /// Delete the database (for testing/debugging)
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    
    await databaseFactory.deleteDatabase(path);
    _database = null;
    debugPrint('🗄️ Database deleted');
  }
  
  /// Execute a transaction with proper error handling
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
  
  /// Execute raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }
  
  /// Execute raw SQL command
  Future<int> rawUpdate(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }
  
  /// Execute raw SQL insert
  Future<int> rawInsert(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }
  
  /// Execute raw SQL delete
  Future<int> rawDelete(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }
}

/// Global singleton instance of DatabaseService
final databaseService = DatabaseService();
