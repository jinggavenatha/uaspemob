//import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // Initialize database factory for different platforms
  static Future<void> initializeDatabaseFactory() async {
    if (kIsWeb) {
      // For web platform, sqflite_common_ffi doesn't support web directly
      // We'll handle this differently or use alternative storage
      throw UnsupportedError(
          'SQLite is not supported on web platform. Consider using IndexedDB or Hive instead.');
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // For mobile platforms (Android/iOS), use default sqflite
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'medicine_reminder.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        profile_picture TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel Medicines
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        dosage TEXT NOT NULL,
        unit TEXT NOT NULL,
        start_date DATE NOT NULL,
        end_date DATE,
        notes TEXT,
        photo TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tabel Schedules
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        time TIME NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        days TEXT,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');

    // Tabel Medicine Logs (untuk tracking sudah minum atau belum)
    await db.execute('''
      CREATE TABLE medicine_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        medicine_id INTEGER NOT NULL,
        schedule_id INTEGER NOT NULL,
        taken_at TIMESTAMP,
        status TEXT NOT NULL DEFAULT 'pending',
        scheduled_date DATE NOT NULL,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE,
        FOREIGN KEY (schedule_id) REFERENCES schedules (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Database upgrade from version $oldVersion to $newVersion');
    
    try {
      if (oldVersion < 2) {
        // Add photo column to medicines table if upgrading from version 1
        await db.execute('ALTER TABLE medicines ADD COLUMN photo TEXT');
        print('Added photo column to medicines table');
      }
      
      if (oldVersion < 3) {
        // Add days column to schedules table if upgrading from version 2
        await db.execute('ALTER TABLE schedules ADD COLUMN days TEXT');
        print('Added days column to schedules table');
      }
      
      print('Database upgrade completed successfully');
    } catch (e) {
      print('Error during database upgrade: $e');
      print('Falling back to recreating tables...');
      await _recreateTablesWithNewSchema(db);
    }
  }

  Future<void> _recreateTablesWithNewSchema(Database db) async {
    print('Recreating tables with new schema...');

    try {
      // Backup existing data
      final users = await db.query('users');
      final medicines = await db.query('medicines');
      final schedules = await db.query('schedules');
      final medicineLogs = await db.query('medicine_logs');

      // Drop existing tables
      await db.execute('DROP TABLE IF EXISTS medicine_logs');
      await db.execute('DROP TABLE IF EXISTS schedules');
      await db.execute('DROP TABLE IF EXISTS medicines');
      await db.execute('DROP TABLE IF EXISTS users');

      // Recreate tables with new schema
      await _onCreate(db, 3);

      // Restore data
      for (final user in users) {
        await db.insert('users', user);
      }

      for (final medicine in medicines) {
        // Add photo column if not exists
        final medicineData = Map<String, dynamic>.from(medicine);
        if (!medicineData.containsKey('photo')) {
          medicineData['photo'] = null;
        }
        await db.insert('medicines', medicineData);
      }

      for (final schedule in schedules) {
        await db.insert('schedules', schedule);
      }

      for (final log in medicineLogs) {
        await db.insert('medicine_logs', log);
      }

      print('Tables recreated successfully with data restored');
    } catch (e) {
      print('Error recreating tables: $e');
      rethrow;
    }
  }

  // Generic CRUD Operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  // Raw Query untuk query kompleks
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Reset database (untuk debugging)
  Future<void> resetDatabase() async {
    try {
      print('Resetting database...');
      final dbPath = join(await getDatabasesPath(), 'medicine_reminder.db');

      // Close existing connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Delete database file
      await deleteDatabase(dbPath);
      print('Database reset completed');

      // Reinitialize
      _database = await _initDatabase();
      print('Database reinitialized');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }
}
