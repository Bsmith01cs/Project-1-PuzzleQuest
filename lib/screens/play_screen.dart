import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/puzzle.dart';

enum GameStatus { ready, running, paused, solved }

String scrambleWord(String word, {Random? random}) {
  final letters = word.split('');
  if (letters.toSet().length < 2) {
    return word;
  }

  final rng = random ?? Random();
  var scrambled = word;
  while (scrambled == word) {
    letters.shuffle(rng);
    scrambled = letters.join();
  }
  return scrambled;
}

String formatElapsed(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder';
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, this.puzzle, this.random});

  final Puzzle? puzzle;
  final Random? random;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final TextEditingController _guess = TextEditingController();

  Timer? _timer;
  GameStatus _status = GameStatus.ready;
  String _scrambled = '';
  String? _feedback;
  int _wrongGuesses = 0;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _scrambled = _scramble();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _guess.dispose();
    super.dispose();
  }

  String _scramble() {
    final puzzle = widget.puzzle;
    if (puzzle == null) {
      return '';
    }
    return scrambleWord(puzzle.answer, random: widget.random);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  void _start() {
    setState(() {
      _status = GameStatus.running;
      _feedback = null;
    });
    _startTimer();
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _status = GameStatus.paused);
  }

  void _resume() {
    setState(() => _status = GameStatus.running);
    _startTimer();
  }

  void _reset() {
    _timer?.cancel();
    _guess.clear();
    setState(() {
      _status = GameStatus.ready;
      _scrambled = _scramble();
      _elapsedSeconds = 0;
      _wrongGuesses = 0;
      _feedback = null;
    });
  }

  void _checkGuess() {
    final puzzle = widget.puzzle;
    if (puzzle == null || _status != GameStatus.running) {
      return;
    }

    final guess = _guess.text.trim();
    if (guess.isEmpty) {
      return;
    }

    if (guess.toUpperCase() == puzzle.answer.toUpperCase()) {
      _timer?.cancel();
      setState(() {
        _status = GameStatus.solved;
        _feedback = null;
      });
      return;
    }

    _guess.clear();
    setState(() {
      _wrongGuesses++;
      _feedback = 'Not quite. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puzzle = widget.puzzle;

    if (puzzle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Play Puzzle')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Puzzle gameplay will appear here.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Play Puzzle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(puzzle.clue, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            _letters(theme),
            const SizedBox(height: 16),
            Text(
              'Time ${formatElapsed(_elapsedSeconds)} · '
              'Wrong guesses $_wrongGuesses',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (_status == GameStatus.solved)
              _solvedMessage(theme, puzzle)
            else ...[
              TextField(
                controller: _guess,
                enabled: _status == GameStatus.running,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Your guess',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _checkGuess(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _status == GameStatus.running ? _checkGuess : null,
                child: const Text('Check'),
              ),
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                _feedback!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(spacing: 12, children: _controls()),
          ],
        ),
      ),
    );
  }

  Widget _letters(ThemeData theme) {
    if (_status == GameStatus.paused) {
      return Text(
        'Paused',
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      );
    }

    return Text(
      _scrambled.split('').join(' '),
      style: theme.textTheme.headlineMedium,
      textAlign: TextAlign.center,
    );
  }

  Widget _solvedMessage(ThemeData theme, Puzzle puzzle) {
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Solved!', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'The answer was ${puzzle.answer}, '
              'found in ${formatElapsed(_elapsedSeconds)}.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _controls() {
    switch (_status) {
      case GameStatus.ready:
        return [
          FilledButton.tonal(onPressed: _start, child: const Text('Start')),
        ];
      case GameStatus.running:
        return [
          FilledButton.tonal(onPressed: _pause, child: const Text('Pause')),
          OutlinedButton(onPressed: _reset, child: const Text('Reset')),
        ];
      case GameStatus.paused:
        return [
          FilledButton.tonal(onPressed: _resume, child: const Text('Resume')),
          OutlinedButton(onPressed: _reset, child: const Text('Reset')),
        ];
      case GameStatus.solved:
        return [
          OutlinedButton(onPressed: _reset, child: const Text('Play again')),
        ];
    }
  }
}
