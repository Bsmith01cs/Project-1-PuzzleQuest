import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:puzzle_quest/models/attempt.dart';
import 'package:puzzle_quest/models/puzzle.dart';
import 'package:puzzle_quest/repositories/attempt_repository.dart';
import 'package:puzzle_quest/repositories/puzzle_repository.dart';
import 'package:puzzle_quest/screens/catalog_screen.dart';
import 'package:puzzle_quest/screens/editor_screen.dart';
import 'package:puzzle_quest/screens/history_screen.dart';
import 'package:puzzle_quest/screens/play_screen.dart';
import 'package:puzzle_quest/screens/settings_screen.dart';
import 'package:puzzle_quest/settings/settings_controller.dart';

class FakePuzzleRepository extends PuzzleRepository {
  FakePuzzleRepository([List<Puzzle>? puzzles])
    : puzzles = List<Puzzle>.from(puzzles ?? const <Puzzle>[]);

  final List<Puzzle> puzzles;

  @override
  Future<void> seedStarterPuzzlesOnce() async {}

  @override
  Future<List<Puzzle>> findAll() async => List<Puzzle>.unmodifiable(puzzles);
}

class FakeAttemptRepository extends AttemptRepository {
  FakeAttemptRepository([List<Attempt>? attempts])
    : attempts = List<Attempt>.from(attempts ?? const <Attempt>[]);

  final List<Attempt> attempts;

  @override
  Future<List<Attempt>> findAll() async => List<Attempt>.unmodifiable(attempts);

  @override
  Future<Attempt?> findLatestUnfinished(int puzzleId) async => null;

  @override
  Future<int> insert(Attempt attempt) async => 1;

  @override
  Future<int> update(Attempt attempt) async => 1;
}

Puzzle buildPuzzle() {
  return Puzzle(
    id: 1,
    answer: 'FLUTTER',
    clue: 'A toolkit for building cross-platform apps',
    category: 'Technology',
    difficulty: 2,
    createdAt: DateTime.utc(2026, 3, 1),
    updatedAt: DateTime.utc(2026, 3, 1),
  );
}

Attempt buildAttempt() {
  return Attempt(
    id: 1,
    puzzleId: 1,
    status: Attempt.statusSolved,
    wrongGuesses: 2,
    hintsUsed: 1,
    elapsedSeconds: 95,
    startedAt: DateTime.utc(2026, 3, 1),
    finishedAt: DateTime.utc(2026, 3, 1, 0, 2),
  );
}

Future<SettingsController> buildSettings() async {
  SharedPreferences.setMockInitialValues({});
  final controller = SettingsController();
  await controller.load();
  return controller;
}

/// Every screen, built with data on screen so no check runs against an
/// empty page. The three shell tabs are wrapped the way HomeShell wraps
/// them, since they carry no Scaffold of their own.
Future<Map<String, Widget>> screens() async {
  final settings = await buildSettings();

  return {
    'Catalog': Scaffold(
      body: CatalogScreen(repository: FakePuzzleRepository([buildPuzzle()])),
    ),
    'Editor': const EditorScreen(),
    'Play': PlayScreen(
      puzzle: buildPuzzle(),
      attempts: FakeAttemptRepository(),
      settings: settings,
    ),
    'History': Scaffold(
      body: HistoryScreen(
        attempts: FakeAttemptRepository([buildAttempt()]),
        puzzles: FakePuzzleRepository([buildPuzzle()]),
      ),
    ),
    'Settings': Scaffold(body: SettingsScreen(settings: settings)),
  };
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(400, 800),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A5FC1),
          brightness: brightness,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every screen names its tap targets and meets 48dp', (
    tester,
  ) async {
    for (final entry in (await screens()).entries) {
      await pumpScreen(tester, entry.value);
      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
        reason: '${entry.key} has a tap target under 48dp',
      );
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: '${entry.key} has an unlabelled tap target',
      );
    }
  });

  testWidgets('every screen keeps readable contrast in light and dark', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final entry in (await screens()).entries) {
        await pumpScreen(tester, entry.value, brightness: brightness);
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: '${entry.key} fails contrast in $brightness',
        );
      }
    }
  });

  testWidgets('every screen lays out at double text size', (tester) async {
    for (final entry in (await screens()).entries) {
      await pumpScreen(tester, entry.value, textScale: 2);
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} overflows at double text size',
      );
    }
  });

  testWidgets('every screen lays out in landscape', (tester) async {
    for (final entry in (await screens()).entries) {
      await pumpScreen(tester, entry.value, size: const Size(800, 400));
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} overflows in landscape',
      );
    }
  });

  testWidgets('the guess field takes keyboard focus and submits on Enter', (
    tester,
  ) async {
    final settings = await buildSettings();
    addTearDown(settings.dispose);
    final attempts = FakeAttemptRepository();

    await pumpScreen(
      tester,
      PlayScreen(puzzle: buildPuzzle(), attempts: attempts, settings: settings),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, 'Your guess');
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);

    await tester.enterText(field, 'WRONG');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Not quite. Try again.'), findsOneWidget);
  });

  testWidgets('every control on the Play screen is reachable with Tab', (
    tester,
  ) async {
    final settings = await buildSettings();
    addTearDown(settings.dispose);

    await pumpScreen(
      tester,
      PlayScreen(
        puzzle: buildPuzzle(),
        attempts: FakeAttemptRepository(),
        settings: settings,
      ),
    );

    final seen = <String>{};
    for (var press = 0; press < 8; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = tester.binding.focusManager.primaryFocus;
      if (focused != null) {
        seen.add(focused.toStringShort());
      }
    }

    // Tab reaches something focusable rather than leaving focus stuck.
    expect(seen, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
