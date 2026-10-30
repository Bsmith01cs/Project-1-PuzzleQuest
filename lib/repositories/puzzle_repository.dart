import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/puzzle.dart';

class PuzzleRepository {
  PuzzleRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  static const _seededKey = 'starter_puzzles_seeded';

  final DatabaseHelper _helper;

  Future<void> seedStarterPuzzlesOnce() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_seededKey) ?? false) {
      return;
    }

    final now = DateTime.now().toUtc();

    await insert(
      Puzzle(
        answer: 'FLUTTER',
        clue: 'Toolkit used to build this app',
        category: 'Technology',
        difficulty: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await insert(
      Puzzle(
        answer: 'HARVEST',
        clue: 'Gathering of ripened crops',
        category: 'Nature',
        difficulty: 2,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await insert(
      Puzzle(
        answer: 'LABYRINTH',
        clue: 'Maze of winding passages',
        category: 'Places',
        difficulty: 3,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await preferences.setBool(_seededKey, true);
  }

  Future<int> insert(Puzzle puzzle) async {
    final db = await _helper.database;
    return db.insert('puzzles', puzzle.toMap());
  }

  Future<List<Puzzle>> findAll() async {
    final db = await _helper.database;
    final rows = await db.query('puzzles', orderBy: 'created_at DESC');
    return rows.map(Puzzle.fromMap).toList();
  }

  Future<Puzzle?> findById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'puzzles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Puzzle.fromMap(rows.first);
  }

  Future<int> update(Puzzle puzzle) async {
    final db = await _helper.database;
    return db.update(
      'puzzles',
      puzzle.toMap(),
      where: 'id = ?',
      whereArgs: [puzzle.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete('puzzles', where: 'id = ?', whereArgs: [id]);
  }
}
