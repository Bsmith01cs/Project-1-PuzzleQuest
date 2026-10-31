import 'package:flutter/material.dart';

import '../repositories/attempt_repository.dart';
import '../repositories/puzzle_repository.dart';
import 'catalog_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.puzzleRepository, this.attemptRepository});

  final PuzzleRepository? puzzleRepository;
  final AttemptRepository? attemptRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titles = ['PuzzleQuest', 'History & Insights', 'Settings'];

  int _selectedIndex = 0;

  // Bumped whenever History is opened so the screen reloads its attempts and
  // statistics instead of showing what it read the last time.
  int _historyVisit = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          CatalogScreen(repository: widget.puzzleRepository),
          HistoryScreen(
            key: ValueKey(_historyVisit),
            attempts: widget.attemptRepository,
            puzzles: widget.puzzleRepository,
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          if (index == 1 && _selectedIndex != 1) {
            _historyVisit++;
          }
          _selectedIndex = index;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
