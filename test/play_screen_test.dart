import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/repositories/attempt_repository.dart';
import 'package:puzzle_quest/screens/play_screen.dart';

class FakeAttemptRepository extends AttemptRepository {
  FakeAttemptRepository({
    this.existing,
    this.failReads = false,
    this.failWrites = false,
  });

  Attempt? existing;
  bool failReads;
  bool failWrites;

  final List<Attempt> inserted = [];
  final List<Attempt> updated = [];

  int _nextId = 10;

  Attempt get lastWrite => updated.isNotEmpty ? updated.last : inserted.last;

  @override
  Future<Attempt?> findLatestUnfinished(int puzzleId) async {
    if (failReads) {
      throw Exception('read failed');
    }
    return existing;
  }

  @override
  Future<int> insert(Attempt attempt) async {
    if (failWrites) {
      throw Exception('write failed');
    }
    inserted.add(attempt);
    return _nextId++;
  }

  @override
  Future<int> update(Attempt attempt) async {
    if (failWrites) {
      throw Exception('write failed');
    }
    updated.add(attempt);
    return 1;
  }
}

Puzzle buildPuzzle({String answer = 'FLUTTER'}) {
  final now = DateTime.utc(2026, 3, 1);

  return Puzzle(
    id: 1,
    answer: answer,
    clue: 'Toolkit used to build this app',
    category: 'Technology',
    difficulty: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Attempt buildAttempt({
  int id = 7,
  int wrongGuesses = 2,
  int elapsedSeconds = 45,
  String? lastGuess = 'FLUTTRE',
  String status = Attempt.statusPaused,
}) {
  return Attempt(
    id: id,
    puzzleId: 1,
    status: status,
    wrongGuesses: wrongGuesses,
    elapsedSeconds: elapsedSeconds,
    lastGuess: lastGuess,
    startedAt: DateTime.utc(2026, 3, 1, 10),
  );
}

Widget wrapPlay(
  Puzzle? puzzle, {
  Random? random,
  AttemptRepository? attempts,
}) {
  return MaterialApp(
    home: PlayScreen(
      puzzle: puzzle,
      random: random,
      attempts: attempts ?? FakeAttemptRepository(),
    ),
  );
}

// Lets the queued repository writes run without settling a live game timer.
Future<void> flushWrites(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

// The State class is private, so the lifecycle callback is invoked the way the
// framework would invoke it on the registered observer.
void sendLifecycleState(WidgetTester tester, AppLifecycleState state) {
  final dynamic playState = tester.state(find.byType(PlayScreen));
  playState.didChangeAppLifecycleState(state);
}

void main() {
  group('scrambleWord', () {
    test('keeps exactly the same letters', () {
      final scrambled = scrambleWord('FLUTTER', random: Random(1));

      expect(scrambled.length, 7);
      expect(scrambled.split('')..sort(), 'FLUTTER'.split('')..sort());
    });

    test('does not return the original order', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(scrambleWord('HARVEST', random: Random(seed)), isNot('HARVEST'));
      }
    });

    test('returns a single-letter word unchanged', () {
      expect(scrambleWord('A', random: Random(1)), 'A');
    });

    test('returns a repeated-letter word unchanged rather than looping', () {
      expect(scrambleWord('AAAA', random: Random(1)), 'AAAA');
    });

    test('is deterministic for a given seed', () {
      expect(
        scrambleWord('LABYRINTH', random: Random(42)),
        scrambleWord('LABYRINTH', random: Random(42)),
      );
    });
  });

  group('formatElapsed', () {
    test('pads minutes and seconds', () {
      expect(formatElapsed(0), '00:00');
      expect(formatElapsed(7), '00:07');
      expect(formatElapsed(65), '01:05');
      expect(formatElapsed(600), '10:00');
    });
  });

  group('play screen', () {
    testWidgets('without a puzzle it keeps the placeholder', (tester) async {
      await tester.pumpWidget(wrapPlay(null));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Play Puzzle'), findsOneWidget);
      expect(find.text('Puzzle gameplay will appear here.'), findsOneWidget);
    });

    testWidgets('shows the clue and the scrambled letters', (tester) async {
      final expected = scrambleWord('FLUTTER', random: Random(7));

      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      expect(find.text('Toolkit used to build this app'), findsOneWidget);
      expect(find.text(expected.split('').join(' ')), findsOneWidget);
      expect(find.text('FLUTTER'), findsNothing);
    });

    testWidgets('guessing is locked until the game starts', (tester) async {
      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check'))
            .onPressed,
        isNull,
      );
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    });

    testWidgets('a correct guess solves the puzzle, ignoring case', (
      tester,
    ) async {
      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '  flutter  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pump();

      expect(find.text('Solved!'), findsOneWidget);
      expect(find.textContaining('The answer was FLUTTER'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Play again'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a wrong guess reports feedback and counts the miss', (
      tester,
    ) async {
      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pump();

      expect(find.text('Not quite. Try again.'), findsOneWidget);
      expect(find.textContaining('Wrong guesses 1'), findsOneWidget);
      expect(find.text('Solved!'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pump();
    });

    testWidgets('the timer advances while running', (tester) async {
      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Time 00:00'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Time 00:03'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pump();
    });

    testWidgets('pause hides the letters and resume brings them back', (
      tester,
    ) async {
      final expected = scrambleWord('FLUTTER', random: Random(7));

      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await tester.pump();

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text(expected.split('').join(' ')), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
      await tester.pump();

      expect(find.text('Paused'), findsNothing);
      expect(find.text(expected.split('').join(' ')), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pump();
    });

    testWidgets('pause does not advance the timer', (tester) async {
      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('Time 00:01'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pump();
    });

    testWidgets('reset clears the timer, misses and guess', (tester) async {
      await tester.pumpWidget(wrapPlay(buildPuzzle(), random: Random(7)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await tester.pump();

      expect(find.textContaining('Time 00:00'), findsOneWidget);
      expect(find.textContaining('Wrong guesses 0'), findsOneWidget);
      expect(find.text('Not quite. Try again.'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('attempt persistence', () {
    testWidgets('starting a game records one in-progress attempt', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      expect(attempts.inserted, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      expect(attempts.inserted, hasLength(1));
      final attempt = attempts.inserted.single;
      expect(attempt.id, isNull);
      expect(attempt.puzzleId, 1);
      expect(attempt.status, Attempt.statusInProgress);
      expect(attempt.wrongGuesses, 0);
      expect(attempt.hintsUsed, 0);
      expect(attempt.elapsedSeconds, 0);
      expect(attempt.lastGuess, isNull);
      expect(attempt.finishedAt, isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });

    testWidgets('a wrong guess updates the attempt instead of adding one', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'wrongly');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      expect(attempts.inserted, hasLength(1));
      expect(attempts.updated, hasLength(1));

      final saved = attempts.updated.single;
      expect(saved.id, 10);
      expect(saved.status, Attempt.statusInProgress);
      expect(saved.wrongGuesses, 1);
      expect(saved.lastGuess, 'wrongly');
      expect(saved.elapsedSeconds, 2);
      expect(saved.finishedAt, isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });

    testWidgets('pausing and resuming persist the matching status', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await flushWrites(tester);
      expect(attempts.lastWrite.status, Attempt.statusPaused);

      await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);
      expect(attempts.lastWrite.status, Attempt.statusInProgress);

      expect(attempts.inserted, hasLength(1));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });

    testWidgets('solving saves a finished attempt once', (tester) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      expect(attempts.inserted, hasLength(1));
      expect(attempts.updated, hasLength(1));

      final saved = attempts.updated.single;
      expect(saved.id, 10);
      expect(saved.status, Attempt.statusSolved);
      expect(saved.elapsedSeconds, 3);
      expect(saved.lastGuess, 'flutter');
      expect(saved.finishedAt, isNotNull);
    });

    testWidgets('repeated controls never create a second attempt row', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await flushWrites(tester);

      expect(attempts.inserted, hasLength(1));
      expect(attempts.updated, hasLength(3));
      expect(
        attempts.updated.every((attempt) => attempt.id == 10),
        isTrue,
        reason: 'every update targets the row created by Start',
      );
    });

    testWidgets('reset reuses the unfinished row and zeroes it', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);

      expect(attempts.inserted, hasLength(1));
      final saved = attempts.updated.last;
      expect(saved.id, 10);
      expect(saved.wrongGuesses, 0);
      expect(saved.elapsedSeconds, 0);
      expect(saved.lastGuess, isNull);
      expect(saved.finishedAt, isNull);
    });

    testWidgets('playing again leaves the solved row alone', (tester) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      await tester.enterText(find.byType(TextField), 'FLUTTER');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Play again'));
      await flushWrites(tester);

      expect(attempts.updated, hasLength(1));
      expect(attempts.updated.single.status, Attempt.statusSolved);
      expect(attempts.inserted, hasLength(1));

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      expect(attempts.inserted, hasLength(2));
      expect(attempts.inserted.last.status, Attempt.statusInProgress);
      expect(attempts.inserted.last.elapsedSeconds, 0);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });

    testWidgets('a database read failure still lets the player play', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(failReads: true);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Saved progress is unavailable. You can keep playing.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    });

    testWidgets('a database write failure is reported without crashing', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(failWrites: true);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Saved progress is unavailable. You can keep playing.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });
  });

  group('restart recovery', () {
    testWidgets('an unfinished attempt comes back paused with its progress', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(existing: buildAttempt());

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('Time 00:45'), findsOneWidget);
      expect(find.textContaining('Wrong guesses 2'), findsOneWidget);
      expect(find.text('Resumed your unfinished attempt.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'FLUTTRE',
      );
      expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    });

    testWidgets('a restored attempt does not count time while paused', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(existing: buildAttempt());

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('Time 00:45'), findsOneWidget);
      expect(attempts.inserted, isEmpty);
      expect(attempts.updated, isEmpty);
    });

    testWidgets('resuming a restored attempt updates that same row', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(existing: buildAttempt());

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(attempts.inserted, isEmpty);
      expect(attempts.updated, hasLength(1));

      final saved = attempts.updated.single;
      expect(saved.id, 7);
      expect(saved.status, Attempt.statusInProgress);
      expect(saved.elapsedSeconds, 45);
      expect(saved.wrongGuesses, 2);
      expect(saved.startedAt, DateTime.utc(2026, 3, 1, 10));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });

    testWidgets('an untouched saved attempt reopens ready to start', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildAttempt(
          wrongGuesses: 0,
          elapsedSeconds: 0,
          lastGuess: null,
          status: Attempt.statusInProgress,
        ),
      );

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
      expect(find.text('Resumed your unfinished attempt.'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      expect(attempts.inserted, isEmpty);
      expect(attempts.updated.single.id, 7);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
    });
  });

  group('app lifecycle', () {
    testWidgets('leaving the app pauses the game and saves it', (tester) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      sendLifecycleState(tester, AppLifecycleState.paused);
      await flushWrites(tester);

      expect(find.text('Paused'), findsOneWidget);
      expect(attempts.lastWrite.status, Attempt.statusPaused);
      expect(attempts.lastWrite.elapsedSeconds, 2);

      await tester.pump(const Duration(seconds: 10));

      expect(find.textContaining('Time 00:02'), findsOneWidget);
    });

    testWidgets('returning to the app leaves the game paused', (tester) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      sendLifecycleState(tester, AppLifecycleState.inactive);
      await flushWrites(tester);
      sendLifecycleState(tester, AppLifecycleState.resumed);
      await flushWrites(tester);

      expect(find.text('Paused'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    });

    testWidgets('lifecycle changes while paused write nothing extra', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), random: Random(7), attempts: attempts),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await flushWrites(tester);

      final writesSoFar = attempts.updated.length;

      sendLifecycleState(tester, AppLifecycleState.paused);
      sendLifecycleState(tester, AppLifecycleState.resumed);
      await flushWrites(tester);

      expect(attempts.updated, hasLength(writesSoFar));
    });
  });
}
