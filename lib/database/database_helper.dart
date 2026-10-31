import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _fileName = 'puzzle_quest.db';
  static const _version = 2;

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
      onUpgrade: _upgradeTables,
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
        hint_kinds TEXT,
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

  // Every upgrade adds to the stored data; no attempt or puzzle row is
  // rewritten or dropped.
  Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE attempts ADD COLUMN hint_kinds TEXT');
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
