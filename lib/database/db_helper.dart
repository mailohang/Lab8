import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// DatabaseHelper is a singleton — only one instance exists across the app
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Lazy getter: opens/creates DB only when first accessed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('emails.db');
    return _database!;
  }

  // Create the SQLite database file and table
  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTable, // called only on first creation
    );
  }

  // SQL DDL — defines the emails table schema
  Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE emails (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        sender  TEXT    NOT NULL,
        subject TEXT    NOT NULL,
        preview TEXT,
        time    TEXT,
        isRead  INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ── CREATE ──────────────────────────────────────────────────────────────────
  Future<int> insertEmail(Map<String, dynamic> email) async {
    final db = await database;
    // INSERT OR REPLACE handles duplicates gracefully
    return await db.insert(
      'emails',
      email,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Bulk insert — used when importing from JSON or Excel
  Future<void> insertAll(List<Map<String, dynamic>> emails) async {
    final db = await database;
    final batch = db.batch(); // batch is faster than looping inserts
    for (final email in emails) {
      batch.insert('emails', email, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── READ ────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllEmails() async {
    final db = await database;
    return await db.query('emails', orderBy: 'id DESC');
  }

  // READ single row by primary key
  Future<Map<String, dynamic>?> getEmailById(int id) async {
    final db = await database;
    final result = await db.query('emails', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────────
  Future<int> updateEmail(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('emails', data, where: 'id = ?', whereArgs: [id]);
  }

  // ── DELETE ──────────────────────────────────────────────────────────────────
  Future<int> deleteEmail(int id) async {
    final db = await database;
    return await db.delete('emails', where: 'id = ?', whereArgs: [id]);
  }

  // Delete everything — useful for reset
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('emails');
  }

  // Close the database connection when done
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}