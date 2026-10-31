import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:puzzle_quest/hints/hint_coach.dart';
import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/repositories/attempt_repository.dart';
import 'package:puzzle_quest/screens/play_screen.dart';
import 'package:puzzle_quest/settings/settings_controller.dart';

class FakeAttemptRepository extends AttemptRepository {
  FakeAttemptRepository({this.existing});

  final Attempt? existing;
  final List<Attempt> inserted = [];
  final List<Attempt> updated = [];

  Attempt get lastWrite => updated.isNotEmpty ? updated.last : inserted.last;

  @override
  Future<Attempt?> findLatestUnfinished(int puzzleId) async => existing;

  @override
  Future<int> insert(Attempt attempt) async {
    inserted.add(attempt);
    return 10;
  }

  @override
  Future<int> update(Attempt attempt) async {
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

/// A paused attempt waiting to be restored. [hintKinds] left null stands for
/// a row written before the column existed, which stores a count alone.
Attempt buildSavedAttempt({
  int hintsUsed = 1,
  int wrongGuesses = 1,
  int elapsedSeconds = 10,
  String? hintKinds,
  String? userNote,
}) {
  return Attempt(
    id: 7,
    puzzleId: 1,
    status: Attempt.statusPaused,
    wrongGuesses: wrongGuesses,
    hintsUsed: hintsUsed,
    hintKinds: hintKinds,
    elapsedSeconds: elapsedSeconds,
    userNote: userNote,
    startedAt: DateTime.utc(2026, 3, 1, 10),
  );
}

Future<SettingsController> controllerWithThreshold(int seconds) async {
  SharedPreferences.setMockInitialValues({
    SettingsController.hintThresholdKey: seconds,
  });

  final controller = SettingsController();
  await controller.load();
  return controller;
}

Widget wrapPlay(
  Puzzle puzzle, {
  required AttemptRepository attempts,
  required SettingsController settings,
}) {
  return MaterialApp(
    home: PlayScreen(
      puzzle: puzzle,
      random: Random(7),
      attempts: attempts,
      settings: settings,
    ),
  );
}

Future<void> flushWrites(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

// Scrolls a control into view first: with hint cards on screen the Play
// layout can be taller than the test viewport.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  // Case 1: normal gameplay.
  group('normal gameplay', () {
    test('one wrong guess before the threshold earns the clue', () {
      final suggestion = suggestHint(
        wrongGuesses: 1,
        elapsedSeconds: 10,
        thresholdSeconds: 60,
        answerLength: 7,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.kind, HintKind.clue);
      expect(suggestion.explanation, contains('1 wrong guess'));
    });

    test('reaching the threshold with no wrong guess earns the clue', () {
      final suggestion = suggestHint(
        wrongGuesses: 0,
        elapsedSeconds: 60,
        thresholdSeconds: 60,
        answerLength: 7,
      );

      expect(suggestion!.kind, HintKind.clue);
      expect(suggestion.explanation, contains('passed 60 seconds'));
    });

    test('two wrong guesses and the threshold earn the first letter', () {
      final suggestion = suggestHint(
        wrongGuesses: 2,
        elapsedSeconds: 61,
        thresholdSeconds: 60,
        answerLength: 7,
      );

      expect(suggestion!.kind, HintKind.firstLetter);
      expect(suggestion.explanation, contains('longer than four letters'));
    });

    test('two wrong guesses before the threshold stay on the clue', () {
      final suggestion = suggestHint(
        wrongGuesses: 2,
        elapsedSeconds: 59,
        thresholdSeconds: 60,
        answerLength: 7,
      );

      expect(suggestion!.kind, HintKind.clue);
    });

    test('the first letter hint never exposes the whole answer', () {
      final text = hintText(
        kind: HintKind.firstLetter,
        answer: 'FLUTTER',
        clue: 'Toolkit used to build this app',
        clueVisible: true,
      );

      expect(text, 'The answer starts with "F".');
      expect(text, isNot(contains('FLUTTER')));
    });

    test('a clue hint points at the visible clue instead of repeating it', () {
      expect(
        hintText(
          kind: HintKind.clue,
          answer: 'FLUTTER',
          clue: 'Toolkit used to build this app',
          clueVisible: true,
        ),
        'Read the clue above once more.',
      );

      expect(
        hintText(
          kind: HintKind.clue,
          answer: 'FLUTTER',
          clue: 'Toolkit used to build this app',
          clueVisible: false,
        ),
        'Toolkit used to build this app',
      );
    });
  });

  // Case 2: no previous history.
  group('no previous history', () {
    test('a fresh attempt earns no hint', () {
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 0,
          thresholdSeconds: 60,
          answerLength: 7,
        ),
        isNull,
      );
    });

    test('time alone below the threshold earns no hint', () {
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 59,
          thresholdSeconds: 60,
          answerLength: 7,
        ),
        isNull,
      );
    });

    test('the baseline also offers nothing before a wrong guess', () {
      expect(suggestBaselineHint(wrongGuesses: 0), isNull);
    });
  });

  // Case 3: invalid input.
  group('invalid input', () {
    test('negative wrong guesses produce no hint and an explanation', () {
      expect(
        suggestHint(
          wrongGuesses: -3,
          elapsedSeconds: 90,
          thresholdSeconds: 60,
          answerLength: 7,
        ),
        isNull,
      );

      expect(
        validateHintInputs(
          wrongGuesses: -3,
          elapsedSeconds: 90,
          answerLength: 7,
        ),
        'Hints are unavailable: the wrong guess count is invalid.',
      );
    });

    test('a negative elapsed time produces no hint and an explanation', () {
      expect(
        suggestHint(
          wrongGuesses: 2,
          elapsedSeconds: -1,
          thresholdSeconds: 60,
          answerLength: 7,
        ),
        isNull,
      );

      expect(
        validateHintInputs(
          wrongGuesses: 2,
          elapsedSeconds: -1,
          answerLength: 7,
        ),
        'Hints are unavailable: the elapsed time is invalid.',
      );
    });

    test('an invalid answer length produces no hint and an explanation', () {
      for (final length in [0, -4]) {
        expect(
          suggestHint(
            wrongGuesses: 5,
            elapsedSeconds: 300,
            thresholdSeconds: 60,
            answerLength: length,
          ),
          isNull,
          reason: 'answer length $length is not usable',
        );

        expect(
          validateHintInputs(
            wrongGuesses: 5,
            elapsedSeconds: 300,
            answerLength: length,
          ),
          'Hints are unavailable: this puzzle has no answer to hint at.',
        );
      }
    });

    test('sound counters report no problem', () {
      expect(
        validateHintInputs(wrongGuesses: 0, elapsedSeconds: 0, answerLength: 1),
        isNull,
      );
      expect(
        validateHintInputs(
          wrongGuesses: 3,
          elapsedSeconds: 120,
          answerLength: 9,
        ),
        isNull,
      );
    });

    test('a threshold below the range is clamped, not trusted', () {
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 5,
          thresholdSeconds: 0,
          answerLength: 7,
        ),
        isNull,
      );

      final atClamp = suggestHint(
        wrongGuesses: 0,
        elapsedSeconds: minHintThresholdSeconds,
        thresholdSeconds: 0,
        answerLength: 7,
      );

      expect(atClamp!.kind, HintKind.clue);
    });

    test('a threshold above the range is clamped down', () {
      final suggestion = suggestHint(
        wrongGuesses: 2,
        elapsedSeconds: maxHintThresholdSeconds,
        thresholdSeconds: 9999,
        answerLength: 7,
      );

      expect(suggestion!.kind, HintKind.firstLetter);
    });

    test('an empty answer still cannot leak a letter', () {
      expect(
        hintText(
          kind: HintKind.firstLetter,
          answer: '',
          clue: 'Toolkit used to build this app',
          clueVisible: false,
        ),
        'Toolkit used to build this app',
      );
    });

    test('the baseline ignores negative counters', () {
      expect(suggestBaselineHint(wrongGuesses: -2), isNull);
    });
  });

  // Case 4: threshold boundary.
  group('threshold boundary', () {
    test('one second short of the threshold offers nothing', () {
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 59,
          thresholdSeconds: 60,
          answerLength: 7,
        ),
        isNull,
      );
    });

    test('exactly at the threshold offers the clue', () {
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 60,
          thresholdSeconds: 60,
          answerLength: 7,
        )!.kind,
        HintKind.clue,
      );
    });

    test('the first letter waits for the exact threshold', () {
      expect(
        suggestHint(
          wrongGuesses: 2,
          elapsedSeconds: 59,
          thresholdSeconds: 60,
          answerLength: 7,
        )!.kind,
        HintKind.clue,
      );

      expect(
        suggestHint(
          wrongGuesses: 2,
          elapsedSeconds: 60,
          thresholdSeconds: 60,
          answerLength: 7,
        )!.kind,
        HintKind.firstLetter,
      );
    });

    test('the boundary moves with the saved threshold', () {
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 30,
          thresholdSeconds: 30,
          answerLength: 7,
        )!.kind,
        HintKind.clue,
      );

      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 30,
          thresholdSeconds: 120,
          answerLength: 7,
        ),
        isNull,
      );
    });
  });

  // Case 5: four-letter counterexample.
  group('four-letter counterexample', () {
    test('a four-letter answer never gives up its first letter', () {
      final suggestion = suggestHint(
        wrongGuesses: 4,
        elapsedSeconds: 300,
        thresholdSeconds: 60,
        answerLength: 4,
      );

      expect(suggestion!.kind, HintKind.clue);
    });

    test('five letters is the shortest answer that qualifies', () {
      expect(
        suggestHint(
          wrongGuesses: 2,
          elapsedSeconds: 60,
          thresholdSeconds: 60,
          answerLength: 5,
        )!.kind,
        HintKind.firstLetter,
      );
    });
  });

  group('baseline comparison', () {
    test('the baseline offers the clue after one wrong guess', () {
      final suggestion = suggestBaselineHint(wrongGuesses: 1);

      expect(suggestion!.kind, HintKind.clue);
    });

    test('the baseline ignores time and answer length', () {
      expect(suggestBaselineHint(wrongGuesses: 9)!.kind, HintKind.clue);
      expect(suggestBaselineHint(wrongGuesses: 0), isNull);
    });

    test('HintCoach differs from the baseline on a timed-out attempt', () {
      expect(suggestBaselineHint(wrongGuesses: 0), isNull);
      expect(
        suggestHint(
          wrongGuesses: 0,
          elapsedSeconds: 60,
          thresholdSeconds: 60,
          answerLength: 7,
        )!.kind,
        HintKind.clue,
      );
    });

    test('HintCoach escalates where the baseline cannot', () {
      expect(suggestBaselineHint(wrongGuesses: 2)!.kind, HintKind.clue);
      expect(
        suggestHint(
          wrongGuesses: 2,
          elapsedSeconds: 60,
          thresholdSeconds: 60,
          answerLength: 7,
        )!.kind,
        HintKind.firstLetter,
      );
    });
  });

  group('play screen hints', () {
    testWidgets('no hint is offered before the rules are met', (tester) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Hint available'), findsNothing);
      expect(find.text('Hint'), findsNothing);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('a wrong guess offers a hint that is never auto-revealed', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      expect(find.text('Hint available'), findsOneWidget);
      expect(
        find.textContaining('1 wrong guess, so the clue is the hint'),
        findsOneWidget,
      );
      expect(find.text('Read the clue above once more.'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Reveal'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Not now'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('revealing a hint shows it once and records the usage', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      expect(find.text('Read the clue above once more.'), findsOneWidget);
      expect(find.text('Hints used 1'), findsOneWidget);
      expect(find.text('Hint available'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 1);

      // A second wrong guess must not re-offer the same hint.
      await tester.enterText(find.byType(TextField), 'AGAIN');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      expect(find.text('Hint available'), findsNothing);
      expect(find.text('Hints used 1'), findsOneWidget);
      expect(find.text('Read the clue above once more.'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('Not now withdraws the offer without recording a hint', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      await tapVisible(tester, find.widgetWithText(TextButton, 'Not now'));
      await flushWrites(tester);

      expect(find.text('Hint available'), findsNothing);
      expect(find.textContaining('Hints used'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 0);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Hint available'), findsNothing);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('the first letter is offered once the rules escalate', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(30);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      for (final guess in ['WRONGLY', 'MISSING']) {
        await tester.enterText(find.byType(TextField), guess);
        await tester.pump();
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
        await flushWrites(tester);
      }

      await tester.pump(const Duration(seconds: 30));

      expect(find.textContaining('longer than four letters'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      expect(find.text('The answer starts with "F".'), findsOneWidget);
      expect(find.text('FLUTTER'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 1);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('a four-letter answer only ever offers the clue', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(30);

      await tester.pumpWidget(
        wrapPlay(
          buildPuzzle(answer: 'HARP'),
          attempts: attempts,
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      for (final guess in ['WRONG', 'MISS']) {
        await tester.enterText(find.byType(TextField), guess);
        await tester.pump();
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
        await flushWrites(tester);
      }

      await tester.pump(const Duration(seconds: 30));

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      expect(find.text('Read the clue above once more.'), findsOneWidget);
      expect(find.textContaining('starts with'), findsNothing);
      expect(find.text('HARP'), findsNothing);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('reset clears revealed hints and the stored count', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);

      await tester.enterText(find.byType(TextField), 'WRONG');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);

      expect(find.textContaining('Hints used'), findsNothing);
      expect(find.text('Read the clue above once more.'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 0);

      settings.dispose();
    });

    testWidgets('a solved puzzle stops offering hints', (tester) async {
      final attempts = FakeAttemptRepository();
      final settings = await controllerWithThreshold(30);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Start'));
      await flushWrites(tester);
      await tester.pump(const Duration(seconds: 30));

      expect(find.text('Hint available'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Check'));
      await flushWrites(tester);

      expect(find.text('Solved!'), findsOneWidget);
      expect(find.text('Hint available'), findsNothing);

      settings.dispose();
    });
  });

  group('restored hint usage', () {
    testWidgets('a legacy count is shown and not revealed automatically', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(hintsUsed: 1),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hints used 1'), findsOneWidget);
      expect(find.text('Hint'), findsNothing);
      expect(find.text('Read the clue above once more.'), findsNothing);

      settings.dispose();
    });

    testWidgets('a legacy count is not counted a second time', (tester) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(hintsUsed: 1, wrongGuesses: 1),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      expect(find.text('Read the clue above once more.'), findsOneWidget);
      expect(find.text('Hints used 1'), findsOneWidget);
      expect(attempts.lastWrite.hintsUsed, 1);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('a second kind after a legacy restart keeps the floor', (
      tester,
    ) async {
      // A row written before hint kinds were stored names no kind, so the
      // total stays at the restored floor rather than risking a double
      // count. This is the documented limitation in AI_FEATURE.md.
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(
          hintsUsed: 1,
          wrongGuesses: 2,
          elapsedSeconds: 30,
        ),
      );
      final settings = await controllerWithThreshold(30);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(find.textContaining('longer than four letters'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      expect(find.text('The answer starts with "F".'), findsOneWidget);
      expect(attempts.lastWrite.hintsUsed, 1);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('an impossible stored count is clamped to the hint kinds', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(hintsUsed: 9),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hints used 2'), findsOneWidget);

      settings.dispose();
    });

    testWidgets('a negative stored count is read as none', (tester) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(hintsUsed: -3),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Hints used'), findsNothing);

      settings.dispose();
    });

    testWidgets('invalid restored counters report the problem on screen', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(hintsUsed: 0, wrongGuesses: -2),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(
        find.text('Hints are unavailable: the wrong guess count is invalid.'),
        findsOneWidget,
      );
      expect(find.text('Hint available'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Reveal'), findsNothing);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });
  });

  group('stored hint kinds', () {
    test('an empty set is stored as nothing at all', () {
      expect(encodeHintKinds({}), isNull);
    });

    test('kinds survive a round trip', () {
      for (final kinds in [
        {HintKind.clue},
        {HintKind.firstLetter},
        {HintKind.clue, HintKind.firstLetter},
      ]) {
        expect(decodeHintKinds(encodeHintKinds(kinds)), kinds);
      }
    });

    test('the stored order is fixed, whatever order they were revealed in', () {
      expect(
        encodeHintKinds({HintKind.firstLetter, HintKind.clue}),
        encodeHintKinds({HintKind.clue, HintKind.firstLetter}),
      );
    });

    test('a missing or blank column reads as nothing revealed', () {
      expect(decodeHintKinds(null), isEmpty);
      expect(decodeHintKinds(''), isEmpty);
      expect(decodeHintKinds('   '), isEmpty);
      expect(decodeHintKinds(','), isEmpty);
    });

    test('unknown tokens are dropped instead of throwing', () {
      expect(decodeHintKinds('nonsense'), isEmpty);
      expect(decodeHintKinds('clue,nonsense'), {HintKind.clue});
    });

    test('surrounding whitespace is tolerated', () {
      expect(decodeHintKinds(' clue , firstLetter '), {
        HintKind.clue,
        HintKind.firstLetter,
      });
    });

    test('a row stored before the column existed reads as no kinds', () {
      final legacy = Attempt.fromMap({
        'id': 3,
        'puzzle_id': 1,
        'status': Attempt.statusPaused,
        'wrong_guesses': 1,
        'hints_used': 1,
        'elapsed_seconds': 12,
        'last_guess': null,
        'user_note': null,
        'started_at': DateTime.utc(2026, 3, 1).toIso8601String(),
        'finished_at': null,
      });

      expect(legacy.hintKinds, isNull);
      expect(legacy.hintsUsed, 1);
    });
  });

  group('hint kinds across a restart', () {
    testWidgets('a hint already revealed is shown again, never re-offered', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(
          hintsUsed: 1,
          wrongGuesses: 1,
          hintKinds: 'clue',
        ),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('Read the clue above once more.'), findsOneWidget);
      expect(find.text('Hints used 1'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(find.text('Hint available'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Reveal'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 1);
      expect(attempts.lastWrite.hintKinds, 'clue');

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('a second kind after a restart is counted exactly once', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(
          hintsUsed: 1,
          wrongGuesses: 2,
          elapsedSeconds: 30,
          hintKinds: 'clue',
        ),
      );
      final settings = await controllerWithThreshold(30);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(find.textContaining('longer than four letters'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reveal'));
      await flushWrites(tester);

      expect(find.text('The answer starts with "F".'), findsOneWidget);
      expect(find.text('Hints used 2'), findsOneWidget);
      expect(attempts.lastWrite.hintsUsed, 2);
      expect(attempts.lastWrite.hintKinds, 'clue,firstLetter');

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('both kinds restored leave nothing to offer', (tester) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(
          hintsUsed: 2,
          wrongGuesses: 3,
          elapsedSeconds: 90,
          hintKinds: 'clue,firstLetter',
        ),
      );
      final settings = await controllerWithThreshold(30);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(find.text('Hints used 2'), findsOneWidget);
      expect(find.text('Hint available'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 2);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });

    testWidgets('a corrupted column reveals nothing and keeps the count', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(hintsUsed: 1, hintKinds: 'garbage'),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hint'), findsNothing);
      expect(find.text('Hints used 1'), findsOneWidget);

      settings.dispose();
    });

    testWidgets('resetting clears the stored kinds', (tester) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(
          hintsUsed: 1,
          wrongGuesses: 1,
          hintKinds: 'clue',
        ),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);

      expect(find.text('Hint'), findsNothing);
      expect(find.textContaining('Hints used'), findsNothing);
      expect(attempts.lastWrite.hintsUsed, 0);
      expect(attempts.lastWrite.hintKinds, isNull);

      settings.dispose();
    });

    testWidgets('gameplay saves keep a note written in History', (
      tester,
    ) async {
      final attempts = FakeAttemptRepository(
        existing: buildSavedAttempt(
          hintsUsed: 0,
          wrongGuesses: 1,
          userNote: 'Nearly had it',
        ),
      );
      final settings = await controllerWithThreshold(60);

      await tester.pumpWidget(
        wrapPlay(buildPuzzle(), attempts: attempts, settings: settings),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Resume'));
      await flushWrites(tester);

      expect(attempts.lastWrite.userNote, 'Nearly had it');

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Reset'));
      await flushWrites(tester);
      settings.dispose();
    });
  });
}
