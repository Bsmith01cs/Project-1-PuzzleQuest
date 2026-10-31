import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:puzzle_quest/main.dart';
import 'package:puzzle_quest/screens/home_shell.dart';
import 'package:puzzle_quest/screens/settings_screen.dart';
import 'package:puzzle_quest/settings/settings_controller.dart';

Widget wrapSettings(SettingsController settings) {
  return MaterialApp(
    home: Scaffold(body: SettingsScreen(settings: settings)),
  );
}

void main() {
  group('AppSettings', () {
    test('defaults to a light theme, full motion and 60 seconds', () {
      const settings = AppSettings();

      expect(settings.darkTheme, isFalse);
      expect(settings.reducedMotion, isFalse);
      expect(settings.hintThresholdSeconds, defaultHintThresholdSeconds);
      expect(defaultHintThresholdSeconds, 60);
    });

    test('copyWith replaces only the named value', () {
      const settings = AppSettings();

      final dark = settings.copyWith(darkTheme: true);
      expect(dark.darkTheme, isTrue);
      expect(dark.reducedMotion, isFalse);
      expect(dark.hintThresholdSeconds, defaultHintThresholdSeconds);

      final slower = dark.copyWith(hintThresholdSeconds: 90);
      expect(slower.darkTheme, isTrue);
      expect(slower.hintThresholdSeconds, 90);
    });
  });

  group('clampHintThreshold', () {
    test('keeps values inside the approved range', () {
      expect(clampHintThreshold(30), 30);
      expect(clampHintThreshold(75), 75);
      expect(clampHintThreshold(120), 120);
    });

    test('pulls values back to the nearest bound', () {
      expect(clampHintThreshold(0), minHintThresholdSeconds);
      expect(clampHintThreshold(29), minHintThresholdSeconds);
      expect(clampHintThreshold(121), maxHintThresholdSeconds);
      expect(clampHintThreshold(1000), maxHintThresholdSeconds);
    });

    test('the range is 30 to 120 seconds', () {
      expect(minHintThresholdSeconds, 30);
      expect(maxHintThresholdSeconds, 120);
    });
  });

  group('SettingsController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts with defaults before anything is loaded', () {
      final controller = SettingsController();

      expect(controller.settings.darkTheme, isFalse);
      expect(controller.settings.reducedMotion, isFalse);
      expect(controller.settings.hintThresholdSeconds, 60);
      expect(controller.preferencesUnavailable, isFalse);

      controller.dispose();
    });

    test('load keeps the defaults when nothing was stored', () async {
      final controller = SettingsController();
      await controller.load();

      expect(controller.settings.darkTheme, isFalse);
      expect(controller.settings.reducedMotion, isFalse);
      expect(controller.settings.hintThresholdSeconds, 60);
      expect(controller.preferencesUnavailable, isFalse);

      controller.dispose();
    });

    test('load restores every stored preference', () async {
      SharedPreferences.setMockInitialValues({
        SettingsController.darkThemeKey: true,
        SettingsController.reducedMotionKey: true,
        SettingsController.hintThresholdKey: 95,
      });

      final controller = SettingsController();
      await controller.load();

      expect(controller.settings.darkTheme, isTrue);
      expect(controller.settings.reducedMotion, isTrue);
      expect(controller.settings.hintThresholdSeconds, 95);

      controller.dispose();
    });

    test('load clamps a stored threshold outside the range', () async {
      SharedPreferences.setMockInitialValues({
        SettingsController.hintThresholdKey: 600,
      });

      final controller = SettingsController();
      await controller.load();

      expect(controller.settings.hintThresholdSeconds, 120);

      controller.dispose();
    });

    test('load notifies listeners', () async {
      final controller = SettingsController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();

      expect(notifications, 1);

      controller.dispose();
    });

    test('setDarkTheme persists the choice and notifies', () async {
      final controller = SettingsController();
      await controller.load();

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setDarkTheme(true);

      expect(controller.settings.darkTheme, isTrue);
      expect(notifications, greaterThanOrEqualTo(1));

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(SettingsController.darkThemeKey), isTrue);

      controller.dispose();
    });

    test('setReducedMotion persists the choice', () async {
      final controller = SettingsController();
      await controller.load();

      await controller.setReducedMotion(true);

      expect(controller.settings.reducedMotion, isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(SettingsController.reducedMotionKey), isTrue);

      controller.dispose();
    });

    test('setHintThreshold persists the chosen seconds', () async {
      final controller = SettingsController();
      await controller.load();

      await controller.setHintThreshold(45);

      expect(controller.settings.hintThresholdSeconds, 45);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt(SettingsController.hintThresholdKey), 45);

      controller.dispose();
    });

    test('setHintThreshold clamps before storing', () async {
      final controller = SettingsController();
      await controller.load();

      await controller.setHintThreshold(5);

      expect(controller.settings.hintThresholdSeconds, 30);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt(SettingsController.hintThresholdKey), 30);

      controller.dispose();
    });

    test('a later launch restores what an earlier one saved', () async {
      final first = SettingsController();
      await first.load();
      await first.setDarkTheme(true);
      await first.setReducedMotion(true);
      await first.setHintThreshold(110);
      first.dispose();

      final second = SettingsController();
      await second.load();

      expect(second.settings.darkTheme, isTrue);
      expect(second.settings.reducedMotion, isTrue);
      expect(second.settings.hintThresholdSeconds, 110);

      second.dispose();
    });
  });

  group('buildAppTheme', () {
    test('builds Material 3 themes from the existing seed colour', () {
      final light = buildAppTheme(
        brightness: Brightness.light,
        reducedMotion: false,
      );

      expect(light.useMaterial3, isTrue);
      expect(light.colorScheme.brightness, Brightness.light);

      final dark = buildAppTheme(
        brightness: Brightness.dark,
        reducedMotion: false,
      );

      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.primary, isNot(light.colorScheme.primary));
    });

    test('reduced motion replaces the page transitions', () {
      final normal = buildAppTheme(
        brightness: Brightness.light,
        reducedMotion: false,
      );
      final reduced = buildAppTheme(
        brightness: Brightness.light,
        reducedMotion: true,
      );

      expect(
        reduced.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<NoPageTransitionsBuilder>(),
      );
      expect(
        normal.pageTransitionsTheme.builders[TargetPlatform.android],
        isNot(isA<NoPageTransitionsBuilder>()),
      );
    });

    testWidgets('the no-transition builder returns the page unchanged', (
      tester,
    ) async {
      const child = Text('page');
      const builder = NoPageTransitionsBuilder();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => builder.buildTransitions<void>(
              MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
              context,
              const AlwaysStoppedAnimation<double>(0),
              const AlwaysStoppedAnimation<double>(0),
              child,
            ),
          ),
        ),
      );

      expect(find.text('page'), findsOneWidget);
    });
  });

  group('settings screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows the three settings with their stored values', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        SettingsController.hintThresholdKey: 75,
      });

      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(wrapSettings(controller));
      await tester.pumpAndSettle();

      expect(find.text('Dark theme'), findsOneWidget);
      expect(find.text('Reduced motion'), findsOneWidget);
      expect(find.text('Hint threshold'), findsOneWidget);
      expect(
        find.text('Wait 75 seconds before a hint becomes available.'),
        findsOneWidget,
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 75);
      expect(slider.min, 30);
      expect(slider.max, 120);
      expect(slider.divisions, 18);

      controller.dispose();
    });

    testWidgets('toggling dark theme updates and persists the setting', (
      tester,
    ) async {
      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(wrapSettings(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Dark theme'));
      await tester.pumpAndSettle();

      expect(controller.settings.darkTheme, isTrue);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Dark theme'),
            )
            .value,
        isTrue,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(SettingsController.darkThemeKey), isTrue);

      controller.dispose();
    });

    testWidgets('toggling reduced motion updates and persists the setting', (
      tester,
    ) async {
      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(wrapSettings(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Reduced motion'));
      await tester.pumpAndSettle();

      expect(controller.settings.reducedMotion, isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(SettingsController.reducedMotionKey), isTrue);

      controller.dispose();
    });

    testWidgets('the slider previews while dragging and saves on release', (
      tester,
    ) async {
      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(wrapSettings(controller));
      await tester.pumpAndSettle();

      tester.widget<Slider>(find.byType(Slider)).onChanged!(90);
      await tester.pumpAndSettle();

      expect(
        find.text('Wait 90 seconds before a hint becomes available.'),
        findsOneWidget,
      );
      expect(controller.settings.hintThresholdSeconds, 60);

      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(90);
      await tester.pumpAndSettle();

      expect(controller.settings.hintThresholdSeconds, 90);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt(SettingsController.hintThresholdKey), 90);

      controller.dispose();
    });

    testWidgets('an external change is reflected on screen', (tester) async {
      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(wrapSettings(controller));
      await tester.pumpAndSettle();

      await controller.setHintThreshold(35);
      await tester.pumpAndSettle();

      expect(
        find.text('Wait 35 seconds before a hint becomes available.'),
        findsOneWidget,
      );

      controller.dispose();
    });
  });

  group('app theme', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('dark theme applies across the app and can be toggled', (
      tester,
    ) async {
      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(PuzzleQuestApp(settings: controller));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      expect(app.darkTheme, isNotNull);
      expect(
        Theme.of(tester.element(find.byType(HomeShell))).brightness,
        Brightness.light,
      );

      await controller.setDarkTheme(true);
      await tester.pumpAndSettle();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        Theme.of(tester.element(find.byType(HomeShell))).brightness,
        Brightness.dark,
      );

      controller.dispose();
    });

    testWidgets('reduced motion disables animations for the whole app', (
      tester,
    ) async {
      final controller = SettingsController();
      await controller.load();

      await tester.pumpWidget(PuzzleQuestApp(settings: controller));
      await tester.pumpAndSettle();

      expect(
        MediaQuery.of(
          tester.element(find.byType(HomeShell)),
        ).disableAnimations,
        isFalse,
      );

      await controller.setReducedMotion(true);
      await tester.pumpAndSettle();

      expect(
        MediaQuery.of(
          tester.element(find.byType(HomeShell)),
        ).disableAnimations,
        isTrue,
      );
      expect(
        Theme.of(
          tester.element(find.byType(HomeShell)),
        ).pageTransitionsTheme.builders[TargetPlatform.android],
        isA<NoPageTransitionsBuilder>(),
      );

      controller.dispose();
    });
  });
}
