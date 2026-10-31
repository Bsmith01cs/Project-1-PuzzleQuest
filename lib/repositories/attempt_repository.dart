import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/attempt.dart';

class AttemptRepository {
  AttemptRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  Future<int> insert(Attempt attempt) async {
    final db = await _helper.database;
    return db.insert('attempts', attempt.toMap());
  }

  Future<List<Attempt>> findByPuzzle(int puzzleId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'attempts',
      where: 'puzzle_id = ?',
      whereArgs: [puzzleId],
      orderBy: 'started_at DESC',
    );
    return rows.map(Attempt.fromMap).toList();
  }

  Future<Attempt?> findLatestUnfinished(int puzzleId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'attempts',
      where: 'puzzle_id = ? AND finished_at IS NULL AND status != ?',
      whereArgs: [puzzleId, Attempt.statusSolved],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Attempt.fromMap(rows.first);
  }

  Future<Attempt?> findById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'attempts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Attempt.fromMap(rows.first);
  }

  Future<int> update(Attempt attempt) async {
    final db = await _helper.database;
    return db.update(
      'attempts',
      attempt.toMap(),
      where: 'id = ?',
      whereArgs: [attempt.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> delete(int id) async {
    final db = await _helper.database;
    return db.delete('attempts', where: 'id = ?', whereArgs: [id]);
  }
}
