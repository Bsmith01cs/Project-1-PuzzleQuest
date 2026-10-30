import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _fileName = 'puzzle_quest.db';
  static const _version = 1;

  Database? _database;

  Future<Database> get database async {
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);

    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE puzzles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        answer TEXT NOT NULL,
        clue TEXT NOT NULL,
        category TEXT NOT NULL,
        difficulty INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        puzzle_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        wrong_guesses INTEGER NOT NULL DEFAULT 0,
        hints_used INTEGER NOT NULL DEFAULT 0,
        elapsed_seconds INTEGER NOT NULL DEFAULT 0,
        last_guess TEXT,
        user_note TEXT,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        FOREIGN KEY (puzzle_id) REFERENCES puzzles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_attempts_puzzle_id ON attempts (puzzle_id)',
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
