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
  static const int _databaseVersion = 1;

  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database with proper schema and enhanced error handling
  ///
  /// This method includes comprehensive error handling and recovery mechanisms
  /// to prevent database initialization from hanging the app, especially after
  /// being backgrounded for extended periods.
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      debugPrint('🗄️ Initializing database at: $path');

      // Try to open with shorter timeout to prevent hanging
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      ).timeout(
        const Duration(seconds: 5), // Reduced from 10 seconds
        onTimeout: () {
          debugPrint('⏰ Database initialization timed out after 5 seconds');
          throw TimeoutException(
            'Database initialization timed out',
            const Duration(seconds: 5),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');

      // Enhanced error logging for better debugging
      if (e is TimeoutException) {
        debugPrint(
          '⏰ Database timeout - this often happens after app backgrounding',
        );
        debugPrint('💡 Database may be locked by another process or corrupted');
      } else if (e.toString().contains('locked')) {
        debugPrint('🔒 Database is locked - another process may be using it');
        debugPrint(
          '💡 This can happen if the app was killed while database was open',
        );
      } else if (e.toString().contains('corrupt')) {
        debugPrint('💥 Database corruption detected');
        debugPrint('💡 Database file may be damaged');
      } else if (e.toString().contains('permission')) {
        debugPrint('🔐 Database permission error');
        debugPrint('💡 App may not have write access to database directory');
      }

      // Try to recover by deleting corrupted database
      if (e is TimeoutException ||
          e.toString().contains('locked') ||
          e.toString().contains('corrupt')) {
        debugPrint('🔄 Attempting database recovery...');
        try {
          await _attemptDatabaseRecovery();
          // Retry initialization after recovery
          return await _initDatabase();
        } catch (recoveryError) {
          debugPrint('❌ Database recovery failed: $recoveryError');
          debugPrint('💥 App will continue with in-memory data only');
        }
      }

      rethrow;
    }
  }

  /// Attempts to recover from database issues by deleting and recreating
  Future<void> _attemptDatabaseRecovery() async {
    try {
      debugPrint('🔄 Starting database recovery process...');

      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      // Close existing connection if any
      if (_database != null) {
        try {
          await _database!.close();
        } catch (e) {
          debugPrint('⚠️ Error closing existing database connection: $e');
        }
        _database = null;
      }

      // Delete corrupted database file
      try {
        await databaseFactory.deleteDatabase(path);
        debugPrint('✅ Corrupted database file deleted');
      } catch (e) {
        debugPrint('⚠️ Could not delete database file: $e');
        // Continue anyway - the database may not exist
      }

      debugPrint(
        '✅ Database recovery completed - ready for fresh initialization',
      );
    } catch (e) {
      debugPrint('❌ Database recovery process failed: $e');
      rethrow;
    }
  }

  /// Create database schema on first run
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🗄️ Creating database schema (version $version)');

    await db.transaction((txn) async {
      // Create habit_metadata table
      await txn.execute('''
        CREATE TABLE habit_metadata (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          color_index INTEGER NOT NULL,
          icon_name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_archived INTEGER NOT NULL DEFAULT 0,
          frequency_days TEXT NOT NULL,
          target_goal INTEGER NOT NULL DEFAULT 1,
          allow_exceed_goal INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Create daily_completions table with goal tracking
      await txn.execute('''
        CREATE TABLE daily_completions (
          habit_id TEXT NOT NULL,
          completion_date TEXT NOT NULL,
          completion_count INTEGER NOT NULL DEFAULT 0,
          goal_at_completion INTEGER NOT NULL,
          PRIMARY KEY (habit_id, completion_date),
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      // Create completion_times table for individual completion tracking
      await txn.execute('''
        CREATE TABLE completion_times (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id TEXT NOT NULL,
          completion_time TEXT NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      // Create habit_reminders table
      await txn.execute('''
        CREATE TABLE habit_reminders (
          habit_id TEXT PRIMARY KEY,
          reminder_time_hour INTEGER,
          reminder_time_minute INTEGER,
          enable_reminders INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      // Create app_settings table
      await txn.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Create habit_display_order table for custom ordering
      await txn.execute('''
        CREATE TABLE habit_display_order (
          habit_id TEXT PRIMARY KEY,
          order_value REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for better performance
      await txn.execute('''
        CREATE INDEX idx_daily_completions_date 
        ON daily_completions(completion_date)
      ''');

      await txn.execute('''
        CREATE INDEX idx_daily_completions_habit_id 
        ON daily_completions(habit_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_completion_times_habit_id 
        ON completion_times(habit_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_completion_times_time 
        ON completion_times(completion_time)
      ''');

      await txn.execute('''
        CREATE INDEX idx_habit_metadata_archived 
        ON habit_metadata(is_archived)
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
    debugPrint(
      '🗄️ Upgrading database from version $oldVersion to $newVersion',
    );

    // For now, just recreate with clean schema
    // TODO: Add proper migration logic when needed
    debugPrint('🔄 Recreating database with clean schema');
    await _recreateDatabase(db);
  }

  /// Recreate database with clean schema (development mode)
  Future<void> _recreateDatabase(Database db) async {
    await db.transaction((txn) async {
      // Drop all existing tables
      await txn.execute('DROP TABLE IF EXISTS habit_display_order');
      await txn.execute('DROP TABLE IF EXISTS habit_reminders');
      await txn.execute('DROP TABLE IF EXISTS habit_completions');
      await txn.execute('DROP TABLE IF EXISTS habit_completion_timestamps');
      await txn.execute('DROP TABLE IF EXISTS habits');
      await txn.execute('DROP TABLE IF EXISTS app_settings');

      // Create clean schema with TEXT timestamps
      await txn.execute('''
        CREATE TABLE habit_metadata (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          color_index INTEGER NOT NULL,
          icon_name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_archived INTEGER NOT NULL DEFAULT 0,
          frequency_days TEXT NOT NULL,
          target_goal INTEGER NOT NULL DEFAULT 1,
          allow_exceed_goal INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await txn.execute('''
        CREATE TABLE daily_completions (
          habit_id TEXT NOT NULL,
          completion_date TEXT NOT NULL,
          completion_count INTEGER NOT NULL DEFAULT 0,
          goal_at_completion INTEGER NOT NULL,
          PRIMARY KEY (habit_id, completion_date),
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE completion_times (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          habit_id TEXT NOT NULL,
          completion_time TEXT NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE habit_reminders (
          habit_id TEXT PRIMARY KEY,
          reminder_time_hour INTEGER,
          reminder_time_minute INTEGER,
          enable_reminders INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE habit_display_order (
          habit_id TEXT PRIMARY KEY,
          order_value REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habit_metadata(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Create indexes for better performance
      await txn.execute('''
        CREATE INDEX idx_daily_completions_date 
        ON daily_completions(completion_date)
      ''');

      await txn.execute('''
        CREATE INDEX idx_daily_completions_habit_id 
        ON daily_completions(habit_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_habit_metadata_archived 
        ON habit_metadata(is_archived)
      ''');

      await txn.execute('''
        CREATE INDEX idx_habit_order_value 
        ON habit_display_order(order_value)
      ''');

      debugPrint('✅ Database recreated with clean schema');
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
  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  /// Execute raw SQL insert
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  /// Execute raw SQL delete
  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }
}

/// Global singleton instance of DatabaseService
final databaseService = DatabaseService();
