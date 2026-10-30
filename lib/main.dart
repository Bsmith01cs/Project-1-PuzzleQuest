import 'package:flutter/material.dart';

import 'screens/home_shell.dart';

void main() {
  runApp(const PuzzleQuestApp());
}

class PuzzleQuestApp extends StatelessWidget {
  const PuzzleQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuzzleQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A5FC1)),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
