import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';

void main() {
  group('Puzzle', () {
    final puzzle = Puzzle(
      id: 7,
      answer: 'FLUTTER',
      clue: 'Cross-platform UI toolkit',
      category: 'Technology',
      difficulty: 2,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAt: DateTime.utc(2026, 1, 3, 4, 5, 6),
    );

    test('serializes dates as ISO-8601 and keys as column names', () {
      expect(puzzle.toMap(), {
        'id': 7,
        'answer': 'FLUTTER',
        'clue': 'Cross-platform UI toolkit',
        'category': 'Technology',
        'difficulty': 2,
        'created_at': '2026-01-02T03:04:05.000Z',
        'updated_at': '2026-01-03T04:05:06.000Z',
      });
    });

    test('round-trips through a map', () {
      expect(Puzzle.fromMap(puzzle.toMap()).toMap(), puzzle.toMap());
    });

    test('keeps a null id so SQLite can assign one', () {
      final unsaved = Puzzle(
        answer: 'DART',
        clue: 'The language',
        category: 'Technology',
        difficulty: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(unsaved.toMap()['id'], isNull);
    });
  });

  group('Attempt', () {
    final attempt = Attempt(
      id: 11,
      puzzleId: 7,
      status: 'solved',
      wrongGuesses: 2,
      hintsUsed: 1,
      hintKinds: 'clue',
      elapsedSeconds: 95,
      lastGuess: 'FLUTTER',
      userNote: 'Tricky one',
      startedAt: DateTime.utc(2026, 2, 1, 10),
      finishedAt: DateTime.utc(2026, 2, 1, 10, 1, 35),
    );

    test('serializes every column', () {
      expect(attempt.toMap(), {
        'id': 11,
        'puzzle_id': 7,
        'status': 'solved',
        'wrong_guesses': 2,
        'hints_used': 1,
        'hint_kinds': 'clue',
        'elapsed_seconds': 95,
        'last_guess': 'FLUTTER',
        'user_note': 'Tricky one',
        'started_at': '2026-02-01T10:00:00.000Z',
        'finished_at': '2026-02-01T10:01:35.000Z',
      });
    });

    test('round-trips through a map', () {
      expect(Attempt.fromMap(attempt.toMap()).toMap(), attempt.toMap());
    });

    test('defaults counters to zero and leaves optional columns null', () {
      final started = Attempt(
        puzzleId: 7,
        status: 'in_progress',
        startedAt: DateTime.utc(2026, 2, 1, 10),
      );

      expect(started.wrongGuesses, 0);
      expect(started.hintsUsed, 0);
      expect(started.elapsedSeconds, 0);
      expect(started.toMap()['hint_kinds'], isNull);
      expect(started.toMap()['last_guess'], isNull);
      expect(started.toMap()['user_note'], isNull);
      expect(started.toMap()['finished_at'], isNull);
    });

    test('round-trips an unfinished attempt', () {
      final started = Attempt(
        puzzleId: 7,
        status: 'in_progress',
        startedAt: DateTime.utc(2026, 2, 1, 10),
      );

      final restored = Attempt.fromMap(started.toMap());

      expect(restored.finishedAt, isNull);
      expect(restored.toMap(), started.toMap());
    });
  });
}
