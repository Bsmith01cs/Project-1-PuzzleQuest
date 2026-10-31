import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsController();
  await settings.load();

  runApp(PuzzleQuestApp(settings: settings));
}

const seedColor = Color(0xFF4A5FC1);

/// Returns the child unchanged, which removes route transition animations
/// while reduced motion is on.
class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

const noPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: NoPageTransitionsBuilder(),
    TargetPlatform.iOS: NoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: NoPageTransitionsBuilder(),
    TargetPlatform.linux: NoPageTransitionsBuilder(),
    TargetPlatform.macOS: NoPageTransitionsBuilder(),
    TargetPlatform.windows: NoPageTransitionsBuilder(),
  },
);

ThemeData buildAppTheme({
  required Brightness brightness,
  required bool reducedMotion,
}) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    useMaterial3: true,
    pageTransitionsTheme: reducedMotion
        ? noPageTransitionsTheme
        : const PageTransitionsTheme(),
  );
}

class PuzzleQuestApp extends StatelessWidget {
  const PuzzleQuestApp({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final current = settings.settings;

        return MaterialApp(
          title: 'PuzzleQuest',
          theme: buildAppTheme(
            brightness: Brightness.light,
            reducedMotion: current.reducedMotion,
          ),
          darkTheme: buildAppTheme(
            brightness: Brightness.dark,
            reducedMotion: current.reducedMotion,
          ),
          themeMode: current.darkTheme ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            if (!current.reducedMotion) {
              return content;
            }
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: content,
            );
          },
          home: HomeShell(settings: settings),
        );
      },
    );
  }
}
