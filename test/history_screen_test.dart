import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/repositories/attempt_repository.dart';
import 'package:puzzle_quest/repositories/puzzle_repository.dart';
import 'package:puzzle_quest/screens/history_screen.dart';

Attempt buildAttempt({
  required int id,
  int puzzleId = 1,
  String status = Attempt.statusSolved,
  int wrongGuesses = 1,
  int elapsedSeconds = 65,
  String? note,
  DateTime? finishedAt,
}) {
  return Attempt(
    id: id,
    puzzleId: puzzleId,
    status: status,
    wrongGuesses: wrongGuesses,
    elapsedSeconds: elapsedSeconds,
    userNote: note,
    startedAt: DateTime.utc(2026, 3, id, 9),
    finishedAt: finishedAt,
  );
}

Attempt withNote(Attempt attempt, String? note) {
  return Attempt(
    id: attempt.id,
    puzzleId: attempt.puzzleId,
    status: attempt.status,
    wrongGuesses: attempt.wrongGuesses,
    hintsUsed: attempt.hintsUsed,
    elapsedSeconds: attempt.elapsedSeconds,
    lastGuess: attempt.lastGuess,
    userNote: note,
    startedAt: attempt.startedAt,
    finishedAt: attempt.finishedAt,
  );
}

Puzzle buildPuzzle({
  int id = 1,
  String answer = 'FLUTTER',
  String category = 'Technology',
}) {
  final now = DateTime.utc(2026, 3, 1);

  return Puzzle(
    id: id,
    answer: answer,
    clue: 'Clue for $answer',
    category: category,
    difficulty: 1,
    createdAt: now,
    updatedAt: now,
  );
}

class FakeAttemptRepository extends AttemptRepository {
  FakeAttemptRepository([List<Attempt>? attempts])
    : attempts = List<Attempt>.from(attempts ?? const <Attempt>[]);

  final List<Attempt> attempts;
  final List<String?> savedNotes = [];
  final List<int> deleted = [];

  bool failOnLoad = false;
  bool failOnWrite = false;

  @override
  Future<List<Attempt>> findAll() async {
    if (failOnLoad) {
      throw Exception('database unavailable');
    }
    return List<Attempt>.unmodifiable(attempts);
  }

  @override
  Future<int> updateNote(int id, String? note) async {
    if (failOnWrite) {
      throw Exception('write failed');
    }
    savedNotes.add(note);
    final index = attempts.indexWhere((attempt) => attempt.id == id);
    attempts[index] = withNote(attempts[index], note);
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    if (failOnWrite) {
      throw Exception('write failed');
    }
    deleted.add(id);
    attempts.removeWhere((attempt) => attempt.id == id);
    return 1;
  }
}

class FakePuzzleRepository extends PuzzleRepository {
  FakePuzzleRepository([List<Puzzle>? puzzles])
    : puzzles = List<Puzzle>.from(puzzles ?? const <Puzzle>[]);

  final List<Puzzle> puzzles;

  @override
  Future<void> seedStarterPuzzlesOnce() async {}

  @override
  Future<List<Puzzle>> findAll() async => List<Puzzle>.unmodifiable(puzzles);
}

Widget wrapHistory(
  FakeAttemptRepository attempts, {
  FakePuzzleRepository? puzzles,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HistoryScreen(
        attempts: attempts,
        puzzles: puzzles ?? FakePuzzleRepository([buildPuzzle()]),
      ),
    ),
  );
}

void main() {
  group('filterAttemptsByStatus', () {
    final attempts = [
      buildAttempt(id: 1, status: Attempt.statusSolved),
      buildAttempt(id: 2, status: Attempt.statusPaused),
      buildAttempt(id: 3, status: Attempt.statusInProgress),
      buildAttempt(id: 4, status: Attempt.statusSolved),
    ];

    test('returns every attempt when no status is given', () {
      expect(filterAttemptsByStatus(attempts, null), hasLength(4));
    });

    test('keeps only the matching status', () {
      expect(
        filterAttemptsByStatus(attempts, Attempt.statusSolved)
            .map((attempt) => attempt.id),
        [1, 4],
      );
      expect(
        filterAttemptsByStatus(attempts, Attempt.statusPaused)
            .map((attempt) => attempt.id),
        [2],
      );
      expect(
        filterAttemptsByStatus(attempts, Attempt.statusInProgress)
            .map((attempt) => attempt.id),
        [3],
      );
    });

    test('returns nothing for a status no attempt has', () {
      final paused = [buildAttempt(id: 1, status: Attempt.statusPaused)];

      expect(filterAttemptsByStatus(paused, Attempt.statusSolved), isEmpty);
    });
  });

  group('statistics', () {
    test('counts solved attempts only', () {
      final attempts = [
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusPaused),
        buildAttempt(id: 3, status: Attempt.statusSolved),
      ];

      expect(solvedAttemptCount(attempts), 2);
    });

    test('completion rate is solved over total as a percentage', () {
      final attempts = [
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusPaused),
        buildAttempt(id: 3, status: Attempt.statusPaused),
        buildAttempt(id: 4, status: Attempt.statusSolved),
      ];

      expect(completionRate(attempts), 50);
      expect(formatCompletionRate(attempts), '50%');
    });

    test('completion rate rounds to the nearest percent', () {
      final attempts = [
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusSolved),
        buildAttempt(id: 3, status: Attempt.statusPaused),
      ];

      expect(completionRate(attempts), closeTo(66.67, 0.01));
      expect(formatCompletionRate(attempts), '67%');
    });

    test('an empty history reports zero instead of dividing by zero', () {
      expect(solvedAttemptCount(const []), 0);
      expect(completionRate(const []), 0);
      expect(formatCompletionRate(const []), '0%');
    });

    test('every attempt solved reports one hundred percent', () {
      final attempts = [buildAttempt(id: 1), buildAttempt(id: 2)];

      expect(formatCompletionRate(attempts), '100%');
    });
  });

  group('validateNote', () {
    test('accepts an empty note, which clears it', () {
      expect(validateNote(''), isNull);
      expect(validateNote(null), isNull);
      expect(validateNote('   '), isNull);
    });

    test('accepts a note at the limit', () {
      expect(validateNote('a' * maxNoteLength), isNull);
    });

    test('rejects a note over the limit', () {
      expect(
        validateNote('a' * (maxNoteLength + 1)),
        'Keep the note to 140 characters or fewer.',
      );
    });

    test('measures the trimmed note', () {
      expect(validateNote('  ${'a' * maxNoteLength}  '), isNull);
    });
  });

  group('labels', () {
    test('maps stored statuses to readable labels', () {
      expect(attemptStatusLabel(Attempt.statusInProgress), 'In Progress');
      expect(attemptStatusLabel(Attempt.statusPaused), 'Paused');
      expect(attemptStatusLabel(Attempt.statusSolved), 'Solved');
    });

    test('falls back to an unknown status as stored', () {
      expect(attemptStatusLabel('archived'), 'archived');
    });

    test('formats a completion date', () {
      expect(formatAttemptDate(DateTime(2026, 3, 1, 9, 5)), '2026-03-01 09:05');
      expect(
        formatAttemptDate(DateTime(2026, 11, 24, 18, 42)),
        '2026-11-24 18:42',
      );
    });
  });

  group('history screen', () {
    testWidgets('shows the empty state and zeroed statistics', (tester) async {
      await tester.pumpWidget(wrapHistory(FakeAttemptRepository()));
      await tester.pumpAndSettle();

      expect(
        find.text('No attempts yet. Play a puzzle to start your history.'),
        findsOneWidget,
      );
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Attempts'), findsOneWidget);
      expect(find.text('Solved attempts'), findsOneWidget);
      expect(find.text('Completion rate'), findsOneWidget);
    });

    testWidgets('lists an attempt with its puzzle and progress', (
      tester,
    ) async {
      final finishedAt = DateTime(2026, 3, 2, 14, 30);
      final attempts = FakeAttemptRepository([
        buildAttempt(
          id: 1,
          wrongGuesses: 3,
          elapsedSeconds: 125,
          finishedAt: finishedAt,
          note: 'Tricky one',
        ),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(find.text('Technology · Solved'), findsOneWidget);
      expect(find.text('Time 02:05 · Wrong guesses 3'), findsOneWidget);
      expect(find.text('Completed 2026-03-02 14:30'), findsOneWidget);
      expect(find.text('Tricky one'), findsOneWidget);
      expect(find.text('FLUTTER'), findsNothing);
    });

    testWidgets('an unfinished attempt shows no completion date', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, status: Attempt.statusPaused),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      expect(find.text('Technology · Paused'), findsOneWidget);
      expect(find.textContaining('Completed'), findsNothing);
    });

    testWidgets('statistics summarise the stored attempts', (tester) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusPaused),
        buildAttempt(id: 3, status: Attempt.statusSolved),
        buildAttempt(id: 4, status: Attempt.statusInProgress),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('the status filter narrows the list', (tester) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusPaused, puzzleId: 2),
      ]);
      final puzzles = FakePuzzleRepository([
        buildPuzzle(),
        buildPuzzle(id: 2, answer: 'HARVEST', category: 'Nature'),
      ]);

      await tester.pumpWidget(wrapHistory(attempts, puzzles: puzzles));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(find.text('Clue for HARVEST'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Solved'));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(find.text('Clue for HARVEST'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Paused'));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsNothing);
      expect(find.text('Clue for HARVEST'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(find.text('Clue for HARVEST'), findsOneWidget);
    });

    testWidgets('statistics ignore the active filter', (tester) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusPaused),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Solved'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('a filter with no matches keeps its own message', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, status: Attempt.statusPaused),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Solved'));
      await tester.pumpAndSettle();

      expect(find.text('No attempts with this status.'), findsOneWidget);
      expect(
        find.text('No attempts yet. Play a puzzle to start your history.'),
        findsNothing,
      );
    });

    testWidgets('a load failure shows an error with a retry action', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository([buildAttempt(id: 1)]);
      attempts.failOnLoad = true;

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load history.'), findsOneWidget);

      attempts.failOnLoad = false;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('attempt notes', () {
    testWidgets('adding a note stores it and refreshes the card', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository([buildAttempt(id: 1)]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Add note'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Solved on the bus  ');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(attempts.savedNotes, ['Solved on the bus']);
      expect(find.text('Solved on the bus'), findsOneWidget);
      expect(find.text('Note saved.'), findsOneWidget);
    });

    testWidgets('an existing note opens prefilled for editing', (tester) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, note: 'First try'),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit note'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'First try',
      );

      await tester.enterText(find.byType(TextField), 'Second try');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(attempts.savedNotes, ['Second try']);
      expect(find.text('Second try'), findsOneWidget);
    });

    testWidgets('clearing a note removes it', (tester) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, note: 'First try'),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(attempts.savedNotes, [null]);
      expect(find.text('First try'), findsNothing);
      expect(find.text('Note removed.'), findsOneWidget);
    });

    testWidgets('cancelling the dialog writes nothing', (tester) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, note: 'First try'),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Discarded');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(attempts.savedNotes, isEmpty);
      expect(find.text('First try'), findsOneWidget);
    });

    testWidgets('the note field stops at the maximum length', (tester) async {
      final attempts = FakeAttemptRepository([buildAttempt(id: 1)]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, maxNoteLength);

      await tester.enterText(find.byType(TextField), 'a' * 200);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(attempts.savedNotes.single?.length, maxNoteLength);
    });

    testWidgets('a failed note write is reported without losing the list', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository([buildAttempt(id: 1)]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_note_outlined));
      await tester.pumpAndSettle();

      attempts.failOnWrite = true;
      await tester.enterText(find.byType(TextField), 'Note');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not save the note.'),
        findsOneWidget,
      );
      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('attempt deletion', () {
    testWidgets('cancelling the dialog keeps the attempt', (tester) async {
      final attempts = FakeAttemptRepository([buildAttempt(id: 1)]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete attempt?'), findsOneWidget);
      expect(
        find.textContaining('saved progress and note for "Clue for FLUTTER"'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(attempts.deleted, isEmpty);
      expect(find.text('Clue for FLUTTER'), findsOneWidget);
    });

    testWidgets('confirming removes the attempt and updates statistics', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository([
        buildAttempt(id: 1, status: Attempt.statusSolved),
        buildAttempt(id: 2, status: Attempt.statusPaused),
      ]);

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(attempts.deleted, [1]);
      expect(find.text('Attempt deleted.'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a failed delete is reported without crashing', (tester) async {
      final attempts = FakeAttemptRepository([buildAttempt(id: 1)]);
      attempts.failOnWrite = true;

      await tester.pumpWidget(wrapHistory(attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not delete the attempt.'),
        findsOneWidget,
      );
      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
