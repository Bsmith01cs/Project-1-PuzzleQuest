import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../hints/hint_coach.dart';
import '../models/attempt.dart';
import '../models/puzzle.dart';
import '../repositories/attempt_repository.dart';
import '../settings/settings_controller.dart';

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
  const PlayScreen({
    super.key,
    this.puzzle,
    this.random,
    this.attempts,
    this.settings,
  });

  final Puzzle? puzzle;
  final Random? random;
  final AttemptRepository? attempts;
  final SettingsController? settings;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  final TextEditingController _guess = TextEditingController();

  late final AttemptRepository _attempts =
      widget.attempts ?? AttemptRepository();
  late final SettingsController _settings =
      widget.settings ?? SettingsController();

  Timer? _timer;
  Future<void> _writes = Future<void>.value();

  GameStatus _status = GameStatus.ready;
  String _scrambled = '';
  String? _feedback;
  String? _notice;
  int _wrongGuesses = 0;
  int _elapsedSeconds = 0;
  int _hintsUsed = 0;

  // Hints counted by a row written before hint kinds were stored. Such a row
  // names no kinds, so its count is the floor the total cannot drop below.
  int _restoredHints = 0;

  // One entry per hint kind, so a hint is offered once and revealed once.
  // Restored from the attempt, so a hint already accepted is never offered
  // again after a restart.
  final Set<HintKind> _revealedHints = {};
  final Set<HintKind> _declinedHints = {};

  int? _attemptId;
  String? _lastGuess;
  String? _userNote;
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
    if (widget.settings == null) {
      _settings.dispose();
    }
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
      // A stored count outside the possible range is treated as the nearest
      // valid one rather than trusted.
      _revealedHints
        ..clear()
        ..addAll(decodeHintKinds(restored.hintKinds));
      // A stored count outside the possible range is treated as the nearest
      // valid one rather than trusted.
      _restoredHints = restored.hintsUsed.clamp(0, HintKind.values.length);
      _hintsUsed = max(_restoredHints, _revealedHints.length);
      _lastGuess = restored.lastGuess;
      // Carried so saving gameplay cannot wipe a note written in History.
      _userNote = restored.userNote;
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
      hintsUsed: _hintsUsed,
      hintKinds: encodeHintKinds(_revealedHints),
      elapsedSeconds: _elapsedSeconds,
      lastGuess: _lastGuess,
      userNote: _userNote,
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
      _hintsUsed = 0;
      _restoredHints = 0;
      _revealedHints.clear();
      _declinedHints.clear();
      _feedback = null;
      _notice = null;
      _lastGuess = null;
      _userNote = null;
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

  /// The hint HintCoach offers right now, or null when the rules say the
  /// player has not earned one yet.
  HintSuggestion? get _suggestion {
    final puzzle = widget.puzzle;
    if (puzzle == null || _status != GameStatus.running) {
      return null;
    }

    return suggestHint(
      wrongGuesses: _wrongGuesses,
      elapsedSeconds: _elapsedSeconds,
      thresholdSeconds: _settings.settings.hintThresholdSeconds,
      answerLength: puzzle.answer.length,
    );
  }

  /// Why HintCoach cannot offer anything, or null when its inputs are sound.
  String? get _hintError {
    final puzzle = widget.puzzle;
    if (puzzle == null || _status != GameStatus.running) {
      return null;
    }

    return validateHintInputs(
      wrongGuesses: _wrongGuesses,
      elapsedSeconds: _elapsedSeconds,
      answerLength: puzzle.answer.length,
    );
  }

  void _revealHint(HintKind kind) {
    if (_revealedHints.contains(kind)) {
      return;
    }

    setState(() {
      _revealedHints.add(kind);
      _declinedHints.remove(kind);
      // One count per distinct kind. The floor only matters for a row that
      // stored a count without its kinds.
      _hintsUsed = max(_restoredHints, _revealedHints.length);
    });
    _enqueueSave();
  }

  void _declineHint(HintKind kind) {
    setState(() => _declinedHints.add(kind));
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
            ..._hints(theme, puzzle),
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

  List<Widget> _hints(ThemeData theme, Puzzle puzzle) {
    final widgets = <Widget>[];

    for (final kind in HintKind.values) {
      if (!_revealedHints.contains(kind)) {
        continue;
      }

      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hint', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  hintText(
                    kind: kind,
                    answer: puzzle.answer,
                    clue: puzzle.clue,
                    // The clue sits at the top of this screen already.
                    clueVisible: true,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hintsUsed > 0) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Text('Hints used $_hintsUsed', style: theme.textTheme.bodySmall),
      );
    }

    final error = _hintError;
    if (error != null) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Text(
          error,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
      return widgets;
    }

    final suggestion = _suggestion;
    if (suggestion != null &&
        !_revealedHints.contains(suggestion.kind) &&
        !_declinedHints.contains(suggestion.kind)) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Card(
          color: theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hint available', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(suggestion.explanation, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _revealHint(suggestion.kind),
                      child: const Text('Reveal'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _declineHint(suggestion.kind),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _letters(ThemeData theme) {
    if (_status == GameStatus.paused) {
      return Text(
        'Paused',
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      );
    }

    // Read out as whole words the letters are spaced for sighted players,
    // which a screen reader would otherwise run together.
    return Semantics(
      label: 'Scrambled letters: ${_scrambled.split('').join(', ')}',
      excludeSemantics: true,
      child: Text(
        _scrambled.split('').join(' '),
        style: theme.textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
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
