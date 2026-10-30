import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../repositories/puzzle_repository.dart';
import 'editor_screen.dart';
import 'play_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.repository});

  final PuzzleRepository? repository;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final PuzzleRepository _repository =
      widget.repository ?? PuzzleRepository();

  List<Puzzle> _puzzles = const [];
  int? _difficultyFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repository.seedStarterPuzzlesOnce();
      final puzzles = await _repository.findAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _puzzles = puzzles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load puzzles. $error';
        _loading = false;
      });
    }
  }

  List<Puzzle> get _visiblePuzzles {
    final filter = _difficultyFilter;
    if (filter == null) {
      return _puzzles;
    }
    return _puzzles.where((puzzle) => puzzle.difficulty == filter).toList();
  }

  Future<void> _openEditor([Puzzle? puzzle]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditorScreen(puzzle: puzzle, repository: _repository),
      ),
    );

    if (saved ?? false) {
      await _load();
    }
  }

  Future<void> _confirmDelete(Puzzle puzzle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete puzzle?'),
        content: Text(
          'Deleting the puzzle for "${puzzle.clue}" also deletes its '
          'attempt history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.delete(puzzle.id!);
      await _load();
      _showMessage('Puzzle deleted.');
    } catch (error) {
      _showMessage('Could not delete the puzzle. $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visiblePuzzles;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _countLabel(visible.length),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Create Puzzle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('All', null),
              _filterChip('Easy', 1),
              _filterChip('Medium', 2),
              _filterChip('Hard', 3),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _content(theme, visible)),
          OutlinedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PlayScreen())),
            child: const Text('Preview Play screen'),
          ),
        ],
      ),
    );
  }

  String _countLabel(int visibleCount) {
    if (_loading) {
      return 'Loading puzzles…';
    }
    if (_difficultyFilter != null) {
      return '$visibleCount of ${_puzzles.length} puzzles';
    }
    return _puzzles.length == 1 ? '1 puzzle' : '${_puzzles.length} puzzles';
  }

  Widget _filterChip(String label, int? difficulty) {
    return FilterChip(
      label: Text(label),
      selected: _difficultyFilter == difficulty,
      onSelected: (_) => setState(() => _difficultyFilter = difficulty),
    );
  }

  Widget _content(ThemeData theme, List<Puzzle> visible) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_puzzles.isEmpty) {
      return Center(
        child: Text(
          'No puzzles yet.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (visible.isEmpty) {
      return Center(
        child: Text(
          'No puzzles at this difficulty.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final puzzle = visible[index];

        return Card(
          child: ListTile(
            title: Text(
              puzzle.clue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${puzzle.category} · ${difficultyLabel(puzzle.difficulty)}',
            ),
            onTap: () => _openEditor(puzzle),
            trailing: IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(puzzle),
            ),
          ),
        );
      },
    );
  }
}
