import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/screens/play_screen.dart';

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

Widget wrapPlay(Puzzle? puzzle, {Random? random}) {
  return MaterialApp(home: PlayScreen(puzzle: puzzle, random: random));
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
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);

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
}
