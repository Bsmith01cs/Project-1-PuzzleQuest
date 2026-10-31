import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/repositories/attempt_repository.dart';
import 'package:puzzle_quest/repositories/puzzle_repository.dart';
import 'package:puzzle_quest/screens/editor_screen.dart';
import 'package:puzzle_quest/screens/home_shell.dart';

class FakePuzzleRepository extends PuzzleRepository {
  FakePuzzleRepository([List<Puzzle>? puzzles])
    : puzzles = List<Puzzle>.from(puzzles ?? const <Puzzle>[]);

  final List<Puzzle> puzzles;
  final List<Puzzle> inserted = [];
  final List<Puzzle> updated = [];
  bool failOnLoad = false;

  @override
  Future<void> seedStarterPuzzlesOnce() async {}

  @override
  Future<List<Puzzle>> findAll() async {
    if (failOnLoad) {
      throw Exception('database unavailable');
    }
    return List<Puzzle>.unmodifiable(puzzles);
  }

  @override
  Future<int> insert(Puzzle puzzle) async {
    inserted.add(puzzle);
    puzzles.add(puzzle);
    return puzzles.length;
  }

  @override
  Future<int> update(Puzzle puzzle) async {
    updated.add(puzzle);
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    puzzles.removeWhere((puzzle) => puzzle.id == id);
    return 1;
  }
}

class FakeAttemptRepository extends AttemptRepository {
  FakeAttemptRepository([List<Attempt>? attempts])
    : attempts = List<Attempt>.from(attempts ?? const <Attempt>[]);

  final List<Attempt> attempts;

  @override
  Future<List<Attempt>> findAll() async =>
      List<Attempt>.unmodifiable(attempts);
}

Attempt buildAttempt({required int id, int puzzleId = 1}) {
  return Attempt(
    id: id,
    puzzleId: puzzleId,
    status: Attempt.statusSolved,
    elapsedSeconds: 30,
    startedAt: DateTime.utc(2026, 3, id),
  );
}

Puzzle buildPuzzle({
  required int id,
  required String answer,
  int difficulty = 2,
  String category = 'Technology',
}) {
  final now = DateTime.utc(2026, 3, id);

  return Puzzle(
    id: id,
    answer: answer,
    clue: 'Clue for $answer',
    category: category,
    difficulty: difficulty,
    createdAt: now,
    updatedAt: now,
  );
}

Widget wrapShell(
  FakePuzzleRepository repository, {
  FakeAttemptRepository? attempts,
}) {
  return MaterialApp(
    home: HomeShell(
      puzzleRepository: repository,
      attemptRepository: attempts ?? FakeAttemptRepository(),
    ),
  );
}

void main() {
  group('catalog', () {
    testWidgets('starts on the catalog and shows the empty state', (
      tester,
    ) async {
      await tester.pumpWidget(wrapShell(FakePuzzleRepository()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
      expect(find.text('No puzzles yet.'), findsOneWidget);
      expect(find.text('0 puzzles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists stored puzzles with a count', (tester) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER', difficulty: 1),
        buildPuzzle(id: 2, answer: 'HARVEST', difficulty: 2),
        buildPuzzle(id: 3, answer: 'LABYRINTH', difficulty: 3),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      expect(find.text('3 puzzles'), findsOneWidget);
      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(find.text('Clue for HARVEST'), findsOneWidget);
      expect(find.text('Clue for LABYRINTH'), findsOneWidget);
      expect(find.text('No puzzles yet.'), findsNothing);
    });

    testWidgets('does not reveal answers on the cards', (tester) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER'),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(find.text('FLUTTER'), findsNothing);
    });

    testWidgets('difficulty filter narrows the list', (tester) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER', difficulty: 1),
        buildPuzzle(id: 2, answer: 'HARVEST', difficulty: 2),
        buildPuzzle(id: 3, answer: 'LABYRINTH', difficulty: 3),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Hard'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 puzzles'), findsOneWidget);
      expect(find.text('Clue for LABYRINTH'), findsOneWidget);
      expect(find.text('Clue for FLUTTER'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      expect(find.text('3 puzzles'), findsOneWidget);
      expect(find.text('Clue for FLUTTER'), findsOneWidget);
    });

    testWidgets('empty filter result keeps its own message', (tester) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER', difficulty: 1),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Hard'));
      await tester.pumpAndSettle();

      expect(find.text('No puzzles at this difficulty.'), findsOneWidget);
      expect(find.text('No puzzles yet.'), findsNothing);
    });

    testWidgets('shows an error with a retry action when loading fails', (
      tester,
    ) async {
      final repository = FakePuzzleRepository()..failOnLoad = true;

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load puzzles.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

      repository.failOnLoad = false;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load puzzles.'), findsNothing);
      expect(find.text('No puzzles yet.'), findsOneWidget);
    });
  });

  group('deletion', () {
    testWidgets('cancelling the dialog keeps the puzzle', (tester) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER'),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete puzzle?'), findsOneWidget);
      expect(
        find.textContaining('also deletes its attempt history'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Clue for FLUTTER'), findsOneWidget);
      expect(repository.puzzles, hasLength(1));
    });

    testWidgets('confirming the dialog removes the puzzle and refreshes', (
      tester,
    ) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER'),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.puzzles, isEmpty);
      expect(find.text('Clue for FLUTTER'), findsNothing);
      expect(find.text('No puzzles yet.'), findsOneWidget);
      expect(find.text('Puzzle deleted.'), findsOneWidget);
    });
  });

  group('editor', () {
    testWidgets('save stays disabled until every field is valid', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: EditorScreen(repository: FakePuzzleRepository())),
      );
      await tester.pumpAndSettle();

      FilledButton saveButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );

      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'AAA');
      await tester.pumpAndSettle();
      expect(find.text('Use 4 to 12 letters.'), findsOneWidget);
      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'AAAA');
      await tester.pumpAndSettle();
      expect(find.text('Use more than one distinct letter.'), findsOneWidget);
      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'flutter');
      await tester.enterText(find.byType(TextField).at(1), 'A UI toolkit');
      await tester.pumpAndSettle();
      expect(saveButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(2), 'Technology');
      await tester.pumpAndSettle();
      expect(saveButton().onPressed, isNotNull);
    });

    testWidgets('creating a puzzle stores it upper-cased and refreshes', (
      tester,
    ) async {
      final repository = FakePuzzleRepository();

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Puzzle'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Create Puzzle'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'flutter');
      await tester.enterText(find.byType(TextField).at(1), 'A UI toolkit');
      await tester.enterText(find.byType(TextField).at(2), 'Technology');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.inserted, hasLength(1));
      expect(repository.inserted.single.answer, 'FLUTTER');
      expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
      expect(find.text('A UI toolkit'), findsOneWidget);
      expect(find.text('1 puzzle'), findsOneWidget);
    });

    testWidgets('the edit action opens the editor prefilled', (tester) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER', difficulty: 3),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Edit Puzzle'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'FLUTTER'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Clue for FLUTTER'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.updated, hasLength(1));
      expect(repository.updated.single.id, 1);
      expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
    });
  });

  group('play navigation', () {
    testWidgets('tapping a puzzle opens the play screen, not the editor', (
      tester,
    ) async {
      final repository = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER'),
      ]);

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clue for FLUTTER'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Play Puzzle'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Edit Puzzle'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    testWidgets('bottom tabs switch between the three primary screens', (
      tester,
    ) async {
      await tester.pumpWidget(wrapShell(FakePuzzleRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'History & Insights'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();
      expect(find.text('App preferences will appear here.'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Catalog'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('returning to History reloads the attempts', (tester) async {
      final puzzles = FakePuzzleRepository([
        buildPuzzle(id: 1, answer: 'FLUTTER'),
      ]);
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(wrapShell(puzzles, attempts: attempts));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
      await tester.pumpAndSettle();

      expect(
        find.text('No attempts yet. Play a puzzle to start your history.'),
        findsOneWidget,
      );

      attempts.attempts.add(buildAttempt(id: 1));

      await tester.tap(find.widgetWithText(NavigationDestination, 'Catalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
      await tester.pumpAndSettle();

      expect(find.text('Technology · Solved'), findsOneWidget);
      expect(
        find.text('No attempts yet. Play a puzzle to start your history.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('editor closes without saving', (tester) async {
      final repository = FakePuzzleRepository();

      await tester.pumpWidget(wrapShell(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Puzzle'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Create Puzzle'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
      expect(repository.inserted, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
