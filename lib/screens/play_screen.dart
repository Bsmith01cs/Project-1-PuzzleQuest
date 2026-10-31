import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/attempt.dart';
import '../models/puzzle.dart';
import '../repositories/attempt_repository.dart';

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
  const PlayScreen({super.key, this.puzzle, this.random, this.attempts});

  final Puzzle? puzzle;
  final Random? random;
  final AttemptRepository? attempts;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  final TextEditingController _guess = TextEditingController();

  late final AttemptRepository _attempts =
      widget.attempts ?? AttemptRepository();

  Timer? _timer;
  Future<void> _writes = Future<void>.value();

  GameStatus _status = GameStatus.ready;
  String _scrambled = '';
  String? _feedback;
  String? _notice;
  int _wrongGuesses = 0;
  int _elapsedSeconds = 0;

  int? _attemptId;
  String? _lastGuess;
  DateTime _startedAt = DateTime.now().toUtc();
  DateTime? _finishedAt;
  bool _restoring = true;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrambled = _scramble();
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _guess.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _status == GameStatus.running) {
      _pause();
    }
  }

  String _scramble() {
    final puzzle = widget.puzzle;
    if (puzzle == null) {
      return '';
    }
    return scrambleWord(puzzle.answer, random: widget.random);
  }

  // Restores the newest attempt that was never finished, so reopening a
  // puzzle continues where the player stopped instead of starting over.
  Future<void> _restore() async {
    final puzzleId = widget.puzzle?.id;
    if (puzzleId == null) {
      // Still the first synchronous pass of initState, so no rebuild needed.
      _restoring = false;
      return;
    }

    Attempt? saved;
    var failed = false;
    try {
      saved = await _attempts.findLatestUnfinished(puzzleId);
    } catch (_) {
      failed = true;
    }

    if (!mounted) {
      return;
    }

    final restored = saved;

    setState(() {
      _restoring = false;
      _saveFailed = failed;
      if (restored == null) {
        return;
      }

      final untouched =
          restored.elapsedSeconds == 0 &&
          restored.wrongGuesses == 0 &&
          restored.lastGuess == null;

      _attemptId = restored.id;
      _startedAt = restored.startedAt;
      _wrongGuesses = restored.wrongGuesses;
      _elapsedSeconds = restored.elapsedSeconds;
      _lastGuess = restored.lastGuess;
      // A reopened attempt always arrives paused: the clock must not count
      // the time the puzzle was closed.
      _status = untouched ? GameStatus.ready : GameStatus.paused;
      if (!untouched) {
        _notice = 'Resumed your unfinished attempt.';
        _guess.text = restored.lastGuess ?? '';
      }
    });
  }

  String get _savedStatus {
    switch (_status) {
      case GameStatus.solved:
        return Attempt.statusSolved;
      case GameStatus.paused:
        return Attempt.statusPaused;
      case GameStatus.ready:
      case GameStatus.running:
        return Attempt.statusInProgress;
    }
  }

  // Writes run one after another so the insert always wins the race against
  // the updates that follow it, which keeps a single row per attempt.
  void _enqueueSave() {
    _writes = _writes.then((_) async {
      try {
        await _save();
      } catch (_) {
        if (mounted) {
          setState(() => _saveFailed = true);
        }
      }
    });
  }

  Future<void> _save() async {
    final puzzleId = widget.puzzle?.id;
    if (puzzleId == null) {
      return;
    }

    final attempt = Attempt(
      id: _attemptId,
      puzzleId: puzzleId,
      status: _savedStatus,
      wrongGuesses: _wrongGuesses,
      elapsedSeconds: _elapsedSeconds,
      lastGuess: _lastGuess,
      startedAt: _startedAt,
      finishedAt: _finishedAt,
    );

    if (_attemptId == null) {
      _attemptId = await _attempts.insert(attempt);
    } else {
      await _attempts.update(attempt);
    }

    if (mounted && _saveFailed) {
      setState(() => _saveFailed = false);
    }
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
      _notice = null;
      if (_attemptId == null) {
        _startedAt = DateTime.now().toUtc();
      }
    });
    _startTimer();
    _enqueueSave();
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _status = GameStatus.paused);
    _enqueueSave();
  }

  void _resume() {
    setState(() {
      _status = GameStatus.running;
      _notice = null;
    });
    _startTimer();
    _enqueueSave();
  }

  void _reset() {
    _timer?.cancel();
    _guess.clear();

    // A solved attempt is history; leave its row alone and let the next
    // Start open a fresh one.
    final keepRecord = _status == GameStatus.solved;

    setState(() {
      if (keepRecord) {
        _attemptId = null;
      }
      _status = GameStatus.ready;
      _scrambled = _scramble();
      _elapsedSeconds = 0;
      _wrongGuesses = 0;
      _feedback = null;
      _notice = null;
      _lastGuess = null;
      _finishedAt = null;
      _startedAt = DateTime.now().toUtc();
    });

    if (!keepRecord) {
      _enqueueSave();
    }
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
        _notice = null;
        _lastGuess = guess;
        _finishedAt = DateTime.now().toUtc();
      });
      _enqueueSave();
      return;
    }

    _guess.clear();
    setState(() {
      _wrongGuesses++;
      _lastGuess = guess;
      _feedback = 'Not quite. Try again.';
    });
    _enqueueSave();
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
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(
                _notice!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
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
            if (_saveFailed) ...[
              const SizedBox(height: 12),
              Text(
                'Saved progress is unavailable. You can keep playing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: _controls(),
            ),
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
    if (_restoring) {
      return const [
        SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ];
    }

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
