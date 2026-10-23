import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_quest/main.dart';

void main() {
  testWidgets('home screen shows the app title and tagline', (tester) async {
    await tester.pumpWidget(const PuzzleQuestApp());

    expect(find.widgetWithText(AppBar, 'PuzzleQuest'), findsOneWidget);
    expect(find.text('Offline word scramble'), findsOneWidget);
  });
}
