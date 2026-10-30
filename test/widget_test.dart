import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/main.dart';

void main() {
  testWidgets('starts on the catalog', (tester) async {
    await tester.pumpWidget(const PuzzleQuestApp());

    expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
    expect(find.text('No puzzles yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom tabs switch between the three primary screens', (
    tester,
  ) async {
    await tester.pumpWidget(const PuzzleQuestApp());

    await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'History & Insights'), findsOneWidget);
    expect(
      find.text('Completed puzzles and progress insights will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('App preferences will appear here.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Catalog'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
    expect(find.text('No puzzles yet.'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('editor opens from the catalog and closes again', (tester) async {
    await tester.pumpWidget(const PuzzleQuestApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Create Puzzle'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Create Puzzle'), findsOneWidget);
    expect(find.text('The puzzle editor form will appear here.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play screen opens from the catalog and closes again', (
    tester,
  ) async {
    await tester.pumpWidget(const PuzzleQuestApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Preview Play screen'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Play Puzzle'), findsOneWidget);
    expect(find.text('Puzzle gameplay will appear here.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
