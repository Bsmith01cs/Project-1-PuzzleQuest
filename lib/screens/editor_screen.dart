import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import '../repositories/puzzle_repository.dart';

const maxClueLength = 120;
const maxCategoryLength = 40;

String difficultyLabel(int difficulty) {
  switch (difficulty) {
    case 1:
      return 'Easy';
    case 3:
      return 'Hard';
    default:
      return 'Medium';
  }
}

String? validateAnswer(String? value) {
  final answer = (value ?? '').trim().toUpperCase();

  if (answer.isEmpty) {
    return 'Enter an answer.';
  }
  if (!RegExp(r'^[A-Z]+$').hasMatch(answer)) {
    return 'Use letters only.';
  }
  if (answer.length < 4 || answer.length > 12) {
    return 'Use 4 to 12 letters.';
  }
  if (answer.split('').toSet().length == 1) {
    return 'Use more than one distinct letter.';
  }
  return null;
}

String? validateClue(String? value) {
  final clue = (value ?? '').trim();

  if (clue.isEmpty) {
    return 'Enter a clue.';
  }
  if (clue.length > maxClueLength) {
    return 'Keep the clue to $maxClueLength characters or fewer.';
  }
  return null;
}

String? validateCategory(String? value) {
  final category = (value ?? '').trim();

  if (category.isEmpty) {
    return 'Enter a category.';
  }
  if (category.length > maxCategoryLength) {
    return 'Keep the category to $maxCategoryLength characters or fewer.';
  }
  return null;
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.puzzle, this.repository});

  final Puzzle? puzzle;
  final PuzzleRepository? repository;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final PuzzleRepository _repository =
      widget.repository ?? PuzzleRepository();

  late final TextEditingController _answer = TextEditingController(
    text: widget.puzzle?.answer ?? '',
  );
  late final TextEditingController _clue = TextEditingController(
    text: widget.puzzle?.clue ?? '',
  );
  late final TextEditingController _category = TextEditingController(
    text: widget.puzzle?.category ?? '',
  );

  late int _difficulty = widget.puzzle?.difficulty ?? 2;
  bool _saving = false;

  @override
  void dispose() {
    _answer.dispose();
    _clue.dispose();
    _category.dispose();
    super.dispose();
  }

  bool get _isValid =>
      validateAnswer(_answer.text) == null &&
      validateClue(_clue.text) == null &&
      validateCategory(_category.text) == null;

  Future<void> _save() async {
    setState(() => _saving = true);

    final existing = widget.puzzle;
    final now = DateTime.now().toUtc();
    final puzzle = Puzzle(
      id: existing?.id,
      answer: _answer.text.trim().toUpperCase(),
      clue: _clue.text.trim(),
      category: _category.text.trim(),
      difficulty: _difficulty,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (existing == null) {
        await _repository.insert(puzzle);
      } else {
        await _repository.update(puzzle);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save the puzzle. $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.puzzle != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Puzzle' : 'Create Puzzle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _answer,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Answer',
                helperText: '4 to 12 letters, saved in uppercase',
                errorText: _answer.text.isEmpty
                    ? null
                    : validateAnswer(_answer.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clue,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Clue',
                helperText: 'Up to $maxClueLength characters',
                errorText: _clue.text.isEmpty ? null : validateClue(_clue.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                errorText: _category.text.isEmpty
                    ? null
                    : validateCategory(_category.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Difficulty',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Easy')),
                ButtonSegment(value: 2, label: Text('Medium')),
                ButtonSegment(value: 3, label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (selection) =>
                  setState(() => _difficulty = selection.first),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isValid && !_saving ? _save : null,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
