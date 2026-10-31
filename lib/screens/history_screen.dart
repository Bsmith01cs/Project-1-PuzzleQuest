import 'package:flutter/material.dart';

import '../models/attempt.dart';
import '../models/puzzle.dart';
import '../repositories/attempt_repository.dart';
import '../repositories/puzzle_repository.dart';
import 'play_screen.dart' show formatElapsed;

const maxNoteLength = 140;

String? validateNote(String? value) {
  final note = (value ?? '').trim();
  if (note.length > maxNoteLength) {
    return 'Keep the note to $maxNoteLength characters or fewer.';
  }
  return null;
}

String attemptStatusLabel(String status) {
  switch (status) {
    case Attempt.statusInProgress:
      return 'In Progress';
    case Attempt.statusPaused:
      return 'Paused';
    case Attempt.statusSolved:
      return 'Solved';
    default:
      return status;
  }
}

List<Attempt> filterAttemptsByStatus(List<Attempt> attempts, String? status) {
  if (status == null) {
    return attempts;
  }
  return attempts.where((attempt) => attempt.status == status).toList();
}

int solvedAttemptCount(List<Attempt> attempts) {
  return attempts
      .where((attempt) => attempt.status == Attempt.statusSolved)
      .length;
}

double completionRate(List<Attempt> attempts) {
  if (attempts.isEmpty) {
    return 0;
  }
  return solvedAttemptCount(attempts) / attempts.length * 100;
}

String formatCompletionRate(List<Attempt> attempts) {
  return '${completionRate(attempts).round()}%';
}

String formatAttemptDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.attempts, this.puzzles});

  final AttemptRepository? attempts;
  final PuzzleRepository? puzzles;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final AttemptRepository _attempts =
      widget.attempts ?? AttemptRepository();
  late final PuzzleRepository _puzzles = widget.puzzles ?? PuzzleRepository();

  // Owned by the screen, not by the note dialog: the dialog's text field keeps
  // rebuilding while the route animates away, so a controller disposed as soon
  // as showDialog returns is still in use.
  final TextEditingController _noteController = TextEditingController();

  List<Attempt> _allAttempts = const [];
  Map<int, Puzzle> _puzzlesById = const {};
  String? _statusFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attempts = await _attempts.findAll();
      final puzzles = await _puzzles.findAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _allAttempts = attempts;
        _puzzlesById = {
          for (final puzzle in puzzles)
            if (puzzle.id != null) puzzle.id!: puzzle,
        };
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load history. $error';
        _loading = false;
      });
    }
  }

  List<Attempt> get _visibleAttempts =>
      filterAttemptsByStatus(_allAttempts, _statusFilter);

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editNote(Attempt attempt) async {
    final controller = _noteController..text = attempt.userNote ?? '';

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          final error = validateNote(controller.text);

          return AlertDialog(
            title: Text(attempt.userNote == null ? 'Add note' : 'Edit note'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: maxNoteLength,
              decoration: InputDecoration(
                labelText: 'Note',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: error == null
                    ? () =>
                          Navigator.of(dialogContext).pop(controller.text.trim())
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    final id = attempt.id;
    if (note == null || id == null) {
      return;
    }

    try {
      await _attempts.updateNote(id, note.isEmpty ? null : note);
      if (!mounted) {
        return;
      }
      _showMessage(note.isEmpty ? 'Note removed.' : 'Note saved.');
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not save the note. $error');
    }
  }

  Future<void> _confirmDelete(Attempt attempt) async {
    final puzzle = _puzzlesById[attempt.puzzleId];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete attempt?'),
        content: Text(
          'This removes the saved progress and note for '
          '"${puzzle?.clue ?? 'this puzzle'}". This cannot be undone.',
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

    final id = attempt.id;
    if (!(confirmed ?? false) || id == null) {
      return;
    }

    try {
      await _attempts.delete(id);
      if (!mounted) {
        return;
      }
      _showMessage('Attempt deleted.');
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not delete the attempt. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statistics(theme),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('All', null),
              _filterChip('In Progress', Attempt.statusInProgress),
              _filterChip('Paused', Attempt.statusPaused),
              _filterChip('Solved', Attempt.statusSolved),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _content(theme)),
        ],
      ),
    );
  }

  Widget _statistics(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _statistic(theme, 'Attempts', '${_allAttempts.length}'),
            _statistic(
              theme,
              'Solved attempts',
              '${solvedAttemptCount(_allAttempts)}',
            ),
            _statistic(
              theme,
              'Completion rate',
              formatCompletionRate(_allAttempts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statistic(ThemeData theme, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? status) {
    return FilterChip(
      label: Text(label),
      selected: _statusFilter == status,
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  Widget _content(ThemeData theme) {
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

    if (_allAttempts.isEmpty) {
      return Center(
        child: Text(
          'No attempts yet. Play a puzzle to start your history.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final visible = _visibleAttempts;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          'No attempts with this status.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (_, index) => _attemptCard(theme, visible[index]),
    );
  }

  Widget _attemptCard(ThemeData theme, Attempt attempt) {
    final puzzle = _puzzlesById[attempt.puzzleId];
    final finishedAt = attempt.finishedAt;
    final note = attempt.userNote;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    puzzle?.clue ?? 'Puzzle no longer available',
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${puzzle?.category ?? 'Unknown'} · '
                    '${attemptStatusLabel(attempt.status)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Time ${formatElapsed(attempt.elapsedSeconds)} · '
                    'Wrong guesses ${attempt.wrongGuesses}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (finishedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${formatAttemptDate(finishedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(note, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: note == null ? 'Add note' : 'Edit note',
                  icon: const Icon(Icons.edit_note_outlined),
                  onPressed: () => _editNote(attempt),
                ),
                IconButton(
                  tooltip: 'Delete attempt',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(attempt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
