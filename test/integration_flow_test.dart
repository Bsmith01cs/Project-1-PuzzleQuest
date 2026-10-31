import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:puzzle_quest/hints/hint_coach.dart';
import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/repositories/attempt_repository.dart';
import 'package:puzzle_quest/repositories/puzzle_repository.dart';
import 'package:puzzle_quest/screens/home_shell.dart';
import 'package:puzzle_quest/screens/play_screen.dart' show formatElapsed;
import 'package:puzzle_quest/settings/settings_controller.dart';

/// Stands in for the SQLite file across a whole flow: the repositories below
/// read and write it, so a puzzle created on the catalog is the same row the
/// gameplay and history screens later see. Cascade deletion is mirrored the
/// way the schema declares it.
class FakeStore {
  final List<Puzzle> puzzles = [];
  final List<Attempt> attempts = [];
  int _nextPuzzleId = 1;
  int _nextAttemptId = 1;

  int addPuzzle(Puzzle puzzle) {
    final id = _nextPuzzleId++;
    puzzles.add(_copyPuzzle(puzzle, id));
    return id;
  }

  void replacePuzzle(Puzzle puzzle) {
    final index = puzzles.indexWhere((stored) => stored.id == puzzle.id);
    if (index >= 0) {
      puzzles[index] = puzzle;
    }
  }

  void removePuzzle(int id) {
    puzzles.removeWhere((puzzle) => puzzle.id == id);
    // ON DELETE CASCADE on attempts.puzzle_id.
    attempts.removeWhere((attempt) => attempt.puzzleId == id);
  }

  int addAttempt(Attempt attempt) {
    final id = _nextAttemptId++;
    attempts.add(_copyAttempt(attempt, id));
    return id;
  }

  void replaceAttempt(Attempt attempt) {
    final index = attempts.indexWhere((stored) => stored.id == attempt.id);
    if (index >= 0) {
      attempts[index] = attempt;
    }
  }

  Attempt byId(int id) => attempts.firstWhere((attempt) => attempt.id == id);

  static Puzzle _copyPuzzle(Puzzle puzzle, int id) {
    return Puzzle(
      id: id,
      answer: puzzle.answer,
      clue: puzzle.clue,
      category: puzzle.category,
      difficulty: puzzle.difficulty,
      createdAt: puzzle.createdAt,
      updatedAt: puzzle.updatedAt,
    );
  }

  static Attempt _copyAttempt(Attempt attempt, int id) {
    return Attempt(
      id: id,
      puzzleId: attempt.puzzleId,
      status: attempt.status,
      wrongGuesses: attempt.wrongGuesses,
      hintsUsed: attempt.hintsUsed,
      hintKinds: attempt.hintKinds,
      elapsedSeconds: attempt.elapsedSeconds,
      lastGuess: attempt.lastGuess,
      userNote: attempt.userNote,
      startedAt: attempt.startedAt,
      finishedAt: attempt.finishedAt,
    );
  }
}

class StorePuzzleRepository extends PuzzleRepository {
  StorePuzzleRepository(this.store);

  final FakeStore store;

  @override
  Future<void> seedStarterPuzzlesOnce() async {}

  @override
  Future<List<Puzzle>> findAll() async => List<Puzzle>.of(store.puzzles);

  @override
  Future<int> insert(Puzzle puzzle) async => store.addPuzzle(puzzle);

  @override
  Future<int> update(Puzzle puzzle) async {
    store.replacePuzzle(puzzle);
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    store.removePuzzle(id);
    return 1;
  }
}

class StoreAttemptRepository extends AttemptRepository {
  StoreAttemptRepository(this.store);

  final FakeStore store;

  @override
  Future<List<Attempt>> findAll() async =>
      List<Attempt>.of(store.attempts)
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<Attempt?> findLatestUnfinished(int puzzleId) async {
    final open =
        store.attempts
            .where(
              (attempt) =>
                  attempt.puzzleId == puzzleId &&
                  attempt.finishedAt == null &&
                  attempt.status != Attempt.statusSolved,
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return open.isEmpty ? null : open.first;
  }

  @override
  Future<int> insert(Attempt attempt) async => store.addAttempt(attempt);

  @override
  Future<int> update(Attempt attempt) async {
    store.replaceAttempt(attempt);
    return 1;
  }

  @override
  Future<int> updateNote(int id, String? note) async {
    final stored = store.byId(id);
    store.replaceAttempt(
      Attempt(
        id: stored.id,
        puzzleId: stored.puzzleId,
        status: stored.status,
        wrongGuesses: stored.wrongGuesses,
        hintsUsed: stored.hintsUsed,
        hintKinds: stored.hintKinds,
        elapsedSeconds: stored.elapsedSeconds,
        lastGuess: stored.lastGuess,
        userNote: note,
        startedAt: stored.startedAt,
        finishedAt: stored.finishedAt,
      ),
    );
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    store.attempts.removeWhere((attempt) => attempt.id == id);
    return 1;
  }
}

Future<SettingsController> buildSettings({int threshold = 30}) async {
  SharedPreferences.setMockInitialValues({
    SettingsController.hintThresholdKey: threshold,
  });

  final controller = SettingsController();
  await controller.load();
  return controller;
}

Widget wrapShell(FakeStore store, SettingsController settings) {
  return MaterialApp(
    home: HomeShell(
      puzzleRepository: StorePuzzleRepository(store),
      attemptRepository: StoreAttemptRepository(store),
      settings: settings,
    ),
  );
}

/// Taps a control after bringing it into view: the Play screen is taller than
/// the test viewport once hints are on it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// Lets the serialized repository writes drain between steps.
Future<void> flushWrites(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

Future<void> createPuzzle(
  WidgetTester tester, {
  required String answer,
  required String clue,
  required String category,
  required String difficulty,
}) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Create Puzzle'));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'Answer'), answer);
  await tester.enterText(find.widgetWithText(TextField, 'Clue'), clue);
  await tester.enterText(find.widgetWithText(TextField, 'Category'), category);
  await tester.pump();

  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(SegmentedButton<int>),
      matching: find.text(difficulty),
    ),
  );
  await tester.pumpAndSettle();

  await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a puzzle is created, edited, filtered and deleted', (
    tester,
  ) async {
    final store = FakeStore();
    final settings = await buildSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(wrapShell(store, settings));
    await tester.pumpAndSettle();

    expect(find.text('No puzzles yet.'), findsOneWidget);

    await createPuzzle(
      tester,
      answer: 'flutter',
      clue: 'Toolkit used to build this app',
      category: 'Technology',
      difficulty: 'Medium',
    );

    expect(find.text('1 puzzle'), findsOneWidget);
    expect(store.puzzles.single.answer, 'FLUTTER');
    expect(find.text('Technology · Medium'), findsOneWidget);

    await createPuzzle(
      tester,
      answer: 'kernel',
      clue: 'Core of an operating system',
      category: 'Systems',
      difficulty: 'Hard',
    );

    expect(find.text('2 puzzles'), findsOneWidget);

    // Edit the first puzzle's clue.
    await tapVisible(
      tester,
      find.byTooltip('Edit Toolkit used to build this app'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Clue'),
      'The toolkit behind PuzzleQuest',
    );
    await tester.pump();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('The toolkit behind PuzzleQuest'), findsOneWidget);
    expect(find.text('Toolkit used to build this app'), findsNothing);

    // Filter by difficulty.
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Hard'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 puzzles'), findsOneWidget);
    expect(find.text('Core of an operating system'), findsOneWidget);
    expect(find.text('The toolkit behind PuzzleQuest'), findsNothing);

    await tapVisible(tester, find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();

    // Delete the second puzzle.
    await tapVisible(
      tester,
      find.byTooltip('Delete Core of an operating system'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete puzzle?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('1 puzzle'), findsOneWidget);
    expect(store.puzzles.single.answer, 'FLUTTER');
  });

  testWidgets('gameplay runs, pauses, resumes, resets and solves', (
    tester,
  ) async {
    final store = FakeStore();
    final settings = await buildSettings();
    addTearDown(settings.dispose);
    store.addPuzzle(
      Puzzle(
        answer: 'FLUTTER',
        clue: 'Toolkit used to build this app',
        category: 'Technology',
        difficulty: 2,
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
    );

    await tester.pumpWidget(wrapShell(store, settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toolkit used to build this app'));
    await tester.pumpAndSettle();

    expect(find.text('Play Puzzle'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
    await flushWrites(tester);

    expect(store.attempts, hasLength(1));
    expect(store.attempts.single.status, Attempt.statusInProgress);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Time 00:02'), findsOneWidget);

    // A wrong guess is recorded.
    await tester.enterText(
      find.widgetWithText(TextField, 'Your guess'),
      'WRONG',
    );
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
    await flushWrites(tester);

    expect(find.text('Not quite. Try again.'), findsOneWidget);
    expect(store.attempts.single.wrongGuesses, 1);
    expect(store.attempts.single.lastGuess, 'WRONG');

    // Pause stops the clock.
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Pause'));
    await flushWrites(tester);

    expect(find.text('Paused'), findsOneWidget);
    expect(store.attempts.single.status, Attempt.statusPaused);
    final pausedAt = store.attempts.single.elapsedSeconds;

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('Time ${formatElapsed(pausedAt)}'),
      findsOneWidget,
    );

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
    await flushWrites(tester);

    expect(store.attempts.single.status, Attempt.statusInProgress);

    // Reset returns to the start without opening a second row.
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
    await flushWrites(tester);

    expect(store.attempts, hasLength(1));
    expect(store.attempts.single.wrongGuesses, 0);
    expect(store.attempts.single.elapsedSeconds, 0);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
    await flushWrites(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Your guess'),
      'flutter',
    );
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
    await flushWrites(tester);

    expect(find.text('Solved!'), findsOneWidget);
    expect(store.attempts, hasLength(1));
    expect(store.attempts.single.status, Attempt.statusSolved);
    expect(store.attempts.single.finishedAt, isNotNull);
  });

  testWidgets('an unfinished attempt and its hints survive a restart', (
    tester,
  ) async {
    final store = FakeStore();
    final settings = await buildSettings();
    addTearDown(settings.dispose);
    final puzzleId = store.addPuzzle(
      Puzzle(
        answer: 'FLUTTER',
        clue: 'Toolkit used to build this app',
        category: 'Technology',
        difficulty: 2,
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
    );

    await tester.pumpWidget(wrapShell(store, settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toolkit used to build this app'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
    await flushWrites(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Your guess'),
      'WRONG',
    );
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
    await flushWrites(tester);

    // Earns and accepts the clue.
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
    await flushWrites(tester);

    final attemptId = store.attempts.single.id!;
    expect(store.byId(attemptId).hintsUsed, 1);
    expect(store.byId(attemptId).hintKinds, 'clue');

    // Leaving the screen is the restart: the next open reads the row back.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toolkit used to build this app'));
    await tester.pumpAndSettle();

    expect(find.text('Resumed your unfinished attempt.'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.textContaining('Wrong guesses 1'), findsOneWidget);
    expect(find.text('Hints used 1'), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
    await flushWrites(tester);

    // The hint it already paid for is not offered a second time.
    expect(find.text('Hint available'), findsNothing);
    expect(store.attempts, hasLength(1));
    expect(store.byId(attemptId).hintsUsed, 1);
    expect(store.byId(attemptId).hintKinds, 'clue');
    expect(store.byId(attemptId).puzzleId, puzzleId);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'Pause'));
    await flushWrites(tester);
  });

  testWidgets('history reviews, annotates and deletes an attempt', (
    tester,
  ) async {
    final store = FakeStore();
    final settings = await buildSettings();
    addTearDown(settings.dispose);
    store.addPuzzle(
      Puzzle(
        answer: 'FLUTTER',
        clue: 'Toolkit used to build this app',
        category: 'Technology',
        difficulty: 2,
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
    );
    store.addAttempt(
      Attempt(
        puzzleId: 1,
        status: Attempt.statusSolved,
        wrongGuesses: 2,
        hintsUsed: 1,
        hintKinds: encodeHintKinds({HintKind.clue}),
        elapsedSeconds: 95,
        startedAt: DateTime.utc(2026, 3, 1, 10),
        finishedAt: DateTime.utc(2026, 3, 1, 10, 2),
      ),
    );

    await tester.pumpWidget(wrapShell(store, settings));
    await tester.pumpAndSettle();
    await openTab(tester, 'History');

    expect(find.text('Toolkit used to build this app'), findsOneWidget);
    expect(find.textContaining('01:35'), findsOneWidget);
    expect(find.textContaining('100%'), findsOneWidget);

    // Add a note.
    await tapVisible(tester, find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Note'),
      'Hint made the difference',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Note saved.'), findsOneWidget);
    expect(store.attempts.single.userNote, 'Hint made the difference');
    expect(find.text('Hint made the difference'), findsOneWidget);

    // Delete it.
    await tapVisible(tester, find.byTooltip('Delete attempt'));
    await tester.pumpAndSettle();
    expect(find.text('Delete attempt?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.attempts, isEmpty);
    expect(
      find.text('No attempts yet. Play a puzzle to start your history.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a puzzle cascades to its attempts in history', (
    tester,
  ) async {
    final store = FakeStore();
    final settings = await buildSettings();
    addTearDown(settings.dispose);
    store.addPuzzle(
      Puzzle(
        answer: 'FLUTTER',
        clue: 'Toolkit used to build this app',
        category: 'Technology',
        difficulty: 2,
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
    );
    store.addAttempt(
      Attempt(
        puzzleId: 1,
        status: Attempt.statusSolved,
        elapsedSeconds: 40,
        startedAt: DateTime.utc(2026, 3, 1, 10),
        finishedAt: DateTime.utc(2026, 3, 1, 10, 1),
      ),
    );

    await tester.pumpWidget(wrapShell(store, settings));
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byTooltip('Delete Toolkit used to build this app'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.attempts, isEmpty);

    await openTab(tester, 'History');
    expect(
      find.text('No attempts yet. Play a puzzle to start your history.'),
      findsOneWidget,
    );
  });

  testWidgets('settings persist and reach the rest of the app', (tester) async {
    final store = FakeStore();
    final settings = await buildSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(wrapShell(store, settings));
    await tester.pumpAndSettle();
    await openTab(tester, 'Settings');

    await tester.tap(find.widgetWithText(SwitchListTile, 'Dark theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Reduced motion'));
    await tester.pumpAndSettle();

    expect(settings.settings.darkTheme, isTrue);
    expect(settings.settings.reducedMotion, isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(SettingsController.darkThemeKey), isTrue);
    expect(preferences.getBool(SettingsController.reducedMotionKey), isTrue);

    // The saved threshold is what the hint rules read.
    expect(settings.settings.hintThresholdSeconds, 30);
    final reloaded = SettingsController();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.settings.darkTheme, isTrue);
    expect(reloaded.settings.hintThresholdSeconds, 30);
  });
}
